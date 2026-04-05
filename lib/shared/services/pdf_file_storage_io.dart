import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> savePdfBytesToLocalFile(
  Uint8List bytes,
  String filename,
) async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final invoicesDirectory = Directory(
    '${documentsDirectory.path}${Platform.pathSeparator}invoice_pdfs',
  );

  if (!await invoicesDirectory.exists()) {
    await invoicesDirectory.create(recursive: true);
  }

  final sanitizedFilename = filename.replaceAll(
    RegExp(r'[^A-Za-z0-9._-]'),
    '_',
  );
  final file = File(
    '${invoicesDirectory.path}${Platform.pathSeparator}$sanitizedFilename',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
