import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_admin/data/api_client.dart';
import 'package:attendance_admin/data/database.dart';
import 'package:attendance_admin/data/settings.dart';
import 'package:attendance_admin/data/sync_service.dart';

/// A terminal in memory, speaking the real wire format. Enough of the
/// firmware's event log to exercise sync end to end: monotonic sequence
/// numbers, a ring that serves everything after `since`, acks, and -- the
/// case that used to lose data -- an erase that restarts numbering at 1 the
/// way older firmware did.
class FakeTerminal {
  final events = <Map<String, dynamic>>[];
  final employees = <int, Map<String, dynamic>>{};
  int head = 0;
  int ack = 0;
  int eventsRequests = 0;

  void punch(int employee, DateTime at, {bool out = false}) {
    head++;
    events.add({
      'seq': head,
      'epoch': at.toUtc().millisecondsSinceEpoch ~/ 1000,
      'employee_id': employee,
      'slot': 0,
      'direction': out ? 'out' : 'in',
      'method': 'finger',
      'manual': false,
      'provisional_time': false,
    });
  }

  /// What `POST /reset {"scope":"events"}` did before the firmware fix.
  void eraseRestartingNumbering() {
    events.clear();
    head = 0;
    ack = 0;
  }

  Map<String, dynamic> get stats => {
    'head': head,
    'ack': ack,
    'pending': head - ack,
    'oldest': events.isEmpty ? 0 : events.first['seq'],
    'capacity': 40960,
    'overflow': false,
  };

  http.Client client() => MockClient((req) async {
    final path = req.url.path;
    if (req.headers['Authorization'] != 'Bearer tok') {
      return http.Response('{"error":"unauthorized"}', 401);
    }
    if (path == '/api/v1/events' && req.method == 'GET') {
      eventsRequests++;
      final since = int.parse(req.url.queryParameters['since'] ?? '0');
      final limit = int.parse(req.url.queryParameters['limit'] ?? '100');
      final out = events
          .where((e) => (e['seq'] as int) > since)
          .take(limit)
          .toList();
      return http.Response(
        jsonEncode({'events': out, 'count': out.length, 'stats': stats}),
        200,
      );
    }
    if (path == '/api/v1/events/ack') {
      final through = jsonDecode(req.body)['through_seq'] as int;
      if (through > ack) ack = through.clamp(0, head);
      return http.Response(jsonEncode({'events': stats}), 200);
    }
    if (path == '/api/v1/users' && req.method == 'GET') {
      return http.Response(
        jsonEncode({'employees': employees.values.toList()}),
        200,
      );
    }
    if (path == '/api/v1/users' && req.method == 'POST') {
      final j = jsonDecode(req.body) as Map<String, dynamic>;
      final id = j['employee_id'] as int;
      employees[id] = {
        'employee_id': id,
        'active': j['active'] ?? true,
        'last_direction': 'in',
        'last_epoch': 0,
        'fail_count': 0,
        'fingers': 0,
      };
      return http.Response(jsonEncode({'employee_id': id}), 200);
    }
    if (path == '/api/v1/users' && req.method == 'DELETE') {
      final id = int.parse(req.url.queryParameters['employee_id']!);
      if (employees.remove(id) == null) {
        return http.Response('{"error":"unknown employee_id"}', 400);
      }
      return http.Response(jsonEncode({'deleted': true}), 200);
    }
    return http.Response('{"error":"not found"}', 404);
  });
}

void main() {
  late AppDatabase db;
  late Settings settings;
  late SyncService sync;
  late FakeTerminal terminal;
  late ApiClient api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    await settings.load();
    db = AppDatabase(NativeDatabase.memory());
    sync = SyncService(db: db, settings: settings);
    terminal = FakeTerminal();
    api = ApiClient(host: '10.0.0.5', token: 'tok', client: terminal.client());
  });

  tearDown(() async {
    await db.close();
  });

  /// Everything stored, in sequence order.
  Future<List<PunchRow>> stored() async =>
      (await db.recentPunches(limit: 1000))
        ..sort((a, b) => a.seq.compareTo(b.seq));

  test('punches are imported, then acked', () async {
    terminal.punch(1, DateTime(2026, 9, 1, 9));
    terminal.punch(1, DateTime(2026, 9, 1, 17), out: true);

    await sync.pull(api);

    expect(sync.lastError, isNull);
    expect((await stored()).map((r) => r.seq), [1, 2]);
    expect(terminal.ack, 2, reason: 'device may only reclaim what is stored');
  });

  test(
    'a manual punch does not stop fingerprint punches being imported',
    () async {
      // The regression: the manual row's seq (0x40000000) became the high-water
      // mark, the next pull asked for events after it, and nothing ever arrived
      // again.
      terminal.punch(1, DateTime(2026, 9, 1, 9));
      await sync.pull(api);

      await sync.addManualPunch(
        employeeId: 1,
        at: DateTime(2026, 9, 1, 17),
        isOut: true,
        reason: 'sensor would not read',
      );

      terminal.punch(2, DateTime(2026, 9, 2, 9));
      terminal.punch(2, DateTime(2026, 9, 2, 17), out: true);
      await sync.pull(api);

      final rows = await stored();
      expect(
        rows.where((r) => r.method == 0).map((r) => r.seq),
        [1, 2, 3],
        reason: 'device punches after the manual one were never imported',
      );
      expect(rows.where((r) => r.method == 1), hasLength(1));
      expect(terminal.ack, 3);
    },
  );

  test('manual punches number upward in their own range', () async {
    for (var i = 0; i < 3; i++) {
      await sync.addManualPunch(
        employeeId: 1,
        at: DateTime(2026, 9, 1, 9 + i),
        isOut: i.isOdd,
        reason: 'test',
      );
    }
    final seqs = (await stored()).map((r) => r.seq).toList()..sort();
    expect(seqs, [
      AppDatabase.manualSeqBase,
      AppDatabase.manualSeqBase + 1,
      AppDatabase.manualSeqBase + 2,
    ]);
    expect(await db.highWaterSeq(), 0);
  });

  test('clearing the terminal log never overwrites stored history', () async {
    terminal.punch(1, DateTime(2026, 9, 1, 9));
    terminal.punch(1, DateTime(2026, 9, 1, 17), out: true);
    terminal.punch(2, DateTime(2026, 9, 1, 8));
    await sync.pull(api);

    terminal.eraseRestartingNumbering();
    terminal.punch(3, DateTime(2026, 9, 2, 10));
    await sync.pull(api);

    final rows = await stored();
    expect(
      rows,
      hasLength(4),
      reason: 'the new punch either vanished or replaced an old one',
    );
    // The old three are untouched.
    expect(rows.take(3).map((r) => r.employeeId), [1, 1, 2]);
    // The new one is numbered after them.
    expect(rows.last.employeeId, 3);
    expect(rows.last.seq, 4);
    expect(terminal.ack, 1, reason: 'ack must use the device\'s own numbering');

    // And later punches keep flowing.
    terminal.punch(3, DateTime(2026, 9, 2, 18), out: true);
    await sync.pull(api);
    expect(await stored(), hasLength(5));
  });

  test(
    'a cleared log that has already grown past the old mark is detected',
    () async {
      // Head alone cannot catch this: after the erase the terminal recorded
      // more punches than the PC had seen, so its head is higher again. The
      // record at our old mark is a different punch, which gives it away.
      terminal.punch(1, DateTime(2026, 9, 1, 9));
      terminal.punch(1, DateTime(2026, 9, 1, 17), out: true);
      await sync.pull(api);

      terminal.eraseRestartingNumbering();
      for (var i = 0; i < 5; i++) {
        terminal.punch(7, DateTime(2026, 9, 3, 8 + i), out: i.isOdd);
      }
      await sync.pull(api);

      final rows = await stored();
      expect(rows, hasLength(7));
      expect(
        rows.where((r) => r.employeeId == 1),
        hasLength(2),
        reason: 'history was overwritten',
      );
      expect(
        rows.where((r) => r.employeeId == 7),
        hasLength(5),
        reason: 'new punches 1 and 2 were skipped',
      );
    },
  );

  test('an unchanged terminal is not mistaken for a cleared one', () async {
    terminal.punch(1, DateTime(2026, 9, 1, 9));
    await sync.pull(api);
    terminal.punch(1, DateTime(2026, 9, 1, 17), out: true);
    await sync.pull(api);
    await sync.pull(api);

    expect((await stored()).map((r) => r.seq), [1, 2]);
    expect(await db.metaInt('device_seq_base'), isNull);
  });

  test('removing someone with history keeps them for past reports', () async {
    await sync.saveEmployee(api, id: 5, name: 'Sara');
    terminal.punch(5, DateTime(2026, 9, 1, 9));
    await sync.pull(api);

    await sync.removeEmployee(api, 5);

    expect(terminal.employees.containsKey(5), isFalse);
    final row = await db.employee(5);
    expect(row, isNotNull, reason: 'history lost its name');
    expect(row!.removed, isTrue);
    expect(row.name, 'Sara');
  });

  test('removing someone who never punched drops them entirely', () async {
    await sync.saveEmployee(api, id: 6, name: 'Temp');
    await sync.removeEmployee(api, 6);
    expect(await db.employee(6), isNull);
  });

  test('removing someone the terminal already forgot still works', () async {
    // After "clear fingerprints" the terminal knows nobody; its 400 used to
    // make them impossible to remove from the app.
    await db.upsertEmployee(
      const EmployeesCompanion(id: Value(9), name: Value('Ghost')),
    );
    await sync.removeEmployee(api, 9);
    expect(await db.employee(9), isNull);
  });

  test('a correction keeps the recorded time and is audited', () async {
    terminal.punch(1, DateTime(2026, 9, 1, 9));
    await sync.pull(api);

    final fixed = DateTime(2026, 9, 1, 8, 55);
    await sync.correctPunch(seq: 1, at: fixed, reason: 'clock drift');

    final row = (await db.punch(1))!;
    expect(
      row.deviceEpoch,
      DateTime(2026, 9, 1, 9).toUtc().millisecondsSinceEpoch ~/ 1000,
    );
    expect(row.correctedEpoch, fixed.toUtc().millisecondsSinceEpoch ~/ 1000);
    final audit = await db.recentAudit();
    expect(audit.first.action, 'punch.correct');
  });

  test('device punches cannot be deleted, manual ones can', () async {
    terminal.punch(1, DateTime(2026, 9, 1, 9));
    await sync.pull(api);
    await sync.addManualPunch(
      employeeId: 1,
      at: DateTime(2026, 9, 1, 17),
      isOut: true,
      reason: 'x',
    );

    await sync.deleteManualPunch(1);
    await sync.deleteManualPunch(AppDatabase.manualSeqBase);

    final rows = await stored();
    expect(rows.map((r) => r.seq), [1]);
  });

  test('a caller waits for a sync already in progress', () async {
    // "Pull, then clear the terminal" relies on this: returning early while
    // another round was mid-flight would clear punches not yet stored.
    terminal.punch(1, DateTime(2026, 9, 1, 9));
    final first = sync.pull(api);
    final second = sync.pull(api);
    await second;
    expect(
      await stored(),
      hasLength(1),
      reason: 'second caller returned before the round finished',
    );
    await first;
  });
}
