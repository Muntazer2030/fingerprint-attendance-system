// Screenshots for the user guide, taken from the real Windows app.
//
//   python tools/mock_terminal.py --host 127.0.0.1 --port 8080   (fresh)
//   flutter test integration_test/guide_screens_test.dart -d windows \
//       --dart-define=GUIDE_LANG=en        (or ar)
//
// Talks only to the mock on 127.0.0.1, never to a terminal on the network,
// and uses an in-memory database and preferences, so a real installation's
// data is never touched. Pictures go to build/guide_shots/<lang>/.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_admin/data/database.dart';
import 'package:attendance_admin/data/settings.dart';
import 'package:attendance_admin/data/sync_service.dart';
import 'package:attendance_admin/domain/payroll.dart';
import 'package:attendance_admin/l10n/app_localizations.dart';
import 'package:attendance_admin/main.dart';

const mock = 'http://127.0.0.1:8080';
const token = '0123456789abcdef0123456789abcdef';
const lang = String.fromEnvironment('GUIDE_LANG', defaultValue: 'en');

final shotKey = GlobalKey();
final shotsDir = Directory('build/guide_shots/$lang');

Future<void> mockPost(String path, Map<String, dynamic> body) => http.post(
  Uri.parse('$mock$path'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode(body),
);

Future<void> settle(WidgetTester t, [int ms = 700]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await t.pump();
  }
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 20}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await t.pump();
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('timed out waiting for $f');
}

Future<void> shot(WidgetTester t, String name) async {
  await settle(t, 900);
  final b =
      shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final img = await b.toImage(pixelRatio: 1.5);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  shotsDir.createSync(recursive: true);
  File(
    '${shotsDir.path}/$name.png',
  ).writeAsBytesSync(png!.buffer.asUint8List());
  // ignore: avoid_print
  print('  screenshot: $name.png');
}

Future<void> nav(WidgetTester t, String label) async {
  await t.tap(find.text(label).first);
  await settle(t, 1500);
}

/// Scrolls [f] to the middle of its list: clear of the app bar above and of
/// floating buttons below, where a tap can actually land on it.
Future<void> center(WidgetTester t, Finder f) async {
  await Scrollable.ensureVisible(t.element(f), alignment: 0.5);
  await settle(t);
}

Future<void> typeInto(WidgetTester t, Finder field, String text) async {
  await t.tap(field);
  await settle(t, 200);
  await t.enterText(field, text);
  await settle(t, 200);
}

Future<void> closeDialog(WidgetTester t, AppLocalizations l) async {
  await t.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, l.cancel),
    ),
  );
  await settle(t);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guide screenshots ($lang)', (t) async {
    final ar = lang == 'ar';
    final l = lookupAppLocalizations(Locale(lang));
    final names = ar
        ? ['سارة أحمد', 'عمر حسن', 'علي كريم']
        : ['Sara Ahmed', 'Omar Hassan', 'Ali Kareem'];
    final titles = ar
        ? ['كاشير', 'مخزن', 'مبيعات']
        : ['Cashier', 'Stock', 'Sales'];

    SharedPreferences.setMockInitialValues({});
    final settings = Settings();
    await settings.load();
    await settings.setLocale(Locale(lang));
    await settings.setThemeMode(ThemeMode.light);
    await settings.setCurrency(ar ? 'د.ع' : 'IQD');
    await settings.setConnection('127.0.0.1:8080', token);
    final db = AppDatabase(NativeDatabase.memory());
    final sync = SyncService(db: db, settings: settings);
    final api = sync.client();

    // --- data: three staff, two weeks of punches -------------------------
    for (var i = 0; i < 3; i++) {
      await sync.saveEmployee(
        api,
        id: i + 1,
        name: names[i],
        jobTitle: titles[i],
      );
    }
    int ep(int d, int h, int m) =>
        DateTime(2026, 10, d, h, m).toUtc().millisecondsSinceEpoch ~/ 1000;
    Future<void> punch(int emp, bool out, int epoch) => mockPost(
      '/mock/punch',
      {'employee_id': emp, 'direction': out ? 'out' : 'in', 'epoch': epoch},
    );
    for (final d in [1, 2, 5, 6, 7, 8, 9, 12, 13]) {
      if (d != 8) {
        // Sara: late on the 5th, absent on the 8th.
        await punch(1, false, d == 5 ? ep(d, 9, 35) : ep(d, 9, 2));
        await punch(1, true, ep(d, 17, 4));
      }
      // Omar: stays late every day; forgot to check out on the 7th.
      await punch(2, false, ep(d, 8, 55));
      if (d != 7) await punch(2, true, ep(d, 18, 30));
      if (d != 12) {
        // Ali: on time; absent on the 12th (excused later as sick leave).
        await punch(3, false, ep(d, 8, 58));
        await punch(3, true, ep(d, 17, 1));
      }
    }
    await punch(1, false, ep(14, 8, 57));
    await punch(2, false, ep(14, 9, 40));
    await punch(3, false, ep(14, 8, 59));
    await sync.pull(api);

    // Wages in Iraqi dinar; Sara's is set on screen below.
    final pay = PayrollRepository(db);
    final oct = DateTime(2026, 10);
    await pay.setWage(
      2,
      oct,
      const Wage(kind: WageKind.monthly, amount: 600000),
    );
    await pay.setWage(
      3,
      oct,
      const Wage(kind: WageKind.monthly, amount: 650000),
    );
    await pay.addAdjustment(
      2,
      oct,
      PayAdjustment(
        kind: AdjustmentKind.advance,
        amount: 100000,
        note: ar ? 'سلفة 6 أكتوبر' : 'Salary advance, Oct 6',
      ),
    );
    await pay.setOverrides(3, oct, const PayOverrides(absentDays: 0));

    // Telegram set up on the (mock) terminal, so its page shows "active".
    await api.setNotify(
      enabled: true,
      eachPunch: true,
      late: true,
      summaryMinute: 22 * 60,
      chatId: '123456789',
      botToken: '123456789:AAguideScreenshotTokenNotRealXXXXabcd',
    );
    await sync.pushRosterNow(api);

    await t.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: AttendanceApp(settings: settings, db: db, sync: sync),
      ),
    );
    await settle(t, 3000);

    // --- pages ----------------------------------------------------------
    await waitFor(t, find.text(names[1]));
    await shot(t, 'dashboard');

    await nav(t, l.navEmployees);
    await waitFor(t, find.text(names[2]));
    await shot(t, 'employees');

    await nav(t, l.navEvents);
    await settle(t, 1500);
    await shot(t, 'events');
    await t.tap(find.text(l.addPunch).last);
    await settle(t);
    await shot(t, 'add-punch');
    await closeDialog(t, l);

    await nav(t, l.navTimesheet);
    await waitFor(t, find.text(names[1]));
    await shot(t, 'timesheet');
    await t.tap(find.text(names[1]));
    await settle(t);
    await shot(t, 'timesheet-days');

    await t.tap(find.byTooltip(l.schedules));
    await settle(t, 1500);
    await shot(t, 'shifts');
    await t.tap(find.byIcon(Icons.edit_outlined).first);
    await settle(t);
    await shot(t, 'edit-shift');
    await closeDialog(t, l);
    await t.tap(find.byType(BackButton).first);
    await settle(t);

    // Payroll.
    await nav(t, l.navPayroll);
    await waitFor(t, find.text(names[0]));
    await t.tap(find.text(names[0]));
    await settle(t);
    await t.tap(find.text(l.setWage));
    await settle(t);
    await typeInto(
      t,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '750000',
    );
    await shot(t, 'set-wage');
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, l.save),
      ),
    );
    await settle(t, 1500);
    await shot(t, 'payslip');
    await t.tap(find.byIcon(Icons.arrow_back).first);
    await settle(t, 1500);
    await shot(t, 'payroll');

    await t.tap(find.text(names[1]));
    await settle(t, 1500);
    await shot(t, 'payslip-advance');
    await t.tap(find.text(l.add).last);
    await settle(t);
    await t.tap(find.text(l.bonus).last);
    await typeInto(
      t,
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first,
      '50000',
    );
    await typeInto(
      t,
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .last,
      ar ? 'مكافأة المبيعات' : 'Sales bonus',
    );
    await shot(t, 'adjustment');
    await closeDialog(t, l);
    await t.tap(find.byIcon(Icons.arrow_back).first);
    await settle(t, 1500);

    await t.tap(find.text(names[2]));
    await settle(t, 1500);
    await shot(t, 'payslip-edited');
    await t.tap(find.byIcon(Icons.arrow_back).first);
    await settle(t, 1500);

    await t.tap(find.byTooltip(l.payRules));
    await settle(t, 1500);
    await shot(t, 'pay-rules');
    await closeDialog(t, l);

    // Device, Wi-Fi, Telegram.
    await nav(t, l.navDevice);
    await settle(t, 1500);
    await shot(t, 'device');

    await t.scrollUntilVisible(
      find.text(l.wifiTileHelp),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await center(t, find.text(l.wifiTileHelp));
    await t.tap(find.text(l.wifiTileHelp));
    await waitFor(t, find.text(l.wifiScan));
    await t.tap(find.text(l.wifiScan));
    await waitFor(t, find.text('Store-WiFi'), seconds: 10);
    await t.tap(find.text('Store-WiFi'));
    await settle(t);
    await shot(t, 'wifi');
    await t.tap(find.byType(BackButton).first);
    await settle(t, 1200);

    await t.scrollUntilVisible(
      find.text(l.tgTileHelp),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await center(t, find.text(l.tgTileHelp));
    await t.tap(find.text(l.tgTileHelp));
    await waitFor(t, find.text(l.tgStepBot));
    await settle(t, 1500);
    await shot(t, 'telegram');
    await t.scrollUntilVisible(
      find.text(l.tgSendTest),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(t);
    await shot(t, 'telegram-what');
    await t.tap(find.byType(BackButton).first);
    await settle(t, 1200);

    // Settings, password, lock screen.
    await settings.setPassword('1234');
    await nav(t, l.navSettings);
    await settle(t, 1200);
    await shot(t, 'settings-password');
    settings.lock();
    await settle(t, 1200);
    await shot(t, 'lock');
    settings.unlock('1234');
    await settle(t);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
