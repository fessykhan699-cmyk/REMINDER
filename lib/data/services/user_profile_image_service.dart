import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/storage/hive_storage.dart';

class UserProfileImageService {
  static const String logoKey = 'user_logo_path';
  static const String signatureKey = 'user_signature_path';

  static Box<dynamic> get _box => Hive.box<dynamic>(HiveStorage.settingsBoxName);

  static Future<String?> pickAndSaveLogo() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return null;

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      final savedFile = await File(image.path).copy('${directory.path}/$fileName');

      // Remove old logo if exists
      await _removeFileOnly(logoKey);

      await _box.put(logoKey, savedFile.path);
      return savedFile.path;
    } catch (e) {
      debugPrint('Error picking and saving logo: $e');
      return null;
    }
  }

  static Future<String?> pickAndSaveSignature() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return null;

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'signature_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      final savedFile = await File(image.path).copy('${directory.path}/$fileName');

      // Remove old signature if exists
      await _removeFileOnly(signatureKey);

      await _box.put(signatureKey, savedFile.path);
      return savedFile.path;
    } catch (e) {
      debugPrint('Error picking and saving signature: $e');
      return null;
    }
  }

  static Future<String?> getLogoPath() async {
    try {
      return _box.get(logoKey) as String?;
    } catch (e) {
      debugPrint('Error getting logo path: $e');
      return null;
    }
  }

  static Future<String?> getSignaturePath() async {
    try {
      return _box.get(signatureKey) as String?;
    } catch (e) {
      debugPrint('Error getting signature path: $e');
      return null;
    }
  }

  static Future<void> removeLogo() async {
    try {
      await _removeFileOnly(logoKey);
      await _box.delete(logoKey);
    } catch (e) {
      debugPrint('Error removing logo: $e');
    }
  }

  static Future<void> removeSignature() async {
    try {
      await _removeFileOnly(signatureKey);
      await _box.delete(signatureKey);
    } catch (e) {
      debugPrint('Error removing signature: $e');
    }
  }

  static Future<void> _removeFileOnly(String key) async {
    final path = _box.get(key) as String?;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
