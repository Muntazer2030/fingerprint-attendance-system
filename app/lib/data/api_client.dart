import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'settings.dart';

/// Talks to the terminal over the LAN. See docs/protocol.md.
///
/// Deliberately has no dependency on dart:io, so the same client works in the
/// browser build and the Windows build without changes.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  bool get isAuthFailure => statusCode == 401;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required String host, required this.token, http.Client? client})
    : host = Settings.normaliseHost(host),
      _client = client ?? http.Client();

  final String host;
  final String token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.http(host, '/api/v1$path', query);

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    late http.Response r;
    try {
      r = await _client
          .get(_uri(path, query), headers: _headers)
          .timeout(_timeout);
    } catch (e) {
      // In the browser a CORS rejection also lands here as a generic failure,
      // with no status code to inspect - the response never reaches us.
      throw ApiException('Could not reach the device at $host');
    }
    return _decode(r);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    late http.Response r;
    try {
      final req = http.Request(method, _uri(path, query))
        ..headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await _client.send(req).timeout(_timeout);
      r = await http.Response.fromStream(streamed);
    } catch (e) {
      throw ApiException('Could not reach the device at $host');
    }
    return _decode(r);
  }

  Map<String, dynamic> _decode(http.Response r) {
    if (r.statusCode == 401) {
      throw ApiException('Device rejected the token', 401);
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      String detail = r.body;
      try {
        detail = (jsonDecode(r.body) as Map)['error']?.toString() ?? r.body;
      } catch (_) {}
      throw ApiException(detail, r.statusCode);
    }
    if (r.body.isEmpty) return const {};
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      // Something answered, but not the terminal -- another machine now owns
      // this address. Report it as unreachable so sync goes looking for it.
      throw ApiException('Could not reach the device at $host');
    }
  }

  // --- device ------------------------------------------------------------

  Future<DeviceInfo> info() async => DeviceInfo.fromJson(await _get('/info'));

  Future<Health> health() async => Health.fromJson(await _get('/health'));

  /// Pushes this PC's clock to the device. Makes the device's time
  /// authoritative, so subsequent punches stop being flagged provisional.
  Future<void> syncClock() async {
    final epoch = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await _send('POST', '/time', body: {'epoch': epoch});
  }

  // --- device configuration ----------------------------------------------

  Future<DeviceConfig> config() async =>
      DeviceConfig.fromJson(await _get('/config'));

  /// Partial updates are supported by the device, but sending the whole object
  /// keeps the app's view and the device's authoritative.
  Future<DeviceConfig> setConfig(DeviceConfig c) async =>
      DeviceConfig.fromJson(await _send('POST', '/config', body: c.toJson()));

  /// Uploads one rendered UI phrase (a 256-byte 1bpp raster) into a fixed slot.
  Future<void> uploadString(int slot, List<int> bitmap) async {
    await _send(
      'POST',
      '/strings',
      body: {'slot': slot, 'bitmap_b64': base64Encode(bitmap)},
    );
  }

  /// Wipes device state. [scope] is one of events, fingerprints, config, all.
  /// The device token is deliberately never regenerated -- doing so would lock
  /// this app out of the terminal it just cleared.
  Future<void> resetDevice(String scope) async {
    await _send('POST', '/reset', body: {'scope': scope});
  }

  // --- wifi fallback -----------------------------------------------------

  Future<WifiStatus> wifiStatus() async =>
      WifiStatus.fromJson(await _get('/wifi'));

  /// An empty [ssid] forgets the network. An empty [password] is an open one.
  Future<WifiStatus> setWifi(String ssid, String password) async =>
      WifiStatus.fromJson(
        await _send(
          'POST',
          '/wifi',
          body: {'ssid': ssid, 'password': password},
        ),
      );

  /// The terminal listens for a few seconds, so this is slow by design.
  Future<List<WifiNetwork>> wifiScan() async {
    final j = await _get('/wifi/scan');
    return [
      for (final n in (j['networks'] as List?) ?? const [])
        WifiNetwork.fromJson((n as Map).cast<String, dynamic>()),
    ];
  }

  // --- telegram ----------------------------------------------------------

  Future<NotifyStatus> notifyStatus() async =>
      NotifyStatus.fromJson(await _get('/notify'));

  /// Partial update: only the fields given are changed. An empty [botToken]
  /// clears it; null leaves it as it is.
  Future<NotifyStatus> setNotify({
    bool? enabled,
    bool? eachPunch,
    bool? late,
    int? summaryMinute,
    bool clearSummary = false,
    String? chatId,
    String? botToken,
  }) async {
    final body = <String, dynamic>{
      'enabled': ?enabled,
      'each_punch': ?eachPunch,
      'late': ?late,
      'chat_id': ?chatId,
      'bot_token': ?botToken,
    };
    if (clearSummary) {
      body['summary_minute'] = -1;
    } else if (summaryMinute != null) {
      body['summary_minute'] = summaryMinute;
    }
    return NotifyStatus.fromJson(await _send('POST', '/notify', body: body));
  }

  Future<NotifyStatus> notifyTest() async =>
      NotifyStatus.fromJson(await _send('POST', '/notify/test'));

  Future<NotifyStatus> notifySummaryNow() async =>
      NotifyStatus.fromJson(await _send('POST', '/notify/summary'));

  /// Names and expected start times for the next days; see RosterPayload.
  Future<NotifyStatus> pushRoster({
    required int version,
    required List<int> names,
    required List<int> days,
    required int tzOffsetMin,
  }) async => NotifyStatus.fromJson(
    await _send(
      'POST',
      '/roster',
      body: {
        'version': version,
        'names_b64': base64Encode(names),
        'days_b64': base64Encode(days),
        'tz_offset_min': tzOffsetMin,
      },
    ),
  );

  // --- events ------------------------------------------------------------

  Future<List<PunchEvent>> events({int since = 0, int limit = 100}) async =>
      (await eventsPage(since: since, limit: limit)).events;

  /// Events plus the device's own counters from the same response. Sync needs
  /// both at once: the counters are how it notices the device's sequence went
  /// backwards (its log was cleared, or it is a different terminal).
  Future<({List<PunchEvent> events, EventStats stats})> eventsPage({
    int since = 0,
    int limit = 100,
  }) async {
    final j = await _get('/events', {
      'since': since.toString(),
      'limit': limit.toString(),
    });
    final list = (j['events'] as List?) ?? const [];
    return (
      events: list
          .map((e) => PunchEvent.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      stats: EventStats.fromJson(
        (j['stats'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  /// Tells the device everything up to [seq] is durably stored here, so it may
  /// reclaim the space. Only call this after the records are actually saved.
  Future<EventStats> ack(int seq) async {
    final j = await _send('POST', '/events/ack', body: {'through_seq': seq});
    return EventStats.fromJson((j['events'] as Map).cast<String, dynamic>());
  }

  // --- employees ---------------------------------------------------------

  Future<List<Employee>> employees() async {
    final j = await _get('/users');
    final list = (j['employees'] as List?) ?? const [];
    return list
        .map((e) => Employee.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// [nameBitmap] is a 256-byte 1bpp 128x16 raster, already shaped and
  /// RTL-ordered here on the PC so the device never handles Arabic (D3).
  Future<void> upsertEmployee(
    int id, {
    bool active = true,
    List<int>? nameBitmap,
  }) async {
    final body = <String, dynamic>{'employee_id': id, 'active': active};
    if (nameBitmap != null) {
      body['name_bitmap_b64'] = base64Encode(nameBitmap);
    }
    await _send('POST', '/users', body: body);
  }

  /// Removes an employee and their templates from the terminal. Already gone
  /// counts as success: after "clear fingerprints" the device has forgotten
  /// everyone, and refusing to delete would leave them stuck in the app.
  Future<void> deleteEmployee(int id) async {
    try {
      await _send('DELETE', '/users', query: {'employee_id': id.toString()});
    } on ApiException catch (e) {
      if (e.statusCode == 400 && e.message.contains('unknown employee')) {
        return;
      }
      rethrow;
    }
  }

  // --- enrolment ---------------------------------------------------------

  Future<EnrollStatus> startEnroll(int employeeId, {int finger = 0}) async {
    return EnrollStatus.fromJson(
      await _send(
        'POST',
        '/enroll/start',
        body: {'employee_id': employeeId, 'finger': finger},
      ),
    );
  }

  Future<EnrollStatus> enrollStatus() async =>
      EnrollStatus.fromJson(await _get('/enroll'));

  Future<void> cancelEnroll(int sessionId) async {
    await _send(
      'POST',
      '/enroll/cancel',
      query: {'session_id': sessionId.toString()},
    );
  }

  /// Polls enrolment to completion. The device drives the actual sequence;
  /// this just mirrors it so the UI can prompt the user.
  Stream<EnrollStatus> watchEnroll({
    Duration interval = const Duration(milliseconds: 400),
    Duration timeout = const Duration(seconds: 60),
  }) async* {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final s = await enrollStatus();
      yield s;
      if (!s.isRunning) return;
      await Future<void>.delayed(interval);
    }
    throw ApiException('Enrolment timed out');
  }

  void close() => _client.close();
}
