import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Writes into the documents directory and returns the full path so the UI
/// can tell the user where it went.
Future<String?> platformSaveFile(String name, Uint8List bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
