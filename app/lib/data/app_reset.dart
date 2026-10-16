import 'database.dart';
import 'settings.dart';
import 'sync_service.dart';

/// "Reset app": everything this PC holds goes, the terminal is not touched.
///
/// Order matters. Syncing stops first so a round in flight cannot write into
/// the emptied database, and settings go last because clearing them is what
/// sends the app back to the connect screen.
Future<void> resetApp({
  required Settings settings,
  required AppDatabase db,
  required SyncService sync,
}) async {
  await sync.stop();
  await db.wipe();
  await settings.reset();
}
