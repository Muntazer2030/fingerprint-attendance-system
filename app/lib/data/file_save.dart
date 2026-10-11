import 'dart:typed_data';

import 'file_save_stub.dart'
    if (dart.library.js_interop) 'file_save_web.dart'
    if (dart.library.io) 'file_save_io.dart';

/// Hands a generated file to the user.
///
/// Web offers it as a download; desktop writes it to disk and returns the
/// path. Conditional import rather than a runtime check, so neither platform
/// drags in the other's libraries.
Future<String?> saveFile(String name, Uint8List bytes) =>
    platformSaveFile(name, bytes);
