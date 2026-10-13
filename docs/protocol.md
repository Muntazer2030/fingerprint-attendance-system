# Device <-> PC Protocol  (v1)

Transport: HTTP/1.1 on the LAN, port 80. Live updates over WebSocket `/ws`.
Discovery: mDNS `_attend._tcp.local` (fallback: static IP in app settings).
Auth: `Authorization: Bearer <device_token>` on every request. Token is set
during pairing and stored in NVS. Requests without it get 401.

## CORS (required for the Flutter **web** client)

A Flutter web build runs inside the browser, so every call to the device is a
cross-origin request. Because we send an `Authorization` header, the request is
never "simple" -- the browser **always** sends an `OPTIONS` preflight first.

The device HTTP server must therefore:

1. Register an `OPTIONS` handler on every path (or a wildcard) returning 204.
2. Emit on **all** responses, preflight and real:

```
Access-Control-Allow-Origin:  *
Access-Control-Allow-Headers: Authorization, Content-Type
Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS
Access-Control-Max-Age:       86400
```

`Allow-Origin: *` is safe here: the bearer token travels in a header, not a
cookie, so this is not a credentialed request in the CORS sense. Access is
still gated by the token, and the device is LAN-only.

Without preflight handling every browser request fails before it reaches a
handler, and the browser console reports it as a network error rather than a
401 -- which is confusing to debug. Build it in from the start.

`Max-Age` matters: without it Chrome re-preflights every single request,
doubling round-trips on a 10 Mbps ENC28J60 link.

**Mixed content:** serve the web app over plain HTTP (`flutter run -d chrome`
uses `http://localhost`). A page served over HTTPS cannot call the device's
plain-HTTP API -- the browser blocks it outright.

**Discovery:** mDNS (`attendance.local`) is not reliably resolvable from a
browser. The web client must target the device by **IP**, so give the terminal
a static lease or a static IP.

WebSocket `/ws` is not subject to CORS and works from the browser as-is.

All timestamps are Unix epoch seconds, UTC. The app applies the timezone.

---

## Event record

On-device packed form is 16 bytes:

| field    | type | notes                                          |
|----------|------|------------------------------------------------|
| seq      | u32  | monotonic, never reused, survives reboot       |
| epoch    | u32  | UTC seconds                                    |
| employee | u16  | 0 = unknown/unmatched                          |
| slot     | u16  | sensor template slot that matched              |
| flags    | u8   | bit0 direction (0=IN,1=OUT), bit1 manual, bit2 provisional_time, bit3 dup_suppressed |
| method   | u8   | 0=finger 1=manual 2=pin                        |
| crc      | u16  | CRC-16 over the preceding 14 bytes             |

Stored in a raw append-only ring partition (~700 KB => ~44,000 events,
roughly 220 days at 50 staff x 4 punches/day). Power-fail safe: a torn write
fails CRC and is skipped on replay.

JSON form on the wire:

```json
{ "seq": 10423, "epoch": 1766217600, "employee_id": 17, "slot": 42,
  "direction": "in", "method": "finger",
  "provisional_time": false, "manual": false }
```

---

## REST

### Device
| method | path | purpose |
|---|---|---|
| GET  | `/api/v1/info`    | device id, fw version, board, uptime, time-sync state, event counts |
| GET  | `/api/v1/health`  | eth link, sensor ok, free heap, log usage %, last sync |
| POST | `/api/v1/time`    | `{ "epoch": 1766217600 }` — set clock |
| POST | `/api/v1/config`  | language, clock format, timezone, brightness, buzzer, idle timers, direction mode |
| POST | `/api/v1/reboot`  | |
| POST | `/api/v1/ota`     | firmware image upload, `Content-Type: application/octet-stream` |

### Events (pull model — the PC drives)
| method | path | purpose |
|---|---|---|
| GET  | `/api/v1/events?since=<seq>&limit=<n>` | events with `seq > since` |
| POST | `/api/v1/events/ack` | `{ "through_seq": N }` — device may reclaim space |

The PC stores its own high-water mark. Re-requesting an already-acked range is
allowed until the ring wraps. Events are never deleted before ack unless the
ring is full, in which case the oldest are dropped and `overflow` is set in
`/health`.

### Users and slots
| method | path | purpose |
|---|---|---|
| GET    | `/api/v1/users` | all `slot -> employee` mappings |
| POST   | `/api/v1/users` | upsert `{ employee_id, name_bitmap_b64, active }` |
| DELETE | `/api/v1/users/{employee_id}` | removes user and all their slots |

`name_bitmap_b64` is a 128x16 1bpp bitmap (256 bytes), row-major, MSB-first,
already shaped and RTL-ordered by the Flutter app.

### Enrolment
| method | path | purpose |
|---|---|---|
| POST | `/api/v1/enroll/start` | `{ employee_id, finger_label }` -> `{ session_id }` |
| GET  | `/api/v1/enroll/{sid}` | poll state (also pushed over WS) |
| POST | `/api/v1/enroll/{sid}/cancel` | |

State machine: `waiting_finger` -> `lift_finger` -> `waiting_finger_again`
-> `merging` -> `stored{slot}` | `failed{reason}`.

### Telegram notifications (firmware/main/notify.c, decision D14)
| method | path | purpose |
|---|---|---|
| GET  | `/api/v1/notify` | settings, delivery counters, last error, roster summary |
| POST | `/api/v1/notify` | partial update: `enabled`, `each_punch`, `late`, `summary_minute` (-1 = off), `chat_id`, `bot_token` (`""` clears) |
| POST | `/api/v1/notify/test` | no body; queues a test message |
| POST | `/api/v1/notify/summary` | no body; queues today's summary now |
| POST | `/api/v1/roster` | `{ version, names_b64, days_b64, tz_offset_min }`, body up to 20 KB |

The bot token is write-only: GET returns `has_bot_token` and the last four
characters (`bot_token_hint`), never the token. Sending is asynchronous, so
GET again a few seconds after `/notify/test` to see `sent` or `last_error`.

The roster is binary (little-endian), base64 in the JSON:
- `names`: repeated `{ u16 id, u8 len, len bytes UTF-8 }` (the app caps a
  name at 60 bytes, cut on a character boundary)
- `days`: repeated `{ u32 yyyymmdd, u16 n, n x { u16 id, i16 start_min,
  u8 grace_min, u8 0 } }`; `start_min` -1 = expected, but no fixed start
  (flexible shift); a day with `n = 0` means nobody is expected.

`version` is opaque to the terminal (the app uses FNV-1a over the blobs and
the offset); the app pushes only when `roster_version` differs from its own.
`tz_offset_min` updates the terminal's offset too: it decides what "today"
means for lateness and the summary.

`POST /reset` with scope `config` or `all` also clears the Telegram settings
and the roster.

### Wi-Fi fallback (firmware/main/net_wifi.c, decision D15)
| method | path | purpose |
|---|---|---|
| GET  | `/api/v1/wifi` | `configured`, `ssid`, `state` (off/connecting/connected/failed), `ip`, `rssi`, `last_error`, `active` (eth/wifi/none), `eth_link` |
| POST | `/api/v1/wifi` | `{ ssid, password }`; empty `ssid` forgets; password empty (open) or 8-64 |
| GET  | `/api/v1/wifi/scan` | `{ networks: [{ ssid, rssi, secure }] }`, strongest first; blocks ~3 s |

The password is write-only. `/info` and `/health` also report `net` (the
interface in use) and `ip` is that interface's address. `POST /reset` with
`config` or `all` forgets the Wi-Fi network.

### Template backup
| method | path | purpose |
|---|---|---|
| GET  | `/api/v1/templates/{slot}` | 512-byte template, for backup |
| POST | `/api/v1/templates/{slot}` | restore into a replacement sensor |

---

## WebSocket `/ws`

Server -> client:
```json
{ "type": "punch",  "event": { ...event json... } }
{ "type": "enroll", "session_id": "...", "state": "lift_finger" }
{ "type": "health", "eth": true, "sensor": true, "heap": 184320 }
{ "type": "error",  "code": "sensor_timeout", "detail": "..." }
```
Client -> server: `{ "type": "ping" }`.

WebSocket is a **notification channel only** — it makes the dashboard live.
Correctness never depends on it; the PC always reconciles via
`GET /events?since=`. If the socket drops, nothing is lost.

---
