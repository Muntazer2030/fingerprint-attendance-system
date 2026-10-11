import 'package:flutter/material.dart';

import 'data/database.dart';
import 'data/settings.dart';
import 'data/sync_service.dart';
import 'l10n/app_localizations.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = Settings();
  await settings.load();
  final db = AppDatabase();
  runApp(
    AttendanceApp(
      settings: settings,
      db: db,
      sync: SyncService(db: db, settings: settings),
    ),
  );
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({
    super.key,
    required this.settings,
    required this.db,
    required this.sync,
  });

  final Settings settings;
  final AppDatabase db;
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitle,
          debugShowCheckedModeBanner: false,
          locale: settings.locale,
          // flutter_localizations supplies RTL direction and the Material
          // widget translations; app strings come from lib/l10n.
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          home: AppScope(
            settings: settings,
            db: db,
            sync: sync,
            child: const AppShell(),
          ),
        );
      },
    );
  }
}

/// Carries the app-wide singletons without pulling in a state-management
/// package. Settings drives rebuilds; the database and sync service are stable
/// references for their lifetime.
class AppScope extends InheritedNotifier<Settings> {
  const AppScope({
    super.key,
    required Settings settings,
    required this.db,
    required this.sync,
    required super.child,
  }) : super(notifier: settings);

  final AppDatabase db;
  final SyncService sync;

  static AppScope _of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing from the widget tree');
    return scope!;
  }

  static Settings settingsOf(BuildContext c) => _of(c).notifier!;
  static AppDatabase dbOf(BuildContext c) => _of(c).db;
  static SyncService syncOf(BuildContext c) => _of(c).sync;

  @override
  bool updateShouldNotify(covariant AppScope oldWidget) =>
      super.updateShouldNotify(oldWidget) ||
      db != oldWidget.db ||
      sync != oldWidget.sync;
}

/// Back-compat alias so pages can keep asking for settings directly.
class SettingsScope {
  static Settings of(BuildContext context) => AppScope.settingsOf(context);
}
