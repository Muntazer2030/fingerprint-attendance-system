#!/usr/bin/env python3
"""A stand-in for the attendance terminal, speaking its real HTTP API.

For testing the admin app when the hardware is not to hand. It mirrors
firmware/main/api_server.c closely enough that the app cannot tell the
difference: the same routes, JSON shapes, error strings, the 401 body the
app's scanner uses to recognise the device, the event log's sequence rules,
and an enrolment state machine that walks through the same states on a timer.

    python tools/mock_terminal.py                       # 0.0.0.0:80
    python tools/mock_terminal.py --host 192.168.137.1  # on the ICS adapter
    python tools/mock_terminal.py --port 8080 --token abc123

Test-only control routes (the real firmware has none of these):

    POST /mock/punch   {"employee_id": 5, "direction": "in"|"out",
                        "epoch": 1790000000?, "provisional": false?}
    POST /mock/scan    {"employee_id": 5}   a finger scan: direction follows
                                            the terminal's mode, like the device
    POST /mock/erase-old-firmware          reset the log the way firmware
                                            before the fix did: numbering back to 1
    GET  /mock/state                       everything, for assertions
"""

import argparse
import base64
import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

# Test token for the mock only. Not a real device credential.
DEFAULT_TOKEN = "0123456789abcdef0123456789abcdef"

CAPACITY = 40960
MAX_EVENTS_PER_REQUEST = 100
STRING_SLOTS = 19

lock = threading.RLock()

state = {
    "head": 0,
    "ack": 0,
    "floor": 0,
    "events": [],          # dicts in wire format
    "employees": {},       # id -> dict
    "slots": [],           # {"slot", "employee_id", "finger"}
    "strings": set(),
    "clock_source": "ntp",
    "clock_offset": 0,     # seconds added to real time, set by POST /time
    "config": {
        "language": "en", "time_12h": False, "show_seconds": False,
        "tz_offset_min": 180, "brightness": 128, "buzzer": True,
        "dup_window_s": 60, "idle_dim_s": 20, "idle_off_s": 120,
        "use_finger_detect": True, "use_touch_button": True,
        "direction_mode": "fixed", "direction": "in",
    },
    "enroll": {"session_id": 0, "state": "idle", "slot": None, "reason": None,
               "employee_id": None, "finger": 0},
    "boot": time.time(),
    # Telegram: the mock never calls Telegram, it records what it would send.
    "notify": {"enabled": False, "each_punch": True, "late": True,
               "summary_minute": -1, "chat_id": "", "bot_token": ""},
    "notify_outbox": [],
    # Wi-Fi fallback. The mock is always "on Ethernet", so Wi-Fi stays off.
    "wifi": {"ssid": "", "password": ""},
    "roster": {"version": 0, "names": 0, "days": 0, "first": 0, "last": 0},
}

DEFAULT_CONFIG = dict(state["config"])


def now_epoch():
    return int(time.time() + state["clock_offset"])


def stats():
    head, ack, floor = state["head"], state["ack"], state["floor"]
    oldest_ring = head - CAPACITY + 1 if head > CAPACITY else 1
    oldest = max(oldest_ring, floor + 1) if head > floor else 0
    return {
        "head": head, "ack": ack, "pending": head - ack, "oldest": oldest,
        "capacity": CAPACITY,
        "overflow": head > CAPACITY and ack < head - CAPACITY,
    }


def append_event(employee_id, direction, epoch=None, method="finger",
                 provisional=False):
    with lock:
        state["head"] += 1
        ev = {
            "seq": state["head"],
            "epoch": epoch if epoch is not None else now_epoch(),
            "employee_id": employee_id,
            "slot": 0,
            "direction": direction,
            "method": method,
            "manual": method == "manual",
            "provisional_time": provisional,
        }
        state["events"].append(ev)
        emp = state["employees"].get(employee_id)
        if emp:
            emp["last_direction"] = direction
            emp["last_epoch"] = ev["epoch"]
        return ev


def parse_names(b):
    """{u16 id, u8 len, utf-8} repeated, as notify.c reads it. None if bad."""
    out, p = {}, 0
    while p < len(b):
        if p + 3 > len(b) or p + 3 + b[p + 2] > len(b):
            return None
        out[int.from_bytes(b[p:p + 2], "little")] = \
            b[p + 3:p + 3 + b[p + 2]].decode("utf-8", "replace")
        p += 3 + b[p + 2]
    return out


def parse_days(b):
    """{u32 yyyymmdd, u16 n, n x {u16 id, i16 start, u8 grace, u8 0}}."""
    out, p = {}, 0
    while p < len(b):
        if p + 6 > len(b):
            return None
        day = int.from_bytes(b[p:p + 4], "little")
        n = int.from_bytes(b[p + 4:p + 6], "little")
        p += 6
        if p + n * 6 > len(b) or not 20000101 <= day <= 21001231:
            return None
        out[day] = [(int.from_bytes(b[q:q + 2], "little"),
                     int.from_bytes(b[q + 2:q + 4], "little", signed=True),
                     b[q + 4]) for q in range(p, p + n * 6, 6)]
        p += n * 6
    return out


def fingers_for(emp_id):
    return sum(1 for s in state["slots"] if s["employee_id"] == emp_id)


def run_enrollment(session_id, emp_id, finger):
    """Walks the same states as attend.c, on a timer."""
    steps = [("waiting_finger", 2.0), ("lift_finger", 1.2),
             ("waiting_finger_again", 2.0), ("merging", 0.8)]
    for name, dwell in steps:
        with lock:
            if state["enroll"]["session_id"] != session_id or \
                    state["enroll"]["state"] in ("idle", "failed"):
                return
            state["enroll"]["state"] = name
        time.sleep(dwell)
    with lock:
        if state["enroll"]["session_id"] != session_id:
            return
        used = {s["slot"] for s in state["slots"]}
        slot = next(i for i in range(240) if i not in used)
        state["slots"].append({"slot": slot, "employee_id": emp_id, "finger": finger})
        state["enroll"].update(state="stored", slot=slot)
    time.sleep(3.0)  # the device holds the result briefly, then goes idle
    with lock:
        if state["enroll"]["session_id"] == session_id:
            state["enroll"].update(state="idle", slot=None)


class Handler(BaseHTTPRequestHandler):
    server_version = "esp-httpd"
    token = DEFAULT_TOKEN

    def log_message(self, fmt, *args):
        print("%s %s" % (self.address_string(), fmt % args), flush=True)

    # --- plumbing ----------------------------------------------------------

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Max-Age", "86400")

    def _send(self, code, obj):
        body = json.dumps(obj, separators=(",", ":")).encode()
        self.send_response(code)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _bad(self, why):
        self._send(400, {"error": why})

    def _authorized(self):
        return self.headers.get("Authorization") == "Bearer " + self.token

    def _deny(self):
        got = self.headers.get("Authorization")
        if got:  # a probe carries none; anything else is worth seeing
            print(f"  rejected Authorization: {got!r}", flush=True)
        self._send(401, {"error": "unauthorized"})

    def _notify_json(self):
        n, r = state["notify"], state["roster"]
        tok = n["bot_token"]
        return {
            "enabled": n["enabled"], "each_punch": n["each_punch"],
            "late": n["late"], "summary_minute": n["summary_minute"],
            "chat_id": n["chat_id"], "has_bot_token": bool(tok),
            "bot_token_hint": tok[-4:] if len(tok) > 4 else "",
            "sent": len(state["notify_outbox"]), "failed": 0, "dropped": 0,
            "queued": 0, "last_ok_epoch": now_epoch() if state["notify_outbox"] else 0,
            "last_error": "", "roster_version": r["version"],
            "roster_days": r["days"], "roster_names": r["names"],
            "roster_first_day": r["first"], "roster_last_day": r["last"],
        }

    def _wifi_json(self):
        w = state["wifi"]
        return {"configured": bool(w["ssid"]), "ssid": w["ssid"],
                "state": "off", "ip": "0.0.0.0", "rssi": 0, "last_error": "",
                "active": "eth", "eth_link": True}

    def _body(self, limit=1024):
        n = int(self.headers.get("Content-Length") or 0)
        if n <= 0 or n > limit:  # the firmware's read_body limit
            return None
        try:
            return json.loads(self.rfile.read(n))
        except ValueError:
            return "malformed"

    def _route(self):
        u = urlparse(self.path)
        return u.path, {k: v[0] for k, v in parse_qs(u.query).items()}

    # --- verbs -------------------------------------------------------------

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        path, q = self._route()
        if path == "/mock/state":
            with lock:
                return self._send(200, {**{k: v for k, v in state.items()
                                           if k != "strings"},
                                        "strings": sorted(state["strings"])})
        if not path.startswith("/api/v1/"):
            return self._send(404, {"error": "not found"})
        if not self._authorized():
            return self._deny()
        with lock:
            if path == "/api/v1/info":
                return self._send(200, {
                    "device": "attendance", "board": "Mock terminal",
                    "eth": "ENC28J60", "display": "SH1106", "fw_version": "1",
                    "idf": "mock", "uptime_s": int(time.time() - state["boot"]),
                    "ip": self.server.server_address[0], "epoch": now_epoch(),
                    "time_synced": state["clock_source"] in ("ntp", "pc"),
                    "time_source": state["clock_source"], "events": stats()})
            if path == "/api/v1/health":
                return self._send(200, {
                    "eth_link": True, "has_ip": True,
                    "ip": self.server.server_address[0], "heap_free": 251068,
                    "heap_min": 198892, "uptime_s": int(time.time() - state["boot"]),
                    "eth_resets": 0, "eth_int_level": 1, "events": stats()})
            if path == "/api/v1/events":
                since = int(q.get("since", 0))
                limit = int(q.get("limit", MAX_EVENTS_PER_REQUEST))
                if not 0 < limit < MAX_EVENTS_PER_REQUEST:
                    limit = MAX_EVENTS_PER_REQUEST
                out = [e for e in state["events"] if e["seq"] > since][:limit]
                return self._send(200, {"events": out, "count": len(out),
                                        "stats": stats()})
            if path == "/api/v1/users":
                emps = []
                for e in sorted(state["employees"].values(),
                                key=lambda x: x["employee_id"]):
                    emps.append({**e, "fingers": fingers_for(e["employee_id"])})
                return self._send(200, {"employees": emps, "slots": state["slots"],
                                        "slots_used": len(state["slots"]),
                                        "slots_total": 240})
            if path == "/api/v1/enroll":
                return self._send(200, self._enroll_json())
            if path == "/api/v1/config":
                return self._send(200, self._config_json())
            if path == "/api/v1/notify":
                return self._send(200, self._notify_json())
            if path == "/api/v1/wifi":
                return self._send(200, self._wifi_json())
            if path == "/api/v1/wifi/scan":
                time.sleep(1.5)  # the real scan blocks for a few seconds
                return self._send(200, {"networks": [
                    {"ssid": "Store-WiFi", "rssi": -48, "secure": True},
                    {"ssid": "Store-Guest", "rssi": -61, "secure": False},
                    {"ssid": "Neighbour 5G", "rssi": -83, "secure": True},
                ]})
            if path == "/api/v1/screen":
                fb = base64.b64encode(bytes(1024)).decode()
                return self._send(200, {"width": 128, "height": 64,
                                        "format": "page-major-1bpp",
                                        "framebuffer_b64": fb})
        return self._send(404, {"error": "not found"})

    def do_DELETE(self):
        path, q = self._route()
        if not self._authorized():
            return self._deny()
        if path == "/api/v1/users":
            if "employee_id" not in q:
                return self._bad("employee_id query param required")
            emp = int(q["employee_id"])
            with lock:
                if emp not in state["employees"]:
                    return self._bad("unknown employee_id")
                del state["employees"][emp]
                state["slots"] = [s for s in state["slots"] if s["employee_id"] != emp]
            return self._send(200, {"employee_id": emp, "deleted": True})
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        path, q = self._route()

        if path.startswith("/mock/"):
            return self._mock(path)

        if not self._authorized():
            return self._deny()

        # enroll/cancel carries no body, like the real one
        if path == "/api/v1/enroll/cancel":
            with lock:
                sid = int(q.get("session_id", 0))
                if sid != state["enroll"]["session_id"] or \
                        state["enroll"]["state"] == "idle":
                    return self._bad("session_id does not match the active enrolment")
                state["enroll"].update(state="idle")
                return self._send(200, self._enroll_json())

        # Also bodiless, like the firmware's handlers.
        if path in ("/api/v1/notify/test", "/api/v1/notify/summary"):
            with lock:
                kind = "test" if path.endswith("test") else "summary"
                state["notify_outbox"].append({"kind": kind, "at": now_epoch()})
                return self._send(200, self._notify_json())

        body = self._body(20 * 1024 if path == "/api/v1/roster" else 1024)
        if body is None:
            return self._bad("missing body")
        if body == "malformed":
            return self._bad("malformed json")

        with lock:
            if path == "/api/v1/wifi":
                ssid, pw = body.get("ssid"), body.get("password", "")
                if not isinstance(ssid, str) or not isinstance(pw, str):
                    return self._bad("ssid required")
                if len(ssid.encode()) > 32 or len(pw) > 64 or 0 < len(pw) < 8:
                    return self._bad("ssid up to 32 bytes; password empty or 8-64")
                state["wifi"] = {"ssid": ssid, "password": pw if ssid else ""}
                return self._send(200, self._wifi_json())
            if path == "/api/v1/notify":
                n = state["notify"]
                for k in ("enabled", "each_punch", "late"):
                    if isinstance(body.get(k), bool):
                        n[k] = body[k]
                if isinstance(body.get("summary_minute"), int):
                    m = body["summary_minute"]
                    n["summary_minute"] = m if 0 <= m < 1440 else -1
                for k, cap in (("chat_id", 24), ("bot_token", 80)):
                    if isinstance(body.get(k), str):
                        if len(body[k]) >= cap:
                            return self._bad(f"{k} too long")
                        n[k] = body[k]
                return self._send(200, self._notify_json())
            if path == "/api/v1/roster":
                try:
                    names = base64.b64decode(body["names_b64"])
                    days = base64.b64decode(body["days_b64"])
                    version = int(body["version"])
                except (KeyError, ValueError, TypeError):
                    return self._bad("version, names_b64 and days_b64 required")
                parsed = parse_days(days)
                if parsed is None or parse_names(names) is None:
                    return self._bad("roster rejected")
                if 8 + len(names) + len(days) > 3 * 4096 - 12:
                    return self._bad("roster too large")
                state["roster"] = {
                    "version": version, "names": len(parse_names(names)),
                    "days": len(parsed),
                    "first": min(parsed) if parsed else 0,
                    "last": max(parsed) if parsed else 0,
                    "names_map": parse_names(names), "days_map": parsed,
                }
                if isinstance(body.get("tz_offset_min"), int):
                    state["config"]["tz_offset_min"] = body["tz_offset_min"]
                return self._send(200, self._notify_json())
            if path == "/api/v1/events/ack":
                if not isinstance(body.get("through_seq"), (int, float)):
                    return self._bad("through_seq required")
                t = min(int(body["through_seq"]), state["head"])
                if t > state["ack"]:
                    state["ack"] = t
                return self._send(200, {"events": stats()})

            if path == "/api/v1/time":
                ep = body.get("epoch")
                if not isinstance(ep, (int, float)) or ep < 1600000000:
                    return self._bad("epoch required, must be a plausible time")
                state["clock_offset"] = int(ep) - time.time()
                state["clock_source"] = "pc"
                return self._send(200, {"epoch": int(ep), "time_synced": True,
                                        "time_source": "pc"})

            if path == "/api/v1/users":
                eid = body.get("employee_id")
                if not isinstance(eid, (int, float)) or not 1 <= eid <= 65535:
                    return self._bad("employee_id required")
                eid = int(eid)
                bmp = body.get("name_bitmap_b64")
                if bmp is not None:
                    try:
                        raw = base64.b64decode(bmp, validate=True)
                    except ValueError:
                        raw = b""
                    if len(raw) != 256:
                        return self._bad("name_bitmap_b64 must decode to 256 bytes")
                prev = state["employees"].get(eid, {})
                state["employees"][eid] = {
                    "employee_id": eid,
                    "active": bool(body.get("active", True)),
                    "last_direction": prev.get("last_direction", "in"),
                    "last_epoch": prev.get("last_epoch", 0),
                    "fail_count": prev.get("fail_count", 0),
                }
                return self._send(200, {"employee_id": eid,
                                        "fingers": fingers_for(eid)})

            if path == "/api/v1/enroll/start":
                eid = body.get("employee_id")
                if not isinstance(eid, (int, float)):
                    return self._bad("employee_id required")
                eid = int(eid)
                if state["enroll"]["state"] not in ("idle", "stored", "failed"):
                    return self._bad("an enrolment is already running")
                if eid not in state["employees"]:
                    return self._bad("create the employee first")
                sid = state["enroll"]["session_id"] + 1
                state["enroll"] = {"session_id": sid, "state": "waiting_finger",
                                   "slot": None, "reason": None,
                                   "employee_id": eid,
                                   "finger": int(body.get("finger", 0))}
                threading.Thread(target=run_enrollment,
                                 args=(sid, eid, int(body.get("finger", 0))),
                                 daemon=True).start()
                return self._send(200, self._enroll_json())

            if path == "/api/v1/config":
                c = state["config"]
                for k, typ in (("time_12h", bool), ("show_seconds", bool),
                               ("buzzer", bool), ("use_finger_detect", bool),
                               ("use_touch_button", bool)):
                    if isinstance(body.get(k), typ):
                        c[k] = body[k]
                for k in ("tz_offset_min", "brightness", "dup_window_s",
                          "idle_dim_s", "idle_off_s"):
                    if isinstance(body.get(k), (int, float)) and \
                            not isinstance(body.get(k), bool):
                        c[k] = int(body[k])
                if isinstance(body.get("language"), str):
                    c["language"] = "ar" if body["language"] == "ar" else "en"
                if isinstance(body.get("direction_mode"), str):
                    c["direction_mode"] = "auto" if body["direction_mode"] == "auto" else "fixed"
                if isinstance(body.get("direction"), str):
                    c["direction"] = "out" if body["direction"] == "out" else "in"
                return self._send(200, self._config_json())

            if path == "/api/v1/strings":
                slot, b = body.get("slot"), body.get("bitmap_b64")
                if not isinstance(slot, (int, float)) or not isinstance(b, str):
                    return self._bad("slot and bitmap_b64 required")
                if not 0 <= int(slot) < STRING_SLOTS:
                    return self._bad("slot out of range")
                try:
                    raw = base64.b64decode(b, validate=True)
                except ValueError:
                    raw = b""
                if len(raw) != 256:
                    return self._bad("bitmap_b64 must decode to 256 bytes")
                state["strings"].add(int(slot))
                return self._send(200, {"slot": int(slot), "stored": True})

            if path == "/api/v1/reset":
                scope = body.get("scope")
                if not isinstance(scope, str):
                    return self._bad("scope required: events, fingerprints, config or all")
                done = {"events_cleared": False, "fingerprints_cleared": False,
                        "config_reset": False}
                if scope in ("events", "all"):
                    # The fixed firmware: numbering continues past the erase.
                    state["events"].clear()
                    state["floor"] = state["head"]
                    state["ack"] = state["head"]
                    done["events_cleared"] = True
                if scope in ("fingerprints", "all"):
                    state["employees"].clear()
                    state["slots"].clear()
                    done["fingerprints_cleared"] = True
                if scope in ("config", "all"):
                    state["config"] = dict(DEFAULT_CONFIG)
                    state["strings"].clear()
                    # Like the firmware: Telegram, roster and Wi-Fi go too.
                    state["notify"].update(enabled=False, summary_minute=-1,
                                           chat_id="", bot_token="")
                    state["roster"] = {"version": 0, "names": 0, "days": 0,
                                       "first": 0, "last": 0}
                    state["wifi"] = {"ssid": "", "password": ""}
                    done["config_reset"] = True
                if not any(done.values()):
                    return self._bad("unknown scope")
                return self._send(200, {**done, "events": stats()})

        return self._send(404, {"error": "not found"})

    # --- helpers -----------------------------------------------------------

    def _enroll_json(self):
        e = state["enroll"]
        o = {"session_id": e["session_id"], "state": e["state"]}
        if e["state"] == "stored":
            o["slot"] = e["slot"]
        if e["state"] == "failed":
            o["reason"] = e["reason"]
        return o

    def _config_json(self):
        return {**state["config"], "has_strings": len(state["strings"]) > 0,
                "string_slots": STRING_SLOTS}

    def _mock(self, path):
        body = self._body() or {}
        if body == "malformed":
            return self._bad("malformed json")
        with lock:
            if path == "/mock/punch":
                ev = append_event(int(body["employee_id"]),
                                  "out" if body.get("direction") == "out" else "in",
                                  epoch=body.get("epoch"),
                                  provisional=bool(body.get("provisional")))
                return self._send(200, ev)
            if path == "/mock/scan":
                eid = int(body["employee_id"])
                c = state["config"]
                if c["direction_mode"] == "auto":
                    last = state["employees"].get(eid, {}).get("last_direction", "out")
                    direction = "out" if last == "in" else "in"
                else:
                    direction = c["direction"]
                return self._send(200, append_event(eid, direction))
            if path == "/mock/erase-old-firmware":
                state["events"].clear()
                state.update(head=0, ack=0, floor=0)
                return self._send(200, stats())
        return self._send(404, {"error": "not found"})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=80)
    ap.add_argument("--token", default=DEFAULT_TOKEN)
    args = ap.parse_args()
    Handler.token = args.token
    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"mock terminal on {args.host}:{args.port}", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
