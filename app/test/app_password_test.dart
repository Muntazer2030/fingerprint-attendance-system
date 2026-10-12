import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_admin/data/database.dart';
import 'package:attendance_admin/data/settings.dart';
import 'package:attendance_admin/data/sync_service.dart';
import 'package:attendance_admin/l10n/app_localizations.dart';
import 'package:attendance_admin/main.dart';
import 'package:attendance_admin/ui/lock_page.dart';
import 'package:attendance_admin/ui/settings_page.dart';
import 'package:attendance_admin/ui/shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('hashing', () {
    test('the stored form never contains the password', () {
      final h = Settings.hashPassword('1234');
      expect(h, startsWith('sha256:10000:'));
      expect(h, isNot(contains('1234')));
    });

    test('verifies the right password and rejects others', () {
      final h = Settings.hashPassword('shop-2026');
      expect(Settings.verifyPassword('shop-2026', h), isTrue);
      expect(Settings.verifyPassword('shop-2025', h), isFalse);
      expect(Settings.verifyPassword('', h), isFalse);
    });

    test('the same password hashes differently each time (salted)', () {
      expect(
        Settings.hashPassword('1234'),
        isNot(Settings.hashPassword('1234')),
      );
    });

    test('a damaged stored value never unlocks', () {
      expect(Settings.verifyPassword('1234', 'garbage'), isFalse);
    });
  });

  group('settings', () {
    test('a fresh install has no password and is not locked', () async {
      final s = Settings();
      await s.load();
      expect(s.hasPassword, isFalse);
      expect(s.locked, isFalse);
    });

    test('a saved password locks the app on the next launch', () async {
      await (Settings()..load()).setPassword('1234');

      final next = Settings();
      await next.load();
      expect(next.hasPassword, isTrue);
      expect(next.locked, isTrue);
      expect(next.unlock('0000'), isFalse);
      expect(next.locked, isTrue);
      expect(next.unlock('1234'), isTrue);
      expect(next.locked, isFalse);
    });

    test('changing the password replaces the old one', () async {
      final s = Settings();
      await s.load();
      await s.setPassword('1234');
      await s.setPassword('5678');
      expect(s.checkPassword('1234'), isFalse);
      expect(s.checkPassword('5678'), isTrue);
    });

    test('removing the password unlocks for good', () async {
      final s = Settings();
      await s.load();
      await s.setPassword('1234');
      await s.removePassword();
      final next = Settings();
      await next.load();
      expect(next.hasPassword, isFalse);
      expect(next.locked, isFalse);
    });

    test('lock does nothing without a password', () async {
      final s = Settings();
      await s.load();
      s.lock();
      expect(s.locked, isFalse);
    });

    test('the device address and token survive a restart', () async {
      final s = Settings();
      await s.load();
      await s.setConnection('192.168.1.40', 'a1b2c3d4e5f60718');

      final next = Settings();
      await next.load();
      expect(next.host, '192.168.1.40');
      expect(next.token, 'a1b2c3d4e5f60718');
      expect(next.isConfigured, isTrue);
    });
  });

  group('lock screen', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<Settings> lockedSettings() async {
      final s = Settings();
      await s.load();
      await s.setPassword('1234');
      s.lock();
      return s;
    }

    Widget app(Settings s, Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppScope(
        settings: s,
        db: db,
        sync: SyncService(db: db, settings: s),
        child: child,
      ),
    );

    // Dialogs live on the navigator above AppScope. This once crashed on Save
    // because the dialog looked settings up through AppScope.
    testWidgets('set, change and remove the password from Settings', (t) async {
      t.view.physicalSize = const Size(1200, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = Settings();
      await t.runAsync(s.load);
      await t.pumpWidget(app(s, const SettingsPage()));

      Future<void> fill(String label, String text) =>
          t.enterText(find.widgetWithText(TextField, label), text);
      Future<void> save(String button) async {
        await t.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, button),
          ),
        );
        // Hashing and the preferences write are real async work.
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await t.pumpAndSettle();
      }

      await t.tap(find.text('Set password'));
      await t.pumpAndSettle();
      await fill('New password', '12');
      await fill('Repeat the new password', '12');
      await save('Save');
      expect(find.text('Use at least 4 characters'), findsOneWidget);

      await fill('New password', '1234');
      await fill('Repeat the new password', '1243');
      await save('Save');
      expect(find.text('The passwords do not match'), findsOneWidget);

      await fill('Repeat the new password', '1234');
      await save('Save');
      expect(find.byType(AlertDialog), findsNothing);
      expect(s.checkPassword('1234'), isTrue);

      await t.tap(find.text('Change password'));
      await t.pumpAndSettle();
      await fill('Current password', 'nope');
      await fill('New password', '5678');
      await fill('Repeat the new password', '5678');
      await save('Save');
      expect(find.text('Wrong password'), findsOneWidget);
      await fill('Current password', '1234');
      await save('Save');
      expect(s.checkPassword('5678'), isTrue);

      await t.tap(find.text('Remove password').first);
      await t.pumpAndSettle();
      await fill('Current password', '5678');
      await save('Remove password');
      expect(s.hasPassword, isFalse);
      expect(find.text('Set password'), findsOneWidget);
    });

    testWidgets('a locked app shows only the lock screen', (t) async {
      final s = await t.runAsync(lockedSettings);
      await t.pumpWidget(app(s!, const AppShell()));
      expect(find.byType(LockPage), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
    });

    testWidgets('a wrong password is refused, the right one unlocks', (
      t,
    ) async {
      final s = await t.runAsync(lockedSettings);
      await t.pumpWidget(app(s!, const LockPage()));

      await t.enterText(find.byType(TextField), '9999');
      await t.tap(find.text('Unlock'));
      await t.pump();
      expect(find.text('Wrong password'), findsOneWidget);
      expect(s.locked, isTrue);

      await t.enterText(find.byType(TextField), '1234');
      await t.tap(find.text('Unlock'));
      await t.pump();
      expect(s.locked, isFalse);
    });
  });
}
