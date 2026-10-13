import 'dart:convert';
import 'dart:typed_data';

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
import 'package:attendance_admin/domain/attendance_rules.dart';
import 'package:attendance_admin/domain/roster_push.dart';

/// Reads the blobs back the way firmware/main/notify.c does, so a layout
/// mismatch between the two shows up here rather than on the terminal.
Map<int, String> parseNames(Uint8List b) {
  final out = <int, String>{};
  var p = 0;
  while (p < b.length) {
    final id = b[p] | (b[p + 1] << 8);
    final len = b[p + 2];
    out[id] = utf8.decode(b.sublist(p + 3, p + 3 + len));
    p += 3 + len;
  }
  return out;
}

Map<int, List<(int, int, int)>> parseDays(Uint8List b) {
  final bd = ByteData.sublistView(b);
  final out = <int, List<(int, int, int)>>{};
  var p = 0;
  while (p < b.length) {
    final day = bd.getUint32(p, Endian.little);
    final n = bd.getUint16(p + 4, Endian.little);
    p += 6;
    out[day] = [
      for (var i = 0; i < n; i++)
        (
          bd.getUint16(p + i * 6, Endian.little),
          bd.getInt16(p + i * 6 + 2, Endian.little),
          b[p + i * 6 + 4],
        ),
    ];
    p += n * 6;
  }
  return out;
}

void main() {
  // Mon-Fri 09:00, 10 min grace.
  const store = Shift(id: 1, name: 'Store', graceInMinutes: 10);
  const flexible = Shift(id: 2, name: 'Flex', kind: ShiftKind.flexible);

  RosterPayload build({
    List<RosterEmployee> employees = const [
      RosterEmployee(1, 'Sara'),
      RosterEmployee(2, 'Omar'),
    ],
    ShiftResolver? resolver,
    int tz = 180,
  }) => RosterPayload.build(
    employees: employees,
    resolver: resolver ?? ShiftResolver(storeDefault: store),
    from: DateTime(2026, 10, 12), // a Monday
    dayCount: 7,
    tzOffsetMin: tz,
  );

  test('days carry date, start minute and grace in the terminal layout', () {
    final days = parseDays(build().days);
    expect(days.keys, [
      20261012,
      20261013,
      20261014,
      20261015,
      20261016,
      20261017,
      20261018,
    ]);
    expect(days[20261012], [(1, 540, 10), (2, 540, 10)]);
    // The weekend is still sent, as "nobody expected", so the terminal can
    // tell a day off from a day it knows nothing about.
    expect(days[20261017], isEmpty);
  });

  test('a flexible shift is expected but has no start time', () {
    final days = parseDays(
      build(
        resolver: ShiftResolver(
          storeDefault: store,
          assignments: [
            ShiftAssignment(
              employeeId: 2,
              shift: flexible,
              from: DateTime(2026, 1, 1),
            ),
          ],
        ),
      ).days,
    );
    expect(days[20261012], contains((2, -1, 10)));
  });

  test('names arrive as UTF-8 text, Arabic included', () {
    final names = parseNames(
      build(employees: const [RosterEmployee(7, 'سارة أحمد')]).names,
    );
    expect(names, {7: 'سارة أحمد'});
  });

  test('long names are cut on a character boundary', () {
    final long = 'محمد' * 20; // 160 bytes
    final cut = RosterPayload.truncateUtf8(long, RosterPayload.maxNameBytes);
    expect(cut.length, lessThanOrEqualTo(RosterPayload.maxNameBytes));
    expect(() => utf8.decode(cut), returnsNormally);
    expect(long.startsWith(utf8.decode(cut)), isTrue);
  });

  test('version is stable, and changes with anything the terminal sees', () {
    final a = build().version;
    expect(build().version, a);
    expect(
      build(
        employees: const [
          RosterEmployee(1, 'Sara A'),
          RosterEmployee(2, 'Omar'),
        ],
      ).version,
      isNot(a),
    );
    expect(build(tz: 120).version, isNot(a));
    expect(
      build(
        resolver: ShiftResolver(
          storeDefault: const Shift(id: 1, name: 'Store', startMinute: 600),
        ),
      ).version,
      isNot(a),
    );
    expect(a, isNot(0), reason: '0 means "no roster" on the terminal');
  });

  test('a full store fits the terminal storage', () {
    final p = RosterPayload.build(
      employees: [
        for (var i = 1; i <= 64; i++) RosterEmployee(i, 'محمد عبد الرحمن' * 3),
      ],
      resolver: ShiftResolver(
        storeDefault: const Shift(id: 1, name: 'All week', daysMask: 0x7F),
      ),
      from: DateTime(2026, 10, 12),
      tzOffsetMin: 180,
    );
    // notify.c: three 4 KB sectors, minus a 12-byte header and 8-byte roster
    // header.
    expect(8 + p.names.length + p.days.length, lessThan(3 * 4096 - 12));
  });

  group('sync pushes the roster', () {
    late AppDatabase db;
    late SyncService sync;
    var pushes = 0;
    var deviceVersion = 0;
    var notifyRoutes = true;

    ApiClient api() => ApiClient(
      host: '10.0.0.9',
      token: 'tok',
      client: MockClient((req) async {
        final path = req.url.path;
        if (path == '/api/v1/users') {
          return http.Response('{"employees":[],"slots":[]}', 200);
        }
        if (path == '/api/v1/events') {
          return http.Response(
            '{"events":[],"count":0,"stats":{"head":0,"ack":0}}',
            200,
          );
        }
        if (!notifyRoutes) return http.Response('{"error":"nf"}', 404);
        if (path == '/api/v1/notify') {
          return http.Response(
            jsonEncode({'roster_version': deviceVersion}),
            200,
          );
        }
        if (path == '/api/v1/roster') {
          pushes++;
          deviceVersion = jsonDecode(req.body)['version'] as int;
          return http.Response(
            jsonEncode({'roster_version': deviceVersion}),
            200,
          );
        }
        return http.Response('{"error":"nf"}', 404);
      }),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      await settings.load();
      db = AppDatabase(NativeDatabase.memory());
      sync = SyncService(db: db, settings: settings);
      pushes = 0;
      deviceVersion = 0;
      notifyRoutes = true;
      await db.upsertEmployee(
        EmployeesCompanion.insert(
          id: const Value(1),
          name: const Value('Sara'),
        ),
      );
    });
    tearDown(() => db.close());

    test('once when the terminal lacks it, then not again', () async {
      await sync.pull(api());
      expect(pushes, 1);
      await sync.pull(api());
      await sync.pull(api());
      expect(pushes, 1, reason: 'unchanged roster pushed again');
      expect(sync.rosterError, isNull);
    });

    test('again when a name changes', () async {
      await sync.pull(api());
      await db.upsertEmployee(
        const EmployeesCompanion(id: Value(1), name: Value('Sara Ahmed')),
      );
      await sync.pull(api());
      expect(pushes, 2);
    });

    test('older firmware without the routes does not break sync', () async {
      notifyRoutes = false;
      await sync.pull(api());
      expect(sync.lastError, isNull);
      expect(sync.rosterError, isNull);
      expect(pushes, 0);
    });
  });
}
