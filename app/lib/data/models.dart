/// Wire types mirroring docs/protocol.md.
library;

class DeviceInfo {
  final String device;
  final String board;
  final String eth;
  final String display;
  final String firmware;
  final String idf;
  final int uptimeSeconds;
  final String ip;
  final int epoch;
  final bool timeSynced;
  final String timeSource;
  final EventStats events;

  DeviceInfo({
    required this.device,
    required this.board,
    required this.eth,
    required this.display,
    required this.firmware,
    required this.idf,
    required this.uptimeSeconds,
    required this.ip,
    required this.epoch,
    required this.timeSynced,
    required this.timeSource,
    required this.events,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> j) => DeviceInfo(
    device: j['device'] as String? ?? '',
    board: j['board'] as String? ?? '',
    eth: j['eth'] as String? ?? '',
    display: j['display'] as String? ?? '',
    firmware: j['fw_version'] as String? ?? '',
    idf: j['idf'] as String? ?? '',
    uptimeSeconds: (j['uptime_s'] as num?)?.toInt() ?? 0,
    ip: j['ip'] as String? ?? '',
    epoch: (j['epoch'] as num?)?.toInt() ?? 0,
    timeSynced: j['time_synced'] as bool? ?? false,
    timeSource: j['time_source'] as String? ?? 'none',
    events: EventStats.fromJson(
      (j['events'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );
}

class EventStats {
  final int head;
  final int ack;
  final int pending;
  final int oldest;
  final int capacity;
  final bool overflow;

  EventStats({
    required this.head,
    required this.ack,
    required this.pending,
    required this.oldest,
    required this.capacity,
    required this.overflow,
  });

  factory EventStats.fromJson(Map<String, dynamic> j) => EventStats(
    head: (j['head'] as num?)?.toInt() ?? 0,
    ack: (j['ack'] as num?)?.toInt() ?? 0,
    pending: (j['pending'] as num?)?.toInt() ?? 0,
    oldest: (j['oldest'] as num?)?.toInt() ?? 0,
    capacity: (j['capacity'] as num?)?.toInt() ?? 0,
    overflow: j['overflow'] as bool? ?? false,
  );

  double get fillRatio => capacity == 0 ? 0 : pending / capacity;
}

class Health {
  final bool ethLink;
  final bool hasIp;
  final String ip;
  final int heapFree;
  final int heapMin;
  final int uptimeSeconds;
  final EventStats events;

  Health({
    required this.ethLink,
    required this.hasIp,
    required this.ip,
    required this.heapFree,
    required this.heapMin,
    required this.uptimeSeconds,
    required this.events,
  });

  factory Health.fromJson(Map<String, dynamic> j) => Health(
    ethLink: j['eth_link'] as bool? ?? false,
    hasIp: j['has_ip'] as bool? ?? false,
    ip: j['ip'] as String? ?? '',
    heapFree: (j['heap_free'] as num?)?.toInt() ?? 0,
    heapMin: (j['heap_min'] as num?)?.toInt() ?? 0,
    uptimeSeconds: (j['uptime_s'] as num?)?.toInt() ?? 0,
    events: EventStats.fromJson(
      (j['events'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );
}

enum PunchDirection { inbound, outbound }

enum PunchMethod { finger, manual, pin }

class PunchEvent {
  final int seq;
  final int epoch;
  final int employeeId;
  final int slot;
  final PunchDirection direction;
  final PunchMethod method;
  final bool manual;

  /// The device could not verify its clock when this was recorded (D7).
  /// Surfaced in the UI rather than silently trusted.
  final bool provisionalTime;

  PunchEvent({
    required this.seq,
    required this.epoch,
    required this.employeeId,
    required this.slot,
    required this.direction,
    required this.method,
    required this.manual,
    required this.provisionalTime,
  });

  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true).toLocal();

  factory PunchEvent.fromJson(Map<String, dynamic> j) => PunchEvent(
    seq: (j['seq'] as num?)?.toInt() ?? 0,
    epoch: (j['epoch'] as num?)?.toInt() ?? 0,
    employeeId: (j['employee_id'] as num?)?.toInt() ?? 0,
    slot: (j['slot'] as num?)?.toInt() ?? 0,
    direction: (j['direction'] as String?) == 'out'
        ? PunchDirection.outbound
        : PunchDirection.inbound,
    method: switch (j['method'] as String?) {
      'manual' => PunchMethod.manual,
      'pin' => PunchMethod.pin,
      _ => PunchMethod.finger,
    },
    manual: j['manual'] as bool? ?? false,
    provisionalTime: j['provisional_time'] as bool? ?? false,
  );
}

class Employee {
  final int id;
  final bool active;
  final PunchDirection lastDirection;
  final int lastEpoch;

  /// Consecutive failed matches. A climbing count means the finger is
  /// degrading; catching it here avoids a daily support call (D5).
  final int failCount;
  final int fingers;

  Employee({
    required this.id,
    required this.active,
    required this.lastDirection,
    required this.lastEpoch,
    required this.failCount,
    required this.fingers,
  });

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
    id: (j['employee_id'] as num?)?.toInt() ?? 0,
    active: j['active'] as bool? ?? true,
    lastDirection: (j['last_direction'] as String?) == 'out'
        ? PunchDirection.outbound
        : PunchDirection.inbound,
    lastEpoch: (j['last_epoch'] as num?)?.toInt() ?? 0,
    failCount: (j['fail_count'] as num?)?.toInt() ?? 0,
    fingers: (j['fingers'] as num?)?.toInt() ?? 0,
  );

  /// Whether this person is currently on site, by their last punch.
  bool get isPresent =>
      lastEpoch > 0 && lastDirection == PunchDirection.inbound;
}

enum EnrollState {
  idle,
  waitingFinger,
  liftFinger,
  waitingFingerAgain,
  merging,
  stored,
  failed,
}

class EnrollStatus {
  final int sessionId;
  final EnrollState state;
  final int? slot;
  final String? reason;

  EnrollStatus({
    required this.sessionId,
    required this.state,
    this.slot,
    this.reason,
  });

  bool get isRunning =>
      state != EnrollState.idle &&
      state != EnrollState.stored &&
      state != EnrollState.failed;

  factory EnrollStatus.fromJson(Map<String, dynamic> j) => EnrollStatus(
    sessionId: (j['session_id'] as num?)?.toInt() ?? 0,
    state: switch (j['state'] as String?) {
      'waiting_finger' => EnrollState.waitingFinger,
      'lift_finger' => EnrollState.liftFinger,
      'waiting_finger_again' => EnrollState.waitingFingerAgain,
      'merging' => EnrollState.merging,
      'stored' => EnrollState.stored,
      'failed' => EnrollState.failed,
      _ => EnrollState.idle,
    },
    slot: (j['slot'] as num?)?.toInt(),
    reason: j['reason'] as String?,
  );
}

/// Everything about the terminal an operator can change without a reflash.
/// Mirrors device_cfg_t in firmware/main/cfg.h.
class DeviceConfig {
  final String language; // 'en' | 'ar'
  final bool time12h;
  final bool showSeconds;
  final int tzOffsetMin;
  final int brightness; // 1..255
  final bool buzzer;
  final int dupWindowSeconds;
  final int idleDimSeconds;
  final int idleOffSeconds;

  /// False makes the device poll the sensor instead of trusting the wake pin.
  /// Needed when the sensor's touch wires are not connected, since the ESP32's
  /// input-only pins float without them.
  final bool useFingerDetect;

  /// False ignores the TTP223 entirely. GPIO35 has no internal pull, so an
  /// unwired button floats and triggers spurious direction overrides.
  final bool useTouchButton;

  /// Fixed: every scan records [directionOut]; the screen can always say which.
  /// Auto: each employee alternates IN and OUT.
  final bool directionAuto;
  final bool directionOut;

  final bool hasStrings;
  final int stringSlots;

  const DeviceConfig({
    this.directionAuto = false,
    this.directionOut = false,
    required this.language,
    required this.time12h,
    required this.showSeconds,
    required this.tzOffsetMin,
    required this.brightness,
    required this.buzzer,
    required this.dupWindowSeconds,
    required this.idleDimSeconds,
    required this.idleOffSeconds,
    required this.useFingerDetect,
    required this.useTouchButton,
    required this.hasStrings,
    required this.stringSlots,
  });

  factory DeviceConfig.fromJson(Map<String, dynamic> j) => DeviceConfig(
    language: j['language'] as String? ?? 'en',
    time12h: j['time_12h'] as bool? ?? false,
    showSeconds: j['show_seconds'] as bool? ?? false,
    tzOffsetMin: (j['tz_offset_min'] as num?)?.toInt() ?? 0,
    brightness: (j['brightness'] as num?)?.toInt() ?? 128,
    buzzer: j['buzzer'] as bool? ?? true,
    dupWindowSeconds: (j['dup_window_s'] as num?)?.toInt() ?? 60,
    idleDimSeconds: (j['idle_dim_s'] as num?)?.toInt() ?? 20,
    idleOffSeconds: (j['idle_off_s'] as num?)?.toInt() ?? 120,
    useFingerDetect: j['use_finger_detect'] as bool? ?? true,
    useTouchButton: j['use_touch_button'] as bool? ?? true,
    directionAuto: (j['direction_mode'] as String?) == 'auto',
    directionOut: (j['direction'] as String?) == 'out',
    hasStrings: j['has_strings'] as bool? ?? false,
    stringSlots: (j['string_slots'] as num?)?.toInt() ?? 0,
  );

  DeviceConfig copyWith({
    String? language,
    bool? time12h,
    bool? showSeconds,
    int? tzOffsetMin,
    int? brightness,
    bool? buzzer,
    int? dupWindowSeconds,
    int? idleDimSeconds,
    int? idleOffSeconds,
    bool? useFingerDetect,
    bool? useTouchButton,
    bool? directionAuto,
    bool? directionOut,
  }) => DeviceConfig(
    directionAuto: directionAuto ?? this.directionAuto,
    directionOut: directionOut ?? this.directionOut,
    language: language ?? this.language,
    time12h: time12h ?? this.time12h,
    showSeconds: showSeconds ?? this.showSeconds,
    tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
    brightness: brightness ?? this.brightness,
    buzzer: buzzer ?? this.buzzer,
    dupWindowSeconds: dupWindowSeconds ?? this.dupWindowSeconds,
    idleDimSeconds: idleDimSeconds ?? this.idleDimSeconds,
    idleOffSeconds: idleOffSeconds ?? this.idleOffSeconds,
    useFingerDetect: useFingerDetect ?? this.useFingerDetect,
    useTouchButton: useTouchButton ?? this.useTouchButton,
    hasStrings: hasStrings,
    stringSlots: stringSlots,
  );

  Map<String, dynamic> toJson() => {
    'language': language,
    'time_12h': time12h,
    'show_seconds': showSeconds,
    'tz_offset_min': tzOffsetMin,
    'brightness': brightness,
    'buzzer': buzzer,
    'dup_window_s': dupWindowSeconds,
    'idle_dim_s': idleDimSeconds,
    'idle_off_s': idleOffSeconds,
    'use_finger_detect': useFingerDetect,
    'use_touch_button': useTouchButton,
    'direction_mode': directionAuto ? 'auto' : 'fixed',
    'direction': directionOut ? 'out' : 'in',
  };

  /// Both burn-in mitigations off is allowed but unwise on an OLED that shows
  /// near-static content around the clock.
  bool get burnInRisk => idleDimSeconds == 0 && idleOffSeconds == 0;
}

/// The terminal's Telegram settings and delivery counters. Mirrors
/// notify_cfg_t / notify_status_t in firmware/main/notify.h.
///
/// The bot token is write-only: the terminal reports whether one is set and
/// its last four characters, never the token itself.
class NotifyStatus {
  const NotifyStatus({
    required this.enabled,
    required this.eachPunch,
    required this.late,
    required this.summaryMinute,
    required this.chatId,
    required this.hasBotToken,
    required this.botTokenHint,
    required this.sent,
    required this.failed,
    required this.dropped,
    required this.queued,
    required this.lastOkEpoch,
    required this.lastError,
    required this.rosterVersion,
    required this.rosterDays,
    required this.rosterNames,
    required this.rosterFirstDay,
    required this.rosterLastDay,
  });

  final bool enabled;
  final bool eachPunch;
  final bool late;

  /// Local minute of the day for the daily summary; null when switched off.
  final int? summaryMinute;
  final String chatId;
  final bool hasBotToken;
  final String botTokenHint;

  final int sent;
  final int failed;
  final int dropped;
  final int queued;
  final int lastOkEpoch;
  final String lastError;

  final int rosterVersion;
  final int rosterDays;
  final int rosterNames;

  /// yyyymmdd, 0 when the terminal has no roster.
  final int rosterFirstDay;
  final int rosterLastDay;

  factory NotifyStatus.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    final summary = n('summary_minute');
    return NotifyStatus(
      enabled: j['enabled'] as bool? ?? false,
      eachPunch: j['each_punch'] as bool? ?? false,
      late: j['late'] as bool? ?? false,
      summaryMinute: summary >= 0 && summary < 1440 ? summary : null,
      chatId: j['chat_id'] as String? ?? '',
      hasBotToken: j['has_bot_token'] as bool? ?? false,
      botTokenHint: j['bot_token_hint'] as String? ?? '',
      sent: n('sent'),
      failed: n('failed'),
      dropped: n('dropped'),
      queued: n('queued'),
      lastOkEpoch: n('last_ok_epoch'),
      lastError: j['last_error'] as String? ?? '',
      rosterVersion: n('roster_version'),
      rosterDays: n('roster_days'),
      rosterNames: n('roster_names'),
      rosterFirstDay: n('roster_first_day'),
      rosterLastDay: n('roster_last_day'),
    );
  }
}

/// The terminal's Wi-Fi fallback. Mirrors net_wifi_status_t in
/// firmware/main/net_wifi.h. The password is write-only and never reported.
class WifiStatus {
  const WifiStatus({
    required this.configured,
    required this.ssid,
    required this.state,
    required this.ip,
    required this.rssi,
    required this.lastError,
    required this.active,
    required this.ethLink,
  });

  final bool configured;
  final String ssid;

  /// off, connecting, connected or failed. "off" is normal while the
  /// Ethernet cable works: Wi-Fi is only a fallback.
  final String state;
  final String ip;
  final int rssi;
  final String lastError;

  /// The interface the terminal is reachable on: eth, wifi or none.
  final String active;
  final bool ethLink;

  factory WifiStatus.fromJson(Map<String, dynamic> j) => WifiStatus(
    configured: j['configured'] as bool? ?? false,
    ssid: j['ssid'] as String? ?? '',
    state: j['state'] as String? ?? 'off',
    ip: j['ip'] as String? ?? '0.0.0.0',
    rssi: (j['rssi'] as num?)?.toInt() ?? 0,
    lastError: j['last_error'] as String? ?? '',
    active: j['active'] as String? ?? 'eth',
    ethLink: j['eth_link'] as bool? ?? true,
  );
}

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.secure,
  });

  final String ssid;
  final int rssi;
  final bool secure;

  /// 0-4 bars, the way phones show it.
  int get bars => rssi >= -55
      ? 4
      : rssi >= -65
      ? 3
      : rssi >= -75
      ? 2
      : rssi >= -85
      ? 1
      : 0;

  factory WifiNetwork.fromJson(Map<String, dynamic> j) => WifiNetwork(
    ssid: j['ssid'] as String? ?? '',
    rssi: (j['rssi'] as num?)?.toInt() ?? -100,
    secure: j['secure'] as bool? ?? true,
  );
}
