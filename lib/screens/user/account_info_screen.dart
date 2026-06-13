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
        backgroundColor: AppTheme.deepBlack,
        body: Center(
            child: Text('جاري التحميل...',
                style: TextStyle(color: AppTheme.textGrey))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
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

            const SizedBox(height: 16),

            // ─── حالة التوثيق ───
            _buildVerificationCard(user, context),

            const SizedBox(height: 16),

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
            color: AppTheme.primaryGold.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppTheme.primaryGold.withValues(alpha: 0.8),
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
              'صورة الهوية',
              user.img.isEmpty ? 'غير مرفوعة' : 'مرفوعة بشكل خاص',
              context),
          _infoRow(Icons.calendar_today_outlined, 'تاريخ التسجيل',
              AppUtils.formatTimestamp(user.tsCrt), context),

          // الباقة — للمستخدمين فقط
          if (!user.isAdmin) ...[
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

  Widget _infoRow(
      IconData icon, String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon,
              color: AppTheme.primaryGold.withValues(alpha: 0.6), size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textGrey.withValues(alpha: 0.7),
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
        border: Border.all(color: color.withValues(alpha: 0.25)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'يجب رفع صورة الهوية + الرقم الوطني قبل طلب التوثيق'),
          backgroundColor: AppTheme.errorRed,
          action: SnackBarAction(
            label: 'إكمال',
            textColor: Colors.white,
            onPressed: () => context.push('/setup-profile'),
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
      await SupabaseService().client.rpc(
        'request_verification_by_uid',
        params: {'p_user_uid': user.uid},
      );
      await auth.refreshUser();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: AppTheme.primaryGold.withValues(alpha: 0.8),
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
                    color: AppTheme.primaryGold.withValues(alpha: 0.3)),
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
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل')),
                );
                return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('كلمتا المرور غير متطابقتين')),
                );
                return;
              }

              Navigator.pop(ctx);
              try {
                final auth = context.read<AuthProvider>();
                final user = auth.userModel!;

                if (hasOld) {
                  await SupabaseService().client.rpc(
                    'change_password_internal',
                    params: {
                      'p_user_uid': user.uid,
                      'p_old_password': oldCtrl.text,
                      'p_new_password': newCtrl.text,
                    },
                  );
                } else {
                  await SupabaseService().client.rpc(
                    'register_password',
                    params: {
                      'p_user_uid': user.uid,
                      'p_username': user.usr ?? user.ph,
                      'p_password': newCtrl.text,
                    },
                  );
                }

                await auth.refreshUser();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
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
                  ScaffoldMessenger.of(context).showSnackBar(
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
