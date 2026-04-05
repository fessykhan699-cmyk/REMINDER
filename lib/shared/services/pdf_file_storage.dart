import 'dart:typed_data';

import 'pdf_file_storage_stub.dart'
    if (dart.library.io) 'pdf_file_storage_io.dart'
    as storage;

Future<String?> savePdfBytesToLocalFile(Uint8List bytes, String filename) {
  return storage.savePdfBytesToLocalFile(bytes, filename);
}
