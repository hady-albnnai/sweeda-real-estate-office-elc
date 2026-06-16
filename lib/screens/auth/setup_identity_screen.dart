import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../services/storage_service.dart';

/// ════════════════════════════════════════════════════════════════════
/// شاشة رفع الهوية (رقم وطني + صورة) — مطلب أساسي للتوثيق والوساطة.
/// تُستدعى من: account_info_screen (طلب توثيق) + become_broker_screen.
/// الصورة تُرفع في bucket خاص (ids_private) — لا تُعرض كـ URL عام.
/// ════════════════════════════════════════════════════════════════════
class SetupIdentityScreen extends StatefulWidget {
  const SetupIdentityScreen({super.key});

  @override
  State<SetupIdentityScreen> createState() => _SetupIdentityScreenState();
}

class _SetupIdentityScreenState extends State<SetupIdentityScreen> {
  final _sidController = TextEditingController();
  XFile? _idImage;
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

  Future<void> _pickIdImage() async {
    final file = await _storage.pickImage(fromCamera: false);
    if (file != null) setState(() => _idImage = file);
  }

  /// 🔒 رفع صورة الهوية في bucket خاص (ids_private).
  Future<String?> _uploadId(String userId) async {
    if (_idImage == null) return null;
    try {
      final storage = SupabaseService().storage;
      final path = '$userId/id_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = kIsWeb
          ? await _idImage!.readAsBytes()
          : await (await _storage.compressImage(File(_idImage!.path)) ??
                  File(_idImage!.path))
              .readAsBytes();
      await storage.from(StorageService.idsPrivateBucket).uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      return path;
    } catch (e) {
      return null;
    }
  }

  Future<void> _submit() async {
    final sid = _sidController.text.trim();

    if (sid.isEmpty) {
      _snack('يرجى إدخال الرقم الوطني');
      return;
    }
    if (_idImage == null) {
      // إذا كان عنده صورة مرفوعة مسبقاً نسمح بالحفظ برقم وطني فقط
      final user = context.read<AuthProvider>().userModel;
      if (user == null || user.img.isEmpty) {
        _snack('يرجى رفع صورة الهوية');
        return;
      }
    }

    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) {
      setState(() => _loading = false);
      _snack('انتهت الجلسة، أعد تسجيل الدخول');
      return;
    }

    // رفع الصورة (إن وُجدت جديدة)
    String? idPath;
    if (_idImage != null) {
      idPath = await _uploadId(user.uid);
      if (idPath == null) {
        setState(() => _loading = false);
        _snack('فشل رفع صورة الهوية، حاول مرة أخرى');
        return;
      }
    }

    try {
      await SupabaseService().client.rpc(
        'update_user_profile_internal',
        params: {
          'p_user_uid': user.uid,
          'p_payload': {
            'sid': sid,
            'img': idPath ?? user.img,
          },
        },
      );

      await auth.refreshUser();
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ بيانات الهوية'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      setState(() => _loading = false);
      _snack('فشل حفظ البيانات، حاول مرة أخرى');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('بيانات الهوية'),
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlack,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.shield_outlined,
                      color: AppTheme.primaryGold, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'بياناتك محمية ومشفّرة، وتُستخدم للتوثيق فقط ولا تظهر للعامة.',
                      style:
                          TextStyle(color: AppTheme.textGrey, fontSize: 12),
                    ),
                  ),
                ]),
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

              // ─── صورة الهوية ───
              const Text('صورة بطاقة الهوية *',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickIdImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBlack,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _idImage != null
                          ? Colors.green
                          : AppTheme.primaryGold.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: _idImage == null
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo,
                                  color: AppTheme.primaryGold, size: 42),
                              SizedBox(height: 6),
                              Text('اضغط لرفع صورة الهوية',
                                  style: TextStyle(
                                      color: AppTheme.textGrey,
                                      fontSize: 13)),
                            ],
                          ),
                        )
                      : Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: kIsWeb
                                ? Image.network(_idImage!.path,
                                    fit: BoxFit.cover,
                                    width: double.infinity)
                                : Image.file(File(_idImage!.path),
                                    fit: BoxFit.cover,
                                    width: double.infinity),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('صورة جديدة',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ),
                          ),
                        ]),
                ),
              ),
              if (_idImage != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _idImage = null),
                    icon: const Icon(Icons.close, color: Colors.red, size: 16),
                    label: const Text('إزالة الصورة',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
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
}
