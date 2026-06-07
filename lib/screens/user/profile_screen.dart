import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../core/constants/db_constants.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../core/utils/app_utils.dart';

/// شاشة الملف الشخصي — عرض البيانات + البادج + النقاط + حالة التوثيق
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// 🛡️ تقديم طلب توثيق رسمي للإدارة (vrf: 0 → 1).
  /// مرجع: docs/LOGIC_SPEC.md §2.1
  Future<void> _requestVerification(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) return;

    // التحقق من توفر صورة الهوية
    if (user.img.isEmpty || user.sid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'يجب رفع صورة الهوية + الرقم الوطني قبل طلب التوثيق'),
          backgroundColor: AppTheme.errorRed,
          action: SnackBarAction(
            label: 'إكمال',
            textColor: Colors.white,
            onPressed: () => context.push('/auth/setup-profile'),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
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
      // 🔒 Phase 8: نستخدم RPC request_verification بدل UPDATE مباشر
      // (UPDATE للـvrf محظور الآن في DB عبر trg_user_safe_update)
      await SupabaseService().client.rpc('request_verification');

      // تحديث الكاش المحلي
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.deepBlack,
        body: Center(child: Text('جاري التحميل...', style: TextStyle(color: AppTheme.textGrey))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        title: const Text('الملف الشخصي', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.primaryGold),
            onPressed: () => context.push('/user/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // صورة البروفايل + الاسم + البادج
            _profileHeader(user),
            const SizedBox(height: 30),

            // النقاط والبادج
            _statsCards(user),
            const SizedBox(height: 20),

            // معلومات الحساب
          _infoCard(user, context),
            const SizedBox(height: 20),

            // 🛡️ حالة التوثيق (LOGIC_SPEC §2.1)
            _verificationCard(user, context),
            const SizedBox(height: 20),

            // إحصائيات النشاط
            _activityStats(user),
            const SizedBox(height: 30),

            // أزرار
            _actionButtons(context, auth),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4),
    );
  }

  Widget _profileHeader(user) {
    return Column(
      children: [
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryGold, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGold.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: user.img.isNotEmpty
              ? ClipOval(child: Image.network(user.img, fit: BoxFit.cover))
              : CircleAvatar(
                  backgroundColor: AppTheme.surfaceBlack,
                  child: Text(
                    user.nm.isNotEmpty ? user.nm[0] : '👤',
                    style: const TextStyle(color: AppTheme.primaryGold, fontSize: 40),
                  ),
                ),
        ),
        const SizedBox(height: 15),
        // الاسم
        Text(
          user.nm.isNotEmpty ? user.nm : 'مستخدم جديد',
          style: const TextStyle(
            color: AppTheme.textWhite,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        // البادج
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
          ),
          child: Text(
            user.badgeName,
            style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          user.roleName,
          style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
        ),
      ],
    );
  }

  Widget _statsCards(user) {
    return Row(
      children: [
        Expanded(
          child: _statCard('⭐ النقاط', '${user.pt}', Icons.stars),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard('🔥 Streak', '${user.strk} يوم', Icons.local_fire_department),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _infoCard(user, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('معلومات الحساب',
              style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.grey, height: 20),
          _infoRow('📱 الهاتف', user.ph),
          _infoRow('📍 العنوان', user.ad.isEmpty ? 'غير محدد' : user.ad),
          _infoRow('🆔 الهوية', user.sid.isEmpty ? 'غير مكتمل' : user.sid),
          _infoRow('📅 تاريخ التسجيل',
              user.tsCrt != null ? AppUtils.formatTimestamp(user.tsCrt) : 'غير معروف'),
          _infoRow('🏷️ الباقة', _packageText(user.bPkg)),
          if (user.pkgEnd != null)
            _infoRow('⏰ انتهاء الباقة', AppUtils.formatTimestamp(user.pkgEnd!)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/user/packages'),
              icon: const Icon(Icons.upgrade, color: AppTheme.primaryGold),
              label: Text(
                user.bPkg == 0 ? 'ترقية الباقة' : 'إدارة الاشتراك',
                style: const TextStyle(color: AppTheme.primaryGold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryGold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(icon.split(' ').first, style: const TextStyle(color: AppTheme.textGrey, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _packageText(int pkg) {
    switch (pkg) {
      case 0: return 'مجاني';
      case 1: return 'فضي';
      case 2: return 'ذهبي';
      default: return 'غير محدد';
    }
  }

  /// 🛡️ بطاقة حالة التوثيق الرسمي + زر الطلب/إعادة الطلب.
  /// مرجع: docs/LOGIC_SPEC.md §2.1
  Widget _verificationCard(user, BuildContext context) {
    final vrf = user.vrf as int;

    late final Color color;
    late final IconData icon;
    late final String title;
    late final String subtitle;
    late final Widget? action;

    switch (vrf) {
      case 2:
        color = Colors.green;
        icon = Icons.verified;
        title = 'حسابك موثق رسمياً ✓';
        subtitle = 'تظهر شارة "موثق" في جميع عروضك أمام العملاء.';
        action = null;
        break;
      case 1:
        color = Colors.orange;
        icon = Icons.hourglass_top;
        title = 'طلب التوثيق قيد المراجعة';
        subtitle = 'الإدارة تراجع وثائقك حالياً. ستصلك إشعار بالنتيجة.';
        action = null;
        break;
      default:
        color = AppTheme.textGrey;
        icon = Icons.verified_user_outlined;
        title = 'حسابك غير موثق';
        subtitle =
            'الحسابات الموثقة تحظى بثقة أكبر من العملاء. ارفع هويتك واطلب التوثيق.';
        action = SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _requestVerification(context),
            icon: const Icon(Icons.verified_outlined,
                color: AppTheme.deepBlack),
            label: const Text('طلب التوثيق الرسمي',
                style: TextStyle(
                    color: AppTheme.deepBlack, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(
                  color: AppTheme.textGrey, fontSize: 13, height: 1.4)),
          if (action != null) ...[
            const SizedBox(height: 12),
            action,
          ],
        ],
      ),
    );
  }

  Widget _activityStats(user) {
    final stats = user.stats;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 إحصائيات النشاط',
              style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniStat('عروض', stats['off'] ?? 0, Icons.home),
              _miniStat('طلبات', stats['req'] ?? 0, Icons.assignment),
              _miniStat('مواعيد', stats['app'] ?? 0, Icons.calendar_today),
              _miniStat('صفقات', stats['dl'] ?? 0, Icons.handshake),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGold, size: 24),
        const SizedBox(height: 5),
        Text('$count', style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
      ],
    );
  }

  Widget _actionButtons(BuildContext context, AuthProvider auth) {
    final user = auth.userModel;
    return Column(
      children: [
        // لوحة الوسيط — تظهر للسماسرة فقط
        if (user != null && (user.isBroker || user.role == 1)) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/broker/dashboard'),
              icon: const Icon(Icons.handshake),
              label: const Text('لوحة الوسيط'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.deepBlack,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // دعوة الأصدقاء
        if (user != null) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/user/referral'),
              icon: const Icon(Icons.card_giftcard,
                  color: AppTheme.primaryGold),
              label: const Text('دعوة الأصدقاء واربح نقاط',
                  style: TextStyle(color: AppTheme.primaryGold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryGold),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ⭐ تقييماتي المستلمة — LOGIC_SPEC §3.3
        if (user != null) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/user/my-ratings'),
              icon: const Icon(Icons.star_rate,
                  color: AppTheme.primaryGold),
              label: const Text('تقييماتي المستلمة',
                  style: TextStyle(color: AppTheme.primaryGold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryGold),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // تقدّم لتصبح وسيطاً — للمستخدم العادي فقط
        if (user != null && !user.isBroker && !user.isAdmin) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/user/become-broker'),
              icon: const Icon(Icons.handshake,
                  color: AppTheme.primaryGold),
              label: const Text('تقدّم لتصبح وسيطاً',
                  style: TextStyle(color: AppTheme.primaryGold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryGold),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // لوحة الإدارة — تظهر للمشرفين فأعلى (role >= 2)
        if (user != null && user.isAdmin) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/admin/dashboard'),
              icon: const Icon(Icons.shield),
              label: const Text('لوحة الإدارة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.85),
                foregroundColor: AppTheme.deepBlack,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              auth.logout();
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.2),
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
    );
  }
}
