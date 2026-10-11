import 'dart:typed_data';

Future<String?> platformSaveFile(String name, Uint8List bytes) async {
  throw UnsupportedError('no file save on this platform');
}
