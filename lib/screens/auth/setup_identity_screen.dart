import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../core/validation/input_validators.dart';
import '../../services/storage_service.dart';

/// ════════════════════════════════════════════════════════════════════
/// شاشة وثائق الهوية (رقم وطني + صورة الهوية بالوجهين) — مطلب التوثيق والوساطة.
/// تُستدعى من: account_info_screen (طلب توثيق) + become_broker_screen.
/// 🔒 الرفع يتم عبر Edge Function (user-account / upload_id_images) بصلاحية
/// service_role لأن الرفع المباشر لـ ids_private محظور بـ RLS (جلسة مخصصة).
/// ════════════════════════════════════════════════════════════════════
class SetupIdentityScreen extends StatefulWidget {
  const SetupIdentityScreen({super.key});

  @override
  State<SetupIdentityScreen> createState() => _SetupIdentityScreenState();
}

class _SetupIdentityScreenState extends State<SetupIdentityScreen> {
  final _sidController = TextEditingController();
  XFile? _frontImage; // الوجه الأمامي
  XFile? _backImage;  // الوجه الخلفي
  bool _loading = false;
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    // نعبّئ الحقل إذا كان موجوداً مسبقاً
    final user = context.read<AuthProvider>().userModel;
    if (user != null && user.sid.isNotEmpty) {
      _sidController.text = user.sid;
    }
  }

  @override
  void dispose() {
    _sidController.dispose();
    super.dispose();
  }

  /// اختيار صورتي الهوية دفعة واحدة من المعرض (الأولى أمامية، الثانية خلفية)
  Future<void> _pickBothImages() async {
    final files = await _storage.pickMultiImages(limit: 2);
    if (files.isEmpty) return;
    setState(() {
      _frontImage = files[0];
      if (files.length > 1) _backImage = files[1];
    });
  }

  /// استبدال وجه محدد بصورة واحدة (معرض أو كاميرا)
  Future<void> _pickSingle(bool front) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.primaryGold),
              title: const Text('اختيار من المعرض',
                  style: TextStyle(color: AppTheme.textWhite)),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppTheme.primaryGold),
              title: const Text('التقاط بالكاميرا',
                  style: TextStyle(color: AppTheme.textWhite)),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final file = await _storage.pickImage(fromCamera: choice == 'camera');
    if (file == null) return;
    setState(() {
      if (front) {
        _frontImage = file;
      } else {
        _backImage = file;
      }
    });
  }

  /// تجهيز صورة كـ base64 (+ اللاحقة) للرفع عبر الـ Edge Function
  Future<({String b64, String ext})?> _encodeImage(XFile xfile) async {
    try {
      Uint8List bytes;
      String ext;
      if (kIsWeb) {
        bytes = await xfile.readAsBytes();
        ext = _extOf(xfile.name);
      } else {
        final compressed =
            await _storage.compressImage(File(xfile.path)) ?? File(xfile.path);
        bytes = await compressed.readAsBytes();
        ext = compressed.path.toLowerCase().endsWith('.jpg') ||
                compressed.path.toLowerCase().endsWith('.jpeg')
            ? 'jpg'
            : _extOf(xfile.path);
      }
      if (bytes.isEmpty) return null;
      return (b64: base64Encode(bytes), ext: ext);
    } catch (_) {
      return null;
    }
  }

  String _extOf(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'png';
    if (p.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  Future<void> _submit() async {
    final sid = InputValidators.normalizeDigits(_sidController.text.trim());
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;

    if (sid.isEmpty) {
      _snack('يرجى إدخال الرقم الوطني');
      return;
    }
    if (user == null) {
      _snack('انتهت الجلسة، أعد تسجيل الدخول');
      return;
    }

    final hasServerImages = user.img.isNotEmpty;
    final hasNewImages = _frontImage != null || _backImage != null;

    if (!hasNewImages && !hasServerImages) {
      _snack('يرجى رفع صورة الهوية بالوجهين (أمامية وخلفية)');
      return;
    }
    // إذا اختار صورة جديدة لوجه واحد، نتأكد أن الوجه الآخر موجود (جديد أو على السيرفر)
    if (hasNewImages &&
        (_frontImage == null || _backImage == null) &&
        !hasServerImages) {
      _snack('يرجى استكمال صورتي الهوية (الأمامية والخلفية)');
      return;
    }

    setState(() => _loading = true);

    try {
      if (hasNewImages) {
        // ─── رفع الصور + الرقم الوطني عبر Edge Function (service_role) ───
        String? frontB64, backB64, frontExt, backExt;
        if (_frontImage != null) {
          final encoded = await _encodeImage(_frontImage!);
          if (encoded == null) {
            _fail('تعذّرت قراءة الصورة الأمامية — جرّب صورة أخرى');
            return;
          }
          frontB64 = encoded.b64;
          frontExt = encoded.ext;
        }
        if (_backImage != null) {
          final encoded = await _encodeImage(_backImage!);
          if (encoded == null) {
            _fail('تعذّرت قراءة الصورة الخلفية — جرّب صورة أخرى');
            return;
          }
          backB64 = encoded.b64;
          backExt = encoded.ext;
        }

        final res = await SupabaseService().invokeFunction(
          'user-account',
          body: {
            'action': 'upload_id_images',
            'user_uid': user.uid,
            'sid': sid,
            if (frontB64 != null) 'front_b64': frontB64,
            if (backB64 != null) 'back_b64': backB64,
            if (frontExt != null) 'front_ext': frontExt,
            if (backExt != null) 'back_ext': backExt,
          },
        );
        final data =
            res.data is Map ? Map<String, dynamic>.from(res.data) : null;
        if (data == null || data['success'] != true) {
          final err = data?['error']?.toString() ?? '';
          _fail(err.startsWith('ID_UPLOAD_FAILED')
              ? 'فشل رفع صورة الهوية بالسيرفر — تحقق من الاتصال وحاول مجدداً'
              : 'فشل حفظ بيانات الهوية${err.isNotEmpty ? ': $err' : ''}');
          return;
        }
      } else {
        // ─── تحديث الرقم الوطني فقط (الصور موجودة أصلاً على السيرفر) ───
        final res = await SupabaseService().invokeFunction(
          'user-account',
          body: {
            'action': 'update_profile',
            'user_uid': user.uid,
            'payload': {'sid': sid, 'img': user.img},
          },
        );
        final data =
            res.data is Map ? Map<String, dynamic>.from(res.data) : null;
        if (data == null || data['success'] == false) {
          _fail('فشل حفظ البيانات، حاول مرة أخرى');
          return;
        }
      }

      await auth.refreshUser();
      if (!mounted) return;
      setState(() => _loading = false);

      AppTheme.showSnackBar(
        context,
        const SnackBar(
          content: Text('✅ تم حفظ بيانات الهوية'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      _fail('فشل حفظ البيانات — تحقق من الاتصال وحاول مرة أخرى');
    }
  }

  void _fail(String m) {
    if (!mounted) return;
    setState(() => _loading = false);
    _snack(m);
  }

  void _snack(String m) {
    if (!mounted) return;
    AppTheme.showSnackBar(context, SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final hasServerImages = (user?.img ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('توثيق الحساب'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── تنويه إلزامية البيانات (بدل رسالة التنبيه الغامضة) ───
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.primaryGold.withOpacity(0.45)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.verified_user_outlined,
                          color: AppTheme.primaryGold, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لإكمال توثيق حسابك يلزمك:',
                          style: TextStyle(
                              color: AppTheme.primaryGold,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]),
                    SizedBox(height: 8),
                    Text(
                      '١) إدخال الرقم الوطني\n٢) رفع صورة بطاقة الهوية بالوجهين (أمامية + خلفية)',
                      style: TextStyle(
                          color: AppTheme.textWhite, fontSize: 12, height: 1.6),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'بياناتك محمية وتُستخدم للتوثيق فقط ولا تظهر للعامة.',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─── الرقم الوطني ───
              const Text('الرقم الوطني *',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _sidController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  hintText: 'أدخل الرقم الوطني',
                  prefixIcon:
                      Icon(Icons.badge_outlined, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 20),

              // ─── صور الهوية بالوجهين ───
              Row(
                children: [
                  const Expanded(
                    child: Text('صورة بطاقة الهوية (الوجهان) *',
                        style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  if (hasServerImages && _frontImage == null && _backImage == null)
                    const Text('موجودة على السيرفر ✓',
                        style: TextStyle(color: Colors.green, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickBothImages,
                  icon: const Icon(Icons.photo_library_outlined,
                      color: AppTheme.primaryGold, size: 20),
                  label: Text(
                    hasServerImages || _frontImage != null || _backImage != null
                        ? 'إعادة اختيار الصورتين معاً من المعرض'
                        : 'اختيار الصورتين معاً من المعرض',
                    style: const TextStyle(
                        color: AppTheme.primaryGold, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side:
                        BorderSide(color: AppTheme.primaryGold.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _idSlot(
                      label: 'الوجه الأمامي',
                      image: _frontImage,
                      onTap: () => _pickSingle(true),
                      onRemove: _frontImage == null
                          ? null
                          : () => setState(() => _frontImage = null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _idSlot(
                      label: 'الوجه الخلفي',
                      image: _backImage,
                      onTap: () => _pickSingle(false),
                      onRemove: _backImage == null
                          ? null
                          : () => setState(() => _backImage = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ─── زر الحفظ ───
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.save_rounded, color: Colors.black),
                  label: const Text('حفظ البيانات',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _idSlot({
    required String label,
    required XFile? image,
    required VoidCallback onTap,
    VoidCallback? onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlack,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: image != null
                    ? Colors.green
                    : AppTheme.primaryGold.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: image == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo,
                            color: AppTheme.primaryGold, size: 32),
                        const SizedBox(height: 6),
                        Text(label,
                            style: const TextStyle(
                                color: AppTheme.textGrey, fontSize: 12)),
                        const Text('اضغط للاختيار',
                            style: TextStyle(
                                color: AppTheme.textGrey, fontSize: 10)),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: SizedBox.expand(
                          child: kIsWeb
                              ? Image.network(image.path, fit: BoxFit.cover)
                              : Image.file(File(image.path),
                                  fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$label ✓',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (onRemove != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.close, color: Colors.red, size: 14),
              label: const Text('إزالة',
                  style: TextStyle(color: Colors.red, fontSize: 11)),
            ),
          ),
      ],
    );
  }
}
