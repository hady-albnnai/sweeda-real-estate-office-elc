import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../core/network/supabase_service.dart';

/// خدمة التخزين — رفع الصور والملفات إلى Supabase Storage
/// مع اختيار من المعرض/الكاميرا وضغط الصور قبل الرفع.
class StorageService {
  final SupabaseStorageClient _storage = SupabaseService().storage;
  final ImagePicker _picker = ImagePicker();

  static const String offerBucket = 'offer_images';
  static const String configAssetsBucket = 'config_assets';
  static const String paymentProofsBucket = 'payment_proofs';
  // 🔒 Phase 9: bucket خاص لصور الهوية (private bucket — RLS صارمة)
  static const String idsPrivateBucket = 'ids_private';
  static const int maxImages = 6;

  // ═══════════════════════════════════════
  // اختيار الصور
  // ═══════════════════════════════════════

  /// اختيار صورة واحدة من المعرض أو الكاميرا
  Future<XFile?> pickImage({bool fromCamera = false}) async {
    try {
      return await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1920,
      );
    } catch (e) {
      debugPrint('❌ pickImage error: $e');
      return null;
    }
  }

  /// اختيار عدة صور من المعرض (مع حد أقصى)
  Future<List<XFile>> pickMultiImages({int limit = maxImages}) async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 90, maxWidth: 1920);
      if (files.length > limit) return files.sublist(0, limit);
      return files;
    } catch (e) {
      debugPrint('❌ pickMultiImages error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════
  // الضغط
  // ═══════════════════════════════════════

  /// ضغط صورة (يتخطى الضغط على الويب لعدم توفّر المسارات)
  Future<File?> compressImage(File file, {int quality = 70}) async {
    if (kIsWeb) return file;
    try {
      final dir = await getTemporaryDirectory();
      final target =
          '${dir.path}/cmp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        target,
        quality: quality,
        minWidth: 1280,
        minHeight: 1280,
      );
      if (result == null) return file;
      return File(result.path);
    } catch (e) {
      debugPrint('⚠️ compressImage error: $e');
      return file; // عند الفشل نرفع الأصلي
    }
  }

  // ═══════════════════════════════════════
  // الرفع
  // ═══════════════════════════════════════

  /// رفع صورة عرض واحدة (مع ضغط) وإرجاع الرابط العام
  Future<String?> uploadOfferImage({
    required XFile xfile,
    required String userId,
    String? offerId,
  }) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${xfile.name}';
      final fullPath = 'offers/$userId/${offerId ?? 'draft'}/$fileName';

      Uint8List bytes;
      if (kIsWeb) {
        bytes = await xfile.readAsBytes();
      } else {
        final compressed = await compressImage(File(xfile.path));
        bytes = await (compressed ?? File(xfile.path)).readAsBytes();
      }

      await _storage.from(offerBucket).uploadBinary(
            fullPath,
            bytes,
            fileOptions:
                const FileOptions(cacheControl: '3600', upsert: true),
          );
      return _storage.from(offerBucket).getPublicUrl(fullPath);
    } catch (e) {
      debugPrint('❌ uploadOfferImage error: $e');
      return null;
    }
  }

  /// رفع عدة صور عرض وإرجاع قائمة الروابط الناجحة
  Future<List<String>> uploadOfferImages({
    required List<XFile> files,
    required String userId,
    String? offerId,
    void Function(int done, int total)? onProgress,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final url =
          await uploadOfferImage(xfile: files[i], userId: userId, offerId: offerId);
      if (url != null) urls.add(url);
      onProgress?.call(i + 1, files.length);
    }
    return urls;
  }

  // ═══════════════════════════════════════
  // دوال عامة (متوافقة مع الكود القديم)
  // ═══════════════════════════════════════

  Future<String> uploadImage({
    required File file,
    required String path,
    String? userId,
  }) async {
    final fullPath = 'images/${userId ?? 'anonymous'}/$path';
    final compressed = kIsWeb ? file : (await compressImage(file) ?? file);
    final fileBytes = await compressed.readAsBytes();
    await _storage.from(offerBucket).uploadBinary(
          fullPath,
          fileBytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
    return _storage.from(offerBucket).getPublicUrl(fullPath);
  }

  Future<String> uploadFile({
    required File file,
    required String bucket,
    required String path,
  }) async {
    final fileBytes = await file.readAsBytes();
    await _storage.from(bucket).uploadBinary(
          path,
          fileBytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
    return _storage.from(bucket).getPublicUrl(path);
  }

  // ═══════════════════════════════════════
  // 🎬 الفيديو (المرحلة D)
  // ═══════════════════════════════════════

  /// اختيار فيديو من المعرض (الحد الأقصى: 60 ثانية لتوفير المساحة)
  Future<XFile?> pickVideo({Duration maxDuration = const Duration(seconds: 60)}) async {
    try {
      return await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: maxDuration,
      );
    } catch (e) {
      debugPrint('❌ pickVideo error: $e');
      return null;
    }
  }

  /// رفع فيديو لعرض
  Future<String?> uploadOfferVideo({
    required XFile xfile,
    required String userId,
    String? offerId,
  }) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${xfile.name}';
      final fullPath = 'videos/$userId/${offerId ?? 'draft'}/$fileName';

      final bytes = kIsWeb
          ? await xfile.readAsBytes()
          : await File(xfile.path).readAsBytes();

      // فحص الحجم (حد أقصى 50 MB)
      if (bytes.length > 50 * 1024 * 1024) {
        debugPrint('❌ Video too large: ${bytes.length} bytes');
        return null;
      }

      await _storage.from(offerBucket).uploadBinary(
            fullPath,
            bytes,
            fileOptions: const FileOptions(
                cacheControl: '3600', upsert: true, contentType: 'video/mp4'),
          );
      return _storage.from(offerBucket).getPublicUrl(fullPath);
    } catch (e) {
      debugPrint('❌ uploadOfferVideo error: $e');
      return null;
    }
  }

  Future<void> deleteFile(String bucket, String path) async {
    try {
      await _storage.from(bucket).remove([path]);
    } catch (_) {}
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
