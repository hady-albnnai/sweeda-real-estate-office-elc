import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

/// خدمة التخزين — الصور والملفات
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// رفع صورة
  Future<String> uploadImage({
    required File file,
    required String path,
    String? userId,
  }) async {
    final fullPath = 'images/${userId ?? 'anonymous'}/$path';
    final ref = _storage.ref().child(fullPath);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// حذف صورة
  Future<void> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // تجاهل الخطأ إذا كانت الصورة غير موجودة
    }
  }
}