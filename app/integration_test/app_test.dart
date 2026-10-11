// End-to-end test of the real Windows app against tools/mock_terminal.py.
//
//   python tools/mock_terminal.py --host 192.168.137.1
//   flutter test integration_test -d windows
//
// The app runs for real -- real HTTP, real discovery sweep, real SQLite --
// but with an in-memory database and preferences, so it never touches the
// app data of an actual installation. Screenshots of each screen are written
// to build/e2e_shots/.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_admin/data/database.dart';
import 'package:attendance_admin/data/settings.dart';
import 'package:attendance_admin/data/sync_service.dart';
import 'package:attendance_admin/main.dart';

const mock = 'http://192.168.137.1';
// The mock terminal's test token (tools/mock_terminal.py DEFAULT_TOKEN).
const token = '0123456789abcdef0123456789abcdef';

final shotKey = GlobalKey();
final shotsDir = Directory('build/e2e_shots');

Future<Map<String, dynamic>> mockPost(
  String path, [
  Map<String, dynamic> body = const {},
]) async {
  final r = await http.post(
    Uri.parse('$mock$path'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  return jsonDecode(r.body) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> mockState() async =>
    jsonDecode((await http.get(Uri.parse('$mock/mock/state'))).body)
        as Map<String, dynamic>;

int epochOf(DateTime d) => d.toUtc().millisecondsSinceEpoch ~/ 1000;

/// Waits in real time: the app is doing real network and database work.
Future<void> waitFor(
  WidgetTester t,
  Finder f, {
  Duration timeout = const Duration(seconds: 30),
  String? why,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await t.pump();
    if (f.evaluate().isNotEmpty) return;
  }
  await shot(t, 'FAILED_${DateTime.now().millisecondsSinceEpoch}');
  throw TestFailure('timed out waiting for ${why ?? f}');
}

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await t.pump();
  }
}

Future<void> shot(WidgetTester t, String name) async {
  await settle(t, 300);
  final b =
      shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final img = await b.toImage(pixelRatio: 1);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  shotsDir.createSync(recursive: true);
  File(
    '${shotsDir.path}/$name.png',
  ).writeAsBytesSync(png!.buffer.asUint8List());
  // ignore: avoid_print
  print('  screenshot: $name.png');
}

void step(String s) {
  // ignore: avoid_print
  print('STEP: $s');
}

/// Clicks the field, then types, as a person does. Plain enterText does not
/// reach a field that lost focus to a button on desktop.
Future<void> type(WidgetTester t, Finder field, String text) async {
  await t.tap(field);
  await settle(t, 200);
  await t.enterText(field, text);
  await settle(t, 150);
}

Future<void> nav(WidgetTester t, String label) async {
  await t.tap(find.text(label).first);
  await settle(t);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the whole app, against a terminal on the LAN',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      await settings.load();
      final db = AppDatabase(NativeDatabase.memory());
      final sync = SyncService(db: db, settings: settings);

      await t.pumpWidget(
        RepaintBoundary(
          key: shotKey,
          child: AttendanceApp(settings: settings, db: db, sync: sync),
        ),
      );

      // ---------------------------------------------------------------------
      step('discovery: the app sweeps this PC\'s own subnets and finds it');
      final sw = Stopwatch()..start();
      await waitFor(
        t,
        find.text('Enter the device token to finish connecting'),
        timeout: const Duration(seconds: 60),
        why: 'discovery',
      );
      sw.stop();
      // ignore: avoid_print
      print('  found the terminal in ${sw.elapsedMilliseconds} ms');
      expect(find.textContaining('192.168.137.1'), findsWidgets);
      await shot(t, '01_found');

      // ---------------------------------------------------------------------
      step('a wrong token is rejected, and the app does not let you in');
      await type(t, find.byType(TextField), 'w');
      await settle(t, 300);
      // The bug: one keystroke made the app "configured" and jumped past this.
      expect(
        find.text('Enter the device token to finish connecting'),
        findsOneWidget,
        reason: 'typing one character dropped into the app',
      );
      await type(t, find.byType(TextField), 'wrongtoken');
      await t.tap(find.widgetWithText(FilledButton, 'Connect'));
      await waitFor(t, find.textContaining('rejected this token'));
      expect(settings.isConfigured, isFalse);
      await shot(t, '02_wrong_token');

      step('the right token gets in');
      await type(t, find.byType(TextField), token);
      await t.tap(find.widgetWithText(FilledButton, 'Connect'));
      await waitFor(t, find.text('Awaiting sync'), why: 'dashboard');
      expect(settings.host, '192.168.137.1');
      await shot(t, '03_dashboard_empty');

      // ---------------------------------------------------------------------
      step('employees: add two, one with an Arabic name');
      await nav(t, 'Employees');
      await waitFor(t, find.text('No employees yet'));

      Future<void> addEmployee(String name, {String? title}) async {
        await t.tap(find.text('Add employee').last);
        await settle(t, 400);
        await type(t, find.widgetWithText(TextField, 'Name'), name);
        if (title != null) {
          await type(
            t,
            find.widgetWithText(TextField, 'Job title (optional)'),
            title,
          );
        }
        await t.tap(find.widgetWithText(FilledButton, 'Add'));
        await waitFor(t, find.text(name), why: 'employee $name in list');
        await settle(t, 800);
      }

      await addEmployee('Sara Ahmed', title: 'Cashier');
      await addEmployee('محمد علي');
      var st = await mockState();
      expect(
        (st['employees'] as Map).keys.toSet(),
        {'1', '2'},
        reason: 'both must reach the terminal',
      );

      step('a duplicate ID is refused with a reason');
      await t.tap(find.text('Add employee').last);
      await settle(t, 400);
      await type(t, find.widgetWithText(TextField, 'Employee ID'), '1');
      await type(t, find.widgetWithText(TextField, 'Name'), 'Someone');
      await t.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(t, 300);
      expect(find.textContaining('already in use: Sara Ahmed'), findsOneWidget);
      await shot(t, '04_duplicate_id');
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(t, 400);

      step('enrol a finger; the dialog follows the terminal\'s states');
      await t.tap(find.text('Enrol finger').first);
      await waitFor(
        t,
        find.text('Place finger on the sensor'),
        timeout: const Duration(seconds: 10),
      );
      await shot(t, '05_enrol_place');
      await waitFor(
        t,
        find.text('Enrolled successfully'),
        timeout: const Duration(seconds: 20),
      );
      await shot(t, '06_enrol_done');
      await t.tap(find.widgetWithText(FilledButton, 'OK'));
      await settle(t, 1500);
      st = await mockState();
      expect((st['slots'] as List).length, 1);
      await shot(t, '07_employees');

      // ---------------------------------------------------------------------
      step('punches on the terminal sync in, with names');
      final now = DateTime.now();
      final yday = DateTime(now.year, now.month, now.day - 1);
      await mockPost('/mock/punch', {
        'employee_id': 1,
        'direction': 'in',
        'epoch': epochOf(yday.add(const Duration(hours: 9, minutes: 25))),
      });
      await mockPost('/mock/punch', {
        'employee_id': 1,
        'direction': 'out',
        'epoch': epochOf(yday.add(const Duration(hours: 17))),
      });
      await mockPost('/mock/punch', {
        'employee_id': 2,
        'direction': 'in',
        'epoch': epochOf(yday.add(const Duration(hours: 8, minutes: 55))),
      });

      await nav(t, 'Events');
      await t.tap(find.byTooltip('Sync now'));
      await waitFor(t, find.text('محمد علي'), why: 'synced punches');
      expect(find.text('Sara Ahmed'), findsNWidgets(2));
      st = await mockState();
      expect(st['ack'], 3, reason: 'device told it may reclaim the space');
      await shot(t, '08_events');

      Future<int> devicePunches() async => (await db.recentPunches(
        limit: 9999,
      )).where((r) => r.seq < AppDatabase.manualSeqBase).length;

      step('a manual punch, then more terminal punches still sync');
      await t.tap(find.text('Add punch'));
      await settle(t, 500);
      // Out for محمد: pick him in the dialog's employee dropdown.
      await t.tap(find.byType(DropdownButtonFormField<int>).last);
      await settle(t, 400);
      await t.tap(find.text('محمد علي').last);
      await settle(t, 300);
      await t.tap(find.text('Out').last);
      await t.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(t, 300);
      expect(
        find.textContaining('reason is required'),
        findsOneWidget,
        reason: 'a manual punch must say why',
      );
      await type(
        t,
        find.widgetWithText(TextField, 'Reason'),
        'forgot to clock out',
      );
      await t.tap(find.widgetWithText(FilledButton, 'Add'));
      await waitFor(t, find.text('Punch added'));
      await waitFor(t, find.text('Manual'));
      await shot(t, '09_manual_punch');

      // The data-loss bug: after a manual punch no terminal punch arrived again.
      await mockPost('/mock/punch', {'employee_id': 1, 'direction': 'in'});
      await t.tap(find.byTooltip('Sync now'));
      await settle(t, 2000);
      expect(
        await devicePunches(),
        4,
        reason: 'terminal punch after a manual one was not imported',
      );

      step('correct a punch time; a reason is required');
      await t.tap(find.text('محمد علي').last);
      await settle(t, 500);
      await t.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(t, 300);
      expect(find.textContaining('reason is required'), findsOneWidget);
      await type(t, find.widgetWithText(TextField, 'Reason'), 'clock check');
      await t.tap(find.widgetWithText(FilledButton, 'Save'));
      await waitFor(t, find.text('Corrected'));
      final audit = await db.recentAudit();
      expect(audit.map((a) => a.action), contains('punch.correct'));
      await shot(t, '10_corrected');

      // ---------------------------------------------------------------------
      step('timesheet: names, figures, and an Excel export');
      await nav(t, 'Timesheet');
      await waitFor(t, find.text('Sara Ahmed'), why: 'timesheet rows');
      await shot(t, '11_timesheet');

      // Straight away, before anything else rebuilds the page: the button was
      // disabled on first view until some unrelated rebuild enabled it.
      final docs = await getApplicationDocumentsDirectory();
      final target = File(
        '${docs.path}${Platform.pathSeparator}'
        'timesheet-${now.year}-${now.month.toString().padLeft(2, '0')}.xlsx',
      );
      // Someone's own report of the same name must survive the test.
      final original = target.existsSync() ? target.readAsBytesSync() : null;
      try {
        await t.tap(find.byTooltip('Export to Excel'));
        await waitFor(
          t,
          find.textContaining('Report saved'),
          timeout: const Duration(seconds: 8),
          why: 'export (button disabled on first view?)',
        );
        final msg =
            (find.textContaining('Report saved').evaluate().first.widget
                    as Text)
                .data!;
        final path = msg.substring(msg.indexOf(':') + 1).trim();
        expect(path, target.path);
        final bytes = File(path).readAsBytesSync();
        expect(
          String.fromCharCodes(bytes.take(2)),
          'PK',
          reason: 'not an xlsx',
        );
        // ignore: avoid_print
        print('  exported ${bytes.length} bytes to $path');
      } finally {
        if (original != null) {
          target.writeAsBytesSync(original);
        } else if (target.existsSync()) {
          target.deleteSync();
        }
      }

      await t.tap(find.text('Sara Ahmed'));
      await settle(t, 600);
      await shot(t, '12_timesheet_detail');
      await t.tap(find.byIcon(Icons.arrow_back).last);
      await settle(t, 400);

      // ---------------------------------------------------------------------
      step('device page: switch the terminal to CHECK OUT');
      await nav(t, 'Device');
      await waitFor(t, find.text('Each scan records'));
      await t.tap(find.text('Check out'));
      await settle(t, 300);
      await t.tap(find.text('Apply'));
      await waitFor(t, find.text('Saved'));
      st = await mockState();
      expect((st['config'] as Map)['direction'], 'out');
      final scan = await mockPost('/mock/scan', {'employee_id': 1});
      expect(scan['direction'], 'out', reason: 'terminal did not change mode');
      await shot(t, '13_device');

      step('clearing the terminal log keeps every stored punch');
      final before = await devicePunches();
      await t.ensureVisible(find.text('Clear attendance log'));
      await settle(t, 300);
      await t.tap(
        find
            .descendant(
              of: find.ancestor(
                of: find.text('Clear attendance log'),
                matching: find.byType(ListTile),
              ),
              matching: find.byType(OutlinedButton),
            )
            .first,
      );
      await settle(t, 500);
      await type(t, find.byType(TextField).last, 'CLEAR');
      await settle(t, 200);
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await waitFor(t, find.text('Device cleared'));
      st = await mockState();
      expect((st['events'] as List), isEmpty);
      // The pending scan above was pulled before the erase, not lost.
      expect(
        await devicePunches(),
        before + 1,
        reason: 'unsynced punch lost to the erase',
      );

      await mockPost('/mock/punch', {'employee_id': 2, 'direction': 'out'});
      await sync.pull();
      expect(await devicePunches(), before + 2);

      step('old firmware restarting its numbering cannot overwrite history');
      final snapshot = {
        for (final r in await db.recentPunches(limit: 9999))
          r.seq: r.deviceEpoch,
      };
      await mockPost('/mock/erase-old-firmware');
      await mockPost('/mock/punch', {'employee_id': 1, 'direction': 'in'});
      await sync.pull();
      expect(sync.lastError, isNull);
      final after = {
        for (final r in await db.recentPunches(limit: 9999))
          r.seq: r.deviceEpoch,
      };
      for (final e in snapshot.entries) {
        expect(after[e.key], e.value, reason: 'punch ${e.key} overwritten');
      }
      expect(after.length, snapshot.length + 1);

      // ---------------------------------------------------------------------
      step('removing an employee keeps their history');
      await nav(t, 'Employees');
      await waitFor(t, find.text('محمد علي'));
      final card = find.ancestor(
        of: find.text('محمد علي'),
        matching: find.byType(Card),
      );
      await t.tap(
        find.descendant(of: card, matching: find.byTooltip('Delete')),
      );
      await settle(t, 400);
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await waitFor(t, find.textContaining('Former employees'));
      expect((await db.employee(2))!.removed, isTrue);
      st = await mockState();
      expect((st['employees'] as Map).containsKey('2'), isFalse);
      await t.tap(find.textContaining('Former employees'));
      await settle(t, 400);
      await shot(t, '14_former_employee');

      await nav(t, 'Timesheet');
      await waitFor(
        t,
        find.text('محمد علي'),
        why: 'removed employee missing from this month',
      );

      // ---------------------------------------------------------------------
      step('Arabic, right to left');
      await nav(t, 'Settings');
      await t.tap(find.text('العربية'));
      await settle(t, 800);
      await shot(t, '15_settings_ar');
      await t.tap(find.text('سجل الدوام').first);
      await settle(t, 1200);
      await shot(t, '16_timesheet_ar');
      await t.tap(find.text('الموظفون').first);
      await settle(t, 1500);
      await shot(t, '17_employees_ar');

      step('the dashboard survives its own auto-refresh');
      // AsyncPage refreshed with setState(() => _future = ...), returning a
      // Future from setState: an assertion every 10 seconds on this page.
      await t.tap(find.text('لوحة المعلومات').first);
      await settle(t, 12500);
      expect(find.textContaining('Sara Ahmed'), findsWidgets);
      await shot(t, '18_dashboard_ar');

      sync.dispose();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
