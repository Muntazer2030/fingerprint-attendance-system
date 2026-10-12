import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_admin/data/database.dart';
import 'package:attendance_admin/data/settings.dart';
import 'package:attendance_admin/data/sync_service.dart';
import 'package:attendance_admin/domain/payroll.dart';
import 'package:attendance_admin/l10n/app_localizations.dart';
import 'package:attendance_admin/main.dart';
import 'package:attendance_admin/ui/payroll_page.dart';

/// Drives the payroll page against an in-memory database: no device needed.
void main() {
  late AppDatabase db;
  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> seed(WidgetTester t) => t.runAsync(() async {
    await db.upsertEmployee(
      EmployeesCompanion.insert(id: const Value(1), name: const Value('Sara')),
    );
    await db.upsertEmployee(
      EmployeesCompanion.insert(id: const Value(2), name: const Value('Omar')),
    );
    final now = DateTime.now();
    await PayrollRepository(db).setWage(
      1,
      DateTime(now.year, now.month),
      const Wage(kind: WageKind.monthly, amount: 3000),
    );
  });

  Future<void> pump(
    WidgetTester t, {
    Locale locale = const Locale('en'),
  }) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await settings.setLocale(locale);
    await t.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppScope(
          settings: settings,
          db: db,
          sync: SyncService(db: db, settings: settings),
          child: const ScaffoldMessenger(child: PayrollPage()),
        ),
      ),
    );
    await settle(t);
  }

  testWidgets('lists employees, flags a missing wage, opens a payslip', (
    t,
  ) async {
    await seed(t);
    await pump(t);

    expect(find.text('Payroll'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.textContaining('No wage set'), findsWidgets);
    expect(find.text('Mark month as paid'), findsOneWidget);

    await t.tap(find.text('Sara'));
    await settle(t);
    expect(find.text('Net pay'), findsOneWidget);
    expect(find.text('Base pay'), findsOneWidget);
    expect(find.textContaining('Monthly salary'), findsOneWidget);
  });

  testWidgets('adds a bonus to a payslip', (t) async {
    await seed(t);
    await pump(t);
    await t.tap(find.text('Sara'));
    await settle(t);

    await t.tap(find.widgetWithText(TextButton, 'Add'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextField, 'Amount'), '150');
    await t.enterText(find.widgetWithText(TextField, 'Note'), 'Eid');
    await t.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(t);

    expect(find.textContaining('+150.00'), findsOneWidget);
    expect(find.text('Eid'), findsOneWidget);
  });

  testWidgets('marking paid freezes the month and offers reopen', (t) async {
    await seed(t);
    await pump(t);

    await t.tap(find.text('Mark month as paid'));
    await settle(t);
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Mark month as paid'),
      ),
    );
    await settle(t);

    expect(find.textContaining('These figures are frozen'), findsOneWidget);
    expect(find.text('Reopen'), findsOneWidget);
    expect(find.text('Mark month as paid'), findsNothing);
  });

  testWidgets('renders in Arabic', (t) async {
    await seed(t);
    await pump(t, locale: const Locale('ar'));
    expect(find.text('الرواتب'), findsOneWidget);
    expect(find.text('اعتماد صرف الشهر'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

/// The page loads from the database, which completes on real IO; let it run,
/// then let the frames that follow settle.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
  }
  await t.pumpAndSettle();
}
