import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_admin/data/database.dart';
import 'package:attendance_admin/data/settings.dart';
import 'package:attendance_admin/data/sync_service.dart';
import 'package:attendance_admin/main.dart';
import 'package:attendance_admin/ui/lock_page.dart';

/// Pushed pages and dialogs live on the Navigator beside the home route. When
/// AppScope wrapped only `home`, they could not see it: Timesheet -> Shifts
/// and the password dialog both crashed on AppScope.of().
void main() {
  testWidgets('pages pushed on the navigator can reach AppScope', (t) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = Settings();
    await t.runAsync(() async {
      await settings.load();
      // Locked, so the shell shows the lock page and touches no network.
      await settings.setPassword('1234');
    });
    settings.lock();

    await t.pumpWidget(
      AttendanceApp(
        settings: settings,
        db: db,
        sync: SyncService(db: db, settings: settings),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(LockPage), findsOneWidget);

    AppDatabase? seen;
    Navigator.of(t.element(find.byType(LockPage))).push(
      MaterialPageRoute<void>(
        builder: (c) {
          seen = AppScope.dbOf(c);
          return const SizedBox();
        },
      ),
    );
    await t.pumpAndSettle();
    expect(seen, same(db));
  });
}
