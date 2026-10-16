import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_admin/data/app_reset.dart';
import 'package:attendance_admin/data/database.dart';
import 'package:attendance_admin/data/settings.dart';
import 'package:attendance_admin/data/sync_service.dart';
import 'package:attendance_admin/l10n/app_localizations.dart';
import 'package:attendance_admin/main.dart';
import 'package:attendance_admin/ui/reset_app_dialog.dart';
import 'package:attendance_admin/ui/settings_page.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  /// A configured, password-protected app with data in several tables.
  Future<Settings> populated() async {
    final s = Settings();
    await s.load();
    await s.setConnection('192.168.1.40', 'a1b2c3d4e5f60718');
    await s.setPassword('1234');
    await s.setCurrency('IQD');
    await s.setLocale(const Locale('ar'));
    await s.setSyncedThroughSeq(31);

    await db
        .into(db.employees)
        .insert(
          EmployeesCompanion.insert(
            id: const Value(3),
            name: const Value('Ali'),
          ),
        );
    await db.storePunches([
      PunchesCompanion.insert(
        seq: const Value(1),
        deviceEpoch: 1760000000,
        employeeId: 3,
        direction: 0,
      ),
    ]);
    await db
        .into(db.wages)
        .insert(
          WagesCompanion.insert(
            employeeId: 3,
            fromMonth: 202610,
            kind: 0,
            amountCents: 75000000,
          ),
        );
    await db.setMetaInt('device_seq_base', 5);
    return s;
  }

  Future<int> rowsLeft() async {
    var n = 0;
    for (final t in db.allTables) {
      n += await db.select(t).get().then((r) => r.length);
    }
    return n;
  }

  test('reset empties every table and every preference', () async {
    final s = await populated();
    expect(await rowsLeft(), greaterThan(0));

    await resetApp(
      settings: s,
      db: db,
      sync: SyncService(db: db, settings: s),
    );

    expect(await rowsLeft(), 0);
    expect(s.isConfigured, isFalse);
    expect(s.rememberedToken, isEmpty);
    expect(s.hasPassword, isFalse);
    expect(s.locked, isFalse);
    expect(s.currency, isEmpty);
    expect(s.locale.languageCode, 'en');
    expect(s.syncedThroughSeq, 0);

    // And it stays that way on the next launch.
    final next = Settings();
    await next.load();
    expect(next.isConfigured, isFalse);
    expect(next.hasPassword, isFalse);
    expect(next.syncedThroughSeq, 0);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  testWidgets('Settings asks for the word and the password before resetting', (
    t,
  ) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final s = (await t.runAsync(populated))!;
    await t.runAsync(() => s.setLocale(const Locale('en')));
    s.unlock('1234');

    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppScope(
          settings: s,
          db: db,
          sync: SyncService(db: db, settings: s),
          child: child!,
        ),
        home: const SettingsPage(),
      ),
    );

    await t.tap(find.widgetWithText(OutlinedButton, 'Reset app'));
    await t.pumpAndSettle();
    expect(find.byType(ResetAppDialog), findsOneWidget);

    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Reset app'),
    );
    bool enabled() => t.widget<FilledButton>(confirm).onPressed != null;

    // Disabled until the word is typed.
    expect(enabled(), isFalse);
    await t.enterText(
      find.widgetWithText(TextField, 'Type RESET to confirm'),
      'reset',
    );
    await t.pump();
    expect(enabled(), isTrue);

    // A wrong password is refused and nothing is deleted.
    await t.enterText(
      find.widgetWithText(TextField, 'Current password'),
      '9999',
    );
    await t.tap(confirm);
    await t.pump();
    expect(find.text('Wrong password'), findsOneWidget);
    expect(s.isConfigured, isTrue);

    // Cancel leaves everything alone.
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.byType(ResetAppDialog), findsNothing);
    expect(s.hasPassword, isTrue);

    await t.tap(find.widgetWithText(OutlinedButton, 'Reset app'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Type RESET to confirm'),
      'RESET',
    );
    await t.enterText(
      find.widgetWithText(TextField, 'Current password'),
      '1234',
    );
    await t.pump();
    await t.tap(confirm);
    // The wipe and the preferences write are real async work.
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();

    expect(find.byType(ResetAppDialog), findsNothing);
    expect(s.isConfigured, isFalse);
    expect(s.hasPassword, isFalse);
    expect(await t.runAsync(rowsLeft), 0);
  });

  testWidgets('the Arabic word works, and so does the English one', (t) async {
    final s = Settings();
    await t.runAsync(s.load);
    await t.runAsync(() => s.setLocale(const Locale('ar')));

    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ResetAppDialog(settings: s)),
      ),
    );

    final confirm = find.widgetWithText(FilledButton, 'إعادة ضبط التطبيق');
    bool enabled() => t.widget<FilledButton>(confirm).onPressed != null;
    final field = find.byType(TextField);

    expect(enabled(), isFalse);
    await t.enterText(field, 'حذف');
    await t.pump();
    expect(enabled(), isTrue);
    await t.enterText(field, 'RESET');
    await t.pump();
    expect(enabled(), isTrue);
    await t.enterText(field, 'حذ');
    await t.pump();
    expect(enabled(), isFalse);
  });
}
