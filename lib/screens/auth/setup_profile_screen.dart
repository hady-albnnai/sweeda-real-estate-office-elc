import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../core/constants/db_constants.dart';
import '../../services/storage_service.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameController = TextEditingController();
  final _sidController = TextEditingController();
  final _addressController = TextEditingController();
  final _referralCodeController = TextEditingController(); // 🎁 كود إحالة اختياري
  XFile? _idImage;
  bool _agreePledge = false;
  bool _loading = false;
  final _storage = StorageService();

  @override
  void dispose() {
    _nameController.dispose();
    _sidController.dispose();
    _addressController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickIdImage() async {
    final file = await _storage.pickImage(fromCamera: false);
    if (file != null) setState(() => _idImage = file);
  }

  /// 🔒 Phase 9: رفع صورة الهوية في bucket خاص (ids_private).
  /// المسار: <userId>/id_<timestamp>.jpg — RLS تشترط أن المسار = auth.uid().
  /// نُرجع المسار (path) فقط، لا getPublicUrl (الـbucket غير عام).
  /// الإدارة تقرأها عبر admin_get_id_signed_path RPC.
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
            path, bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      // نُرجع المسار النسبي (لا URL عام لمنع التسرب)
      return path;
    } catch (e) {return null;
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      _snack('يرجى إكمال الاسم');
      return;
    }
    if (!_agreePledge) {
      _snack('يجب الموافقة على الإقرار والتعهد');
      return;
    }

    setState(() => _loading = true);
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.userModel;
    if (user == null) {
      setState(() => _loading = false);
      _snack('انتهت الجلسة، أعد تسجيل الدخول');
      return;
    }

    // 1) رفع صورة الهوية (إذا كانت موجودة)
    String? idUrl;
    if (_idImage != null) {
      idUrl = await _uploadId(user.uid);
      if (idUrl == null) {
        setState(() => _loading = false);
        _snack('فشل رفع صورة الهوية، حاول مرة أخرى');
        return;
      }
    }

    // 2) تحديث بيانات المستخدم
    try {
      await SupabaseService().client.rpc(
        'update_user_profile_internal',
        params: {
          'p_user_uid': user.uid,
          'p_payload': {
            'nm': _nameController.text.trim(),
            'sid': _sidController.text.trim(),
            'ad': _addressController.text.trim(),
            'img': idUrl ?? user.img,
          },
        },
      );

      // 3) 🎁 تطبيق كود الإحالة (إن وُجد) — RPC apply_referral
      // مرجع: docs/LOGIC_SPEC.md §3.2 + supabase/FUNCTIONS_REFERENCE.md
      final refCode = _referralCodeController.text.trim();
      if (refCode.isNotEmpty) {
        try {
          final ok = await SupabaseService().client.rpc(
            DbFunctions.applyReferral,
            params: {
              'p_new_uid': user.uid,
              'p_referrer_code': refCode.toUpperCase(),
            },
          );
          if (ok == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎁 تم تطبيق كود الإحالة، حصلت أنت والمحيل على نقاط ترحيب!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {// لا نُفشل عملية التسجيل بسبب كود إحالة خاطئ
        }
      }

      await authProvider.refreshUser();

      if (!mounted) return;
      setState(() => _loading = false);

      // التوجّه حسب الدور
      if (authProvider.isAdmin) {
        context.go('/admin/dashboard');
      } else if (authProvider.isBroker) {
        context.go('/broker/dashboard');
      } else {
        context.go('/user/home');
      }
    } catch (e) {
      setState(() => _loading = false);
      _snack('فشل حفظ البيانات: ${e.toString()}');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _showPledgeDialog() {
    final config = context.read<ConfigProvider>().config;
    final pledgeText = config?.texts['plg'] ??
        'إقرار وتعهد إلكتروني — عقارات السويداء\n\n'
            '• أُقرّ بأن جميع البيانات والمعلومات المُدخلة صحيحة وكاملة.\n'
            '• أتعهّد بعدم إدراج أي إعلانات وهمية أو مضللة.\n'
            '• ألتزم بقوانين العمل العقاري في الجمهورية العربية السورية.\n'
            '• أُوافق على معالجة بياناتي وفقاً لسياسة الخصوصية.\n'
            '• أُقرّ بأن أي مخالفة قد تؤدي لتجميد أو حظر حسابي.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Row(
          children: [
            Icon(Icons.gavel, color: AppTheme.primaryGold),
            SizedBox(width: 8),
            Text('الإقرار والتعهد',
                style: TextStyle(color: AppTheme.textWhite)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(pledgeText,
              style:
                  const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق',
                style: TextStyle(color: AppTheme.primaryGold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('إكمال الملف الشخصي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'أهلاً بك في المكتب العقاري',
                style: TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'يرجى تزويدنا ببعض المعلومات الأساسية لتوثيق حسابك',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // الاسم
              _label('الاسم الكامل *'),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  hintText: 'أدخل اسمك الثلاثي',
                  prefixIcon: Icon(Icons.person, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 14),

              // رقم الهوية (اختياري حالياً)
              _label('الرقم الوطني (اختياري)'),
              TextField(
                controller: _sidController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  hintText: 'أدخل رقم الهوية إن رغبت',
                  prefixIcon: Icon(Icons.badge, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 14),
              
              // العنوان
              _label('العنوان (اختياري)'),
              TextField(
                controller: _addressController,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  hintText: 'مثلاً: السويداء — الجادة الرئيسية',
                  prefixIcon: Icon(Icons.location_on,
                      color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 14),

              // 🎁 كود الإحالة (اختياري) — LOGIC_SPEC §3.2
              _label('كود إحالة (اختياري — احصل على نقاط ترحيب 🎁)'),
              TextField(
                controller: _referralCodeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                    color: AppTheme.textWhite, letterSpacing: 2),
                decoration: const InputDecoration(
                  hintText: 'مثلاً: ABCD1234',
                  prefixIcon:
                      Icon(Icons.card_giftcard, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 16),

              // صورة الهوية (اختيارية للمستخدم العادي)
              _label('صورة بطاقة الهوية (اختياري)'),
              const Text(
                'يمكنك رفعها لزيادة موثوقية حسابك',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickIdImage,
                child: Container(
                  height: 160,
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
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: kIsWeb
                              ? Image.network(_idImage!.path,
                                  fit: BoxFit.cover, width: double.infinity)
                              : Image.file(File(_idImage!.path),
                                  fit: BoxFit.cover, width: double.infinity),
                        ),
                ),
              ),
              if (_idImage != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _idImage = null),
                    icon: const Icon(Icons.close, color: Colors.red, size: 16),
                    label: const Text('تغيير الصورة',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ),
              const SizedBox(height: 16),

              // الإقرار والتعهد
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlack,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _agreePledge
                          ? Colors.green
                          : AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: _showPledgeDialog,
                      child: const Row(
                        children: [
                          Icon(Icons.gavel,
                              color: AppTheme.primaryGold, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'اقرأ نص الإقرار والتعهد قبل المتابعة',
                              style: TextStyle(
                                  color: AppTheme.textWhite, fontSize: 12),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              color: AppTheme.primaryGold, size: 12),
                        ],
                      ),
                    ),
                    const Divider(color: AppTheme.textGrey, height: 16),
                    CheckboxListTile(
                      value: _agreePledge,
                      onChanged: (v) =>
                          setState(() => _agreePledge = v ?? false),
                      title: const Text(
                        'أوافق على الإقرار والتعهد الإلكتروني',
                        style: TextStyle(
                            color: AppTheme.textWhite, fontSize: 13),
                      ),
                      activeColor: AppTheme.primaryGold,
                      checkColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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
                      : const Icon(Icons.check, color: Colors.black),
                  label: const Text('ابدأ الآن',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  '🔒 بياناتك مشفّرة ومحفوظة بأمان',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );
}
