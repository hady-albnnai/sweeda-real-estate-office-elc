import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../core/utils/app_utils.dart';
import '../../models/user_model.dart';

/// شاشة معلومات الحساب + التوثيق الرسمي
/// نُقلت من الملف الشخصي لتكون شاشة مستقلة وأنظف
class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBackground,
        body: Center(
            child: Text('جاري التحميل...',
                style: TextStyle(color: AppTheme.textGrey))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: const Text('معلومات الحساب',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.primaryGold, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── معلومات الحساب ───
            _buildInfoCard(user, context),

            if (user.isLawyer || user.isExpediter) ...[
              const SizedBox(height: 16),
              _buildLegalRoleDetailsCard(user),
            ],

            const SizedBox(height: 16),

            // ─── حالة التوثيق (مخفي للموظفين الداخليين) ───
            if (!user.isInternal) ...[
              _buildVerificationCard(user, context),
              const SizedBox(height: 16),
            ],

            // ─── تغيير كلمة المرور ───
            _buildPasswordSection(user, context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(UserModel user, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primaryGold.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppTheme.primaryGold.withOpacity(0.8),
                  size: 18),
              const SizedBox(width: 8),
              const Text(
                'بيانات الحساب',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(
              Icons.phone_android_outlined, 'الهاتف', user.ph, context),
          _infoRow(Icons.person_outline_rounded, 'الاسم',
              user.nm.isEmpty ? 'غير محدد' : user.nm, context),
          if (user.usr != null && user.usr!.isNotEmpty)
            _infoRow(Icons.alternate_email, 'اسم المستخدم',
                '@${user.usr}', context),
          _infoRow(Icons.location_on_outlined, 'العنوان',
              user.ad.isEmpty ? 'غير محدد' : user.ad, context),
          _infoRow(Icons.badge_outlined, 'الرقم الوطني',
              user.sid.isEmpty ? 'غير مكتمل' : user.sid, context),
          _infoRow(
              Icons.credit_card_outlined,
              user.isInternal ? 'صور الهوية' : 'صورة الهوية',
              _identityImagesText(user),
              context),
          _infoRow(Icons.calendar_today_outlined, 'تاريخ التسجيل',
              AppUtils.formatTimestamp(user.tsCrt), context),

          // الباقة — للمستخدمين فقط
          if (!user.isInternal) ...[
            const Divider(
                color: Colors.white12, height: 20, thickness: 0.5),
            _infoRow(Icons.workspace_premium_outlined, 'الباقة',
                _packageText(user), context),
            if (user.pkgEnd != null && user.bPkg > 0)
              _infoRow(
                user.isPkgActive
                    ? Icons.timer_outlined
                    : Icons.warning_amber_rounded,
                user.isPkgActive
                    ? 'انتهاء الباقة'
                    : user.isInGracePeriod
                        ? 'فترة السماح حتى'
                        : 'انتهت',
                user.isPkgActive
                    ? AppUtils.formatTimestamp(user.pkgEnd!)
                    : user.isInGracePeriod
                        ? AppUtils.formatTimestamp(user.pkgGrace!)
                        : AppUtils.formatTimestamp(user.pkgEnd!),
                context,
              ),
          ],
        ],
      ),
    );
  }

  List<String> _parseIdentityImages(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return const [];
    if (value.startsWith('[')) {
      try {
        final parsed = jsonDecode(value);
        if (parsed is List) {
          return parsed.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        }
      } catch (_) {
        // fallback below
      }
    }
    return [value];
  }

  String _identityImagesText(UserModel user) {
    final count = _parseIdentityImages(user.img).length;
    if (count <= 0) return 'غير مرفوعة';
    if (user.isInternal) return 'محفوظة بشكل خاص ($count/2)';
    return 'مرفوعة بشكل خاص';
  }

  Future<Map<String, dynamic>?> _fetchLawyerProfile(UserModel user) async {
    final res = await SupabaseService().invokeFunction(
      'legal-actions',
      body: {'action': 'get_lawyer_profile', 'user_uid': user.uid},
    );
    final data = res.data is Map ? Map<String, dynamic>.from(res.data) : null;
    if (data == null || data['success'] != true || data['profile'] is! Map) return null;
    return Map<String, dynamic>.from(data['profile'] as Map);
  }

  Future<List<dynamic>> _fetchExpediterTasks(UserModel user) async {
    final res = await SupabaseService().invokeFunction(
      'legal-actions',
      body: {'action': 'get_my_expediting_tasks', 'user_uid': user.uid},
    );
    final data = res.data is Map ? Map<String, dynamic>.from(res.data) : null;
    if (data == null || data['success'] != true || data['tasks'] is! List) return const [];
    return data['tasks'] as List;
  }

  Widget _buildLegalRoleDetailsCard(UserModel user) {
    if (user.isLawyer) {
      return FutureBuilder<Map<String, dynamic>?>(
        future: _fetchLawyerProfile(user),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final found = profile != null && profile['found'] == true;
          return _roleDetailsContainer(
            title: 'تفاصيل المحامي المختص',
            icon: Icons.gavel_rounded,
            children: [
              _infoRow(Icons.work_outline, 'القسم', 'القسم القانوني والاستشارات', context),
              _infoRow(Icons.verified_user_outlined, 'التوثيق', user.vrf == 2 ? 'موثق وظيفياً' : 'ينتظر استكمال التوثيق الوظيفي', context),
              _infoRow(Icons.credit_card, 'صور الهوية', _identityImagesText(user), context),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(color: AppTheme.primaryGold),
                )
              else ...[
                _infoRow(Icons.phone_android, 'واتساب', found ? (profile['whatsapp_phone']?.toString() ?? '') : 'غير معد بعد', context),
                _infoRow(Icons.location_on_outlined, 'عنوان المكتب', found ? (profile['office_address']?.toString() ?? '') : 'غير محدد', context),
                _infoRow(Icons.balance_outlined, 'الاختصاص', found ? (profile['specialization']?.toString() ?? '') : 'عقارات وسيارات', context),
                _infoRow(Icons.toggle_on_outlined, 'حالة الملف', found && profile['is_active'] == true ? 'نشط' : 'يحتاج إعداد رقم الواتساب', context),
              ],
            ],
          );
        },
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: _fetchExpediterTasks(user),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? const [];
        final pending = tasks.where((t) => t is Map && (t['status'] == 0 || t['status'] == 1)).length;
        final done = tasks.where((t) => t is Map && (t['status'] == 2 || t['status'] == 3)).length;
        return _roleDetailsContainer(
          title: 'تفاصيل معقب المعاملات',
          icon: Icons.assignment_turned_in_outlined,
          children: [
            _infoRow(Icons.work_outline, 'القسم', 'تعقيب المعاملات الميدانية', context),
            _infoRow(Icons.verified_user_outlined, 'التوثيق', user.vrf == 2 ? 'موثق وظيفياً' : 'ينتظر استكمال التوثيق الوظيفي', context),
            _infoRow(Icons.credit_card, 'صور الهوية', _identityImagesText(user), context),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(color: AppTheme.primaryGold),
              )
            else ...[
              _infoRow(Icons.pending_actions, 'مهام قيد العمل', '$pending', context),
              _infoRow(Icons.task_alt, 'مهام منتهية', '$done', context),
              _infoRow(Icons.list_alt, 'إجمالي المهام', '${tasks.length}', context),
            ],
          ],
        );
      },
    );
  }

  Widget _roleDetailsContainer({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryGold, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon,
              color: AppTheme.primaryGold.withOpacity(0.6), size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textGrey.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _packageText(UserModel user) {
    if (user.bPkg == 0) return 'مجانية';
    final name = user.bPkg == 1 ? 'فضي' : 'ذهبي';
    if (user.isPkgActive) return name;
    if (user.isInGracePeriod) {
      return '$name — سماح ${user.graceDaysLeft} يوم';
    }
    return 'منتهية ($name)';
  }

  // ═══════════════════════════════════════════════════════════════
  //  بطاقة التوثيق
  // ═══════════════════════════════════════════════════════════════

  Widget _buildVerificationCard(UserModel user, BuildContext context) {
    final vrf = user.vrf;

    late final Color color;
    late final IconData icon;
    late final String title;
    late final String subtitle;
    late final bool showAction;

    switch (vrf) {
      case 2:
        color = Colors.green;
        icon = Icons.verified_rounded;
        title = 'حسابك موثق رسمياً';
        subtitle = 'تظهر شارة التوثيق في جميع عروضك أمام العملاء.';
        showAction = false;
        break;
      case 1:
        color = Colors.orange;
        icon = Icons.hourglass_top_rounded;
        title = 'طلب التوثيق قيد المراجعة';
        subtitle = 'الإدارة تراجع وثائقك حالياً. ستصلك إشعار بالنتيجة.';
        showAction = false;
        break;
      default:
        color = AppTheme.textGrey;
        icon = Icons.shield_outlined;
        title = 'حسابك غير موثق';
        subtitle =
            'الحسابات الموثقة تحظى بثقة أكبر. ارفع هويتك واطلب التوثيق.';
        showAction = true;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (showAction) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _requestVerification(context),
                icon: const Icon(Icons.verified_outlined,
                    color: AppTheme.deepBlack, size: 18),
                label: const Text(
                  'طلب التوثيق الرسمي',
                  style: TextStyle(
                    color: AppTheme.deepBlack,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _requestVerification(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) return;

    if (user.img.isEmpty || user.sid.isEmpty) {
      AppTheme.showSnackBar(context,
        SnackBar(
          content: const Text(
              'يجب رفع صورة الهوية + الرقم الوطني قبل طلب التوثيق'),
          backgroundColor: AppTheme.errorRed,
          action: SnackBarAction(
            label: 'إكمال',
            textColor: Colors.white,
            onPressed: () => context.push('/setup-identity'),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('طلب التوثيق الرسمي',
            style: TextStyle(color: AppTheme.textWhite)),
        content: const Text(
          'سيتم إرسال بياناتك للإدارة لمراجعتها واعتمادها. '
          'بعد الاعتماد ستحصل على شارة "موثق ✓" في كل عروضك.\n\nهل تريد المتابعة؟',
          style: TextStyle(color: AppTheme.textGrey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold),
            child: const Text('إرسال الطلب',
                style: TextStyle(color: AppTheme.deepBlack)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await SupabaseService().invokeFunction('user-account', body: {'action': 'request_verification', 'p_user_uid': user.uid});
      await auth.refreshUser();
      if (!context.mounted) return;
      AppTheme.showSnackBar(context,
        const SnackBar(
          content: Text('✅ تم إرسال طلب التوثيق، بانتظار مراجعة الإدارة'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString();
      String userMsg = '❌ فشل إرسال الطلب';
      if (msg.contains('ALREADY_VERIFIED')) {
        userMsg = 'حسابك موثق بالفعل';
      } else if (msg.contains('ALREADY_PENDING')) {
        userMsg = 'طلبك السابق قيد المراجعة';
      } else if (msg.contains('MISSING_DOCUMENTS')) {
        userMsg = 'يجب رفع صورة الهوية + الرقم الوطني أولاً';
      }
      AppTheme.showSnackBar(context,
        SnackBar(content: Text(userMsg), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  تغيير كلمة المرور
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPasswordSection(UserModel user, BuildContext context) {
    final hasPassword = user.pwd != null && user.pwd!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: AppTheme.primaryGold.withOpacity(0.8),
                  size: 18),
              const SizedBox(width: 8),
              const Text(
                'كلمة المرور',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasPassword
                ? 'كلمة المرور مُعيّنة — يمكنك تغييرها'
                : 'لم يتم تعيين كلمة مرور بعد',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showChangePasswordDialog(context, hasPassword),
              icon: Icon(
                hasPassword ? Icons.edit_outlined : Icons.add_outlined,
                color: AppTheme.primaryGold,
                size: 18,
              ),
              label: Text(
                hasPassword ? 'تغيير كلمة المرور' : 'تعيين كلمة مرور',
                style: const TextStyle(
                    color: AppTheme.primaryGold, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, bool hasOld) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          hasOld ? 'تغيير كلمة المرور' : 'تعيين كلمة مرور',
          style: const TextStyle(color: AppTheme.textWhite, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasOld)
                TextField(
                  controller: oldCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                    prefixIcon:
                        Icon(Icons.lock_outline, color: AppTheme.primaryGold),
                  ),
                ),
              if (hasOld) const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  prefixIcon:
                      Icon(Icons.lock_rounded, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  prefixIcon:
                      Icon(Icons.lock_rounded, color: AppTheme.primaryGold),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text.length < 8) {
                AppTheme.showSnackBar(context,
                  const SnackBar(
                      content: Text('كلمة المرور يجب أن تكون 8 أحرف على الأقل')),
                );
                return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                AppTheme.showSnackBar(context,
                  const SnackBar(content: Text('كلمتا المرور غير متطابقتين')),
                );
                return;
              }

              Navigator.pop(ctx);
              try {
                final auth = context.read<AuthProvider>();
                final user = auth.userModel!;

                if (hasOld) {
                  await SupabaseService().invokeFunction('user-account', body: {
                    'action': 'change_password',
                    'user_uid': user.uid,
                    'old_password': oldCtrl.text,
                    'new_password': newCtrl.text,
                  });
                } else {
                  await SupabaseService().invokeFunction('user-account', body: {
                    'action': 'register_password',
                    'user_uid': user.uid,
                    'username': user.usr ?? user.ph,
                    'password': newCtrl.text,
                  });
                }

                await auth.refreshUser();
                if (context.mounted) {
                  AppTheme.showSnackBar(context,
                    const SnackBar(
                        content: Text('✅ تم تحديث كلمة المرور'),
                        backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  final msg = e.toString();
                  String userMsg = 'فشل التحديث';
                  if (msg.contains('WRONG_OLD_PASSWORD')) {
                    userMsg = 'كلمة المرور الحالية غير صحيحة';
                  }
                  AppTheme.showSnackBar(context,
                    SnackBar(
                        content: Text(userMsg),
                        backgroundColor: AppTheme.errorRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold),
            child: const Text('حفظ',
                style: TextStyle(color: AppTheme.deepBlack)),
          ),
        ],
      ),
    );
  }
}
