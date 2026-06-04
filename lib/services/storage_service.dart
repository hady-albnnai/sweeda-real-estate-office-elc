import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/network/supabase_service.dart';

class StorageService {
  final SupabaseStorageClient _storage = SupabaseService().storage;

  Future<String> uploadImage({
    required File file, required String path, String? userId,
  }) async {
    final fullPath = 'images/${userId ?? 'anonymous'}/$path';
    final fileBytes = await file.readAsBytes();
    await _storage.from('offer_images').uploadBinary(
      fullPath, fileBytes,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
    );
    return _storage.from('offer_images').getPublicUrl(fullPath);
  }

  Future<String> uploadFile({
    required File file, required String bucket, required String path,
  }) async {
    final fileBytes = await file.readAsBytes();
    await _storage.from(bucket).uploadBinary(
      path, fileBytes,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
    );
    return _storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteFile(String bucket, String path) async {
    try { await _storage.from(bucket).remove([path]); } catch (_) {}
  }

  Future<void> deleteImage(String url) async {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final idx = segments.indexOf('public');
      if (idx + 1 < segments.length) {
        final bucket = segments[idx + 1];
        final filePath = segments.sublist(idx + 2).join('/');
        await _storage.from(bucket).remove([filePath]);
      }
    } catch (_) {}
  }
}
