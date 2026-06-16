import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../models/user_model.dart';
import '../../widgets/bottom_nav_bar.dart';

/// شاشة الملف الشخصي — إعادة تصميم كاملة
/// تصميم راقي متوافق مع ثيم ذهبي/أسود
/// - الإدارة: إحصائيات مخصصة حسب الدور
/// - المستخدم: نقاط + بادج + streak
/// - بطاقة معلومات الحساب والتوثيق نُقلت لشاشة مستقلة
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _staffStats;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadStaffStats();
  }

  /// جلب إحصائيات الموظف حسب الدور (للإدارة فقط)
  Future<void> _loadStaffStats() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null || !user.isInternal) return;

    setState(() => _loadingStats = true);
    try {
      final result = await SupabaseService().client.rpc(
        'get_staff_stats_internal',
        params: {'p_user_uid': user.uid},
      );
      if (mounted) {
        setState(() {
          _staffStats = result is Map ? Map<String, dynamic>.from(result) : null;
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.deepBlack,
        body: Center(
          child: Text('جاري التحميل...',
              style: TextStyle(color: AppTheme.textGrey)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      body: CustomScrollView(
        slivers: [
          // ─── Header مع gradient ───
          SliverToBoxAdapter(child: _buildHeader(user)),

          // ─── المحتوى ───
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── إحصائيات حسب الدور ───
                if (user.isInternal)
                  _buildStaffStats(user)
                else ...[
                  _buildUserStats(user),
                  const SizedBox(height: 16),
                  _buildActivityStats(user),
                ],

                const SizedBox(height: 20),

                // ─── القائمة الرئيسية ───
                _buildMenuSection(user),

                const SizedBox(height: 20),

                // ─── تسجيل الخروج ───
                _buildLogoutButton(auth),

                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HEADER — صورة + اسم + دور/بادج + حالة التوثيق
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader(UserModel user) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            user.isAdmin 
              ? AppTheme.primaryGold.withValues(alpha: 0.2) 
              : AppTheme.primaryGold.withValues(alpha: 0.15),
            AppTheme.deepBlack,
          ],
        ),
      ),
      child: Column(
        children: [
          // شريط العنوان
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user.isAdmin ? 'الملف الوظيفي' : 'حسابي',
                style: const TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: AppTheme.primaryGold, size: 24),
                onPressed: () => context.push('/user/settings'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Avatar
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGold.withValues(alpha: 0.8),
                  AppTheme.primaryGold.withValues(alpha: 0.4),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGold.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surfaceBlack,
              ),
              child: Center(
                child: Text(
                  user.nm.isNotEmpty ? user.nm[0] : '؟',
                  style: const TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // الاسم
          Text(
            user.nm.isNotEmpty ? user.nm : 'مستخدم جديد',
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          // معلومات الموظف (ID / العنوان)
          if (user.isAdmin) ...[
            Text(
              user.roleName,
              style: const TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (user.sid.isNotEmpty)
              Text(
                'الرقم الوطني: ${user.sid}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
            if (user.ad.isNotEmpty)
              Text(
                'العنوان: ${user.ad}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
          ] else ...[
            // اسم المستخدم للمستخدم العادي
            if (user.usr != null && user.usr!.isNotEmpty)
              Text(
                '@${user.usr}',
                style: TextStyle(
                  color: AppTheme.textGrey.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
          ],

          const SizedBox(height: 12),

          // الدور + البادج (للمستخدم العادي فقط)
          if (!user.isAdmin)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _chip(
                  user.roleName,
                  AppTheme.primaryGold.withValues(alpha: 0.15),
                  AppTheme.primaryGold,
                ),
                const SizedBox(width: 8),
                _chip(
                  user.badgeName,
                  Colors.white.withValues(alpha: 0.08),
                  AppTheme.textWhite,
                ),
                // شارة التوثيق
                if (user.isVerifiedOfficial) ...[
                  const SizedBox(width: 8),
                  _chip(
                    '✓ موثق',
                    Colors.green.withValues(alpha: 0.15),
                    Colors.green,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  إحصائيات المستخدم العادي (نقاط + streak)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildUserStats(UserModel user) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.star_rounded,
            value: '${user.pt}',
            label: 'النقاط',
            color: const Color(0xFFFFD700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statTile(
            icon: Icons.local_fire_department_rounded,
            value: '${user.strk}',
            label: 'أيام متتالية',
            color: const Color(0xFFFF6B35),
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textGrey.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  إحصائيات النشاط (عروض + طلبات + مواعيد + صفقات)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildActivityStats(UserModel user) {
    final stats = user.stats;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primaryGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined,
                  color: AppTheme.primaryGold.withValues(alpha: 0.8),
                  size: 18),
              const SizedBox(width: 8),
              const Text(
                'إحصائيات النشاط',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat('عروض', stats['off'] ?? 0, Icons.home_work_outlined),
              _miniStat('طلبات', stats['req'] ?? 0, Icons.assignment_outlined),
              _miniStat(
                  'مواعيد', stats['app'] ?? 0, Icons.calendar_today_outlined),
              _miniStat('صفقات', stats['dl'] ?? 0, Icons.handshake_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int count, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              color: AppTheme.primaryGold.withValues(alpha: 0.7), size: 20),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textGrey.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  إحصائيات الإدارة/الموظفين حسب الدور
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStaffStats(UserModel user) {
    if (_loadingStats) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.primaryGold),
        ),
      );
    }

    if (_staffStats == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.analytics_outlined,
                  color: AppTheme.textGrey.withValues(alpha: 0.4), size: 32),
              const SizedBox(height: 8),
              const Text('لا توجد إحصائيات متاحة',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    // بناء الإحصائيات حسب الدور
    List<_StaffStatItem> items = [];

    if (user.isPhotographer) {
      items = [
        _StaffStatItem(
            Icons.check_circle_outline, 'مهام مكتملة',
            _staffStats!['completed_tasks'] ?? 0, Colors.green),
        _StaffStatItem(
            Icons.hourglass_top, 'مهام معلّقة',
            _staffStats!['pending_tasks'] ?? 0, Colors.orange),
        _StaffStatItem(
            Icons.send_outlined, 'مرسلة للمكتب',
            _staffStats!['submitted_tasks'] ?? 0, Colors.blue),
      ];
    } else if (user.isSupervisor) {
      items = [
        _StaffStatItem(
            Icons.check_circle_outline, 'زيارات منفذة',
            _staffStats!['completed_visits'] ?? 0, Colors.green),
        _StaffStatItem(
            Icons.task_alt, 'طلبات إتمام',
            _staffStats!['completion_requests'] ?? 0, Colors.blue),
        _StaffStatItem(
            Icons.pending_actions, 'مهام نشطة',
            _staffStats!['active_tasks'] ?? 0, Colors.orange),
      ];
    } else if (user.isEmployee) {
      items = [
        _StaffStatItem(
            Icons.rate_review_outlined, 'عروض مراجَعة',
            _staffStats!['reviewed_offers'] ?? 0, Colors.blue),
        _StaffStatItem(
            Icons.event_available, 'مواعيد',
            _staffStats!['managed_appointments'] ?? 0, Colors.green),
        _StaffStatItem(
            Icons.fact_check_outlined, 'طلبات إتمام',
            _staffStats!['processed_completions'] ?? 0, Colors.orange),
      ];
    } else if (user.isSenior || user.isManager) {
      items = [
        _StaffStatItem(
            Icons.handshake_outlined, 'صفقات',
            _staffStats!['total_deals'] ?? 0, Colors.green),
        _StaffStatItem(
            Icons.payments_outlined, 'مدفوعات معتمدة',
            _staffStats!['approved_payments'] ?? 0, Colors.blue),
        _StaffStatItem(
            Icons.pending_outlined, 'مدفوعات معلّقة',
            _staffStats!['pending_payments'] ?? 0, Colors.orange),
        _StaffStatItem(
            Icons.verified_user_outlined, 'مستخدمون موثقون',
            _staffStats!['verified_users'] ?? 0, Colors.teal),
        _StaffStatItem(
            Icons.hourglass_top, 'توثيقات معلّقة',
            _staffStats!['pending_verifications'] ?? 0, Colors.amber),
        _StaffStatItem(
            Icons.people_outline, 'إجمالي المستخدمين',
            _staffStats!['total_users'] ?? 0, AppTheme.textGrey),
        _StaffStatItem(
            Icons.real_estate_agent_outlined, 'عروض نشطة',
            _staffStats!['active_offers'] ?? 0, AppTheme.primaryGold),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primaryGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  color: AppTheme.primaryGold.withValues(alpha: 0.8),
                  size: 18),
              const SizedBox(width: 8),
              const Text(
                'إحصائياتي',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadStaffStats,
                child: Icon(Icons.refresh,
                    color: AppTheme.textGrey.withValues(alpha: 0.5),
                    size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) => _staffStatCard(item)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _staffStatCard(_StaffStatItem item) {
    return Container(
      width: (MediaQuery.of(context).size.width - 72) / 2,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: item.color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.value}',
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  item.label,
                  style: TextStyle(
                    color: AppTheme.textGrey.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  القائمة الرئيسية
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMenuSection(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── معلومات الحساب والتوثيق ───
        _menuItem(
          icon: Icons.person_outline_rounded,
          title: user.isAdmin ? 'بياناتي الوظيفية' : 'معلومات الحساب',
          subtitle: _accountSubtitle(user),
          onTap: () => context.push('/user/account-info'),
        ),

        // ─── التقييمات ───
        _menuItem(
          icon: Icons.star_outline_rounded,
          title: 'تقييماتي المستلمة',
          subtitle: 'شاهد تقييمات العملاء لك',
          onTap: () => context.push('/user/my-ratings'),
        ),

        // ─── الباقة — للمستخدمين فقط ───
        if (!user.isAdmin) ...[
          _menuItem(
            icon: Icons.workspace_premium_outlined,
            title: user.bPkg == 0 ? 'ترقية الباقة' : 'إدارة الاشتراك',
            subtitle: _packageSubtitle(user),
            onTap: () => context.push('/user/packages'),
            trailing: user.bPkg == 0
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ترقية',
                      style: TextStyle(
                          color: AppTheme.primaryGold, fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  )
                : null,
          ),

          _menuItem(
            icon: Icons.receipt_long_outlined,
            title: 'سجل دفعاتي',
            subtitle: 'الدفعات السابقة وحالتها',
            onTap: () => context.push('/user/my-payments'),
          ),
        ],

        // ─── الإحالة — للمستخدمين فقط ───
        if (!user.isAdmin)
          _menuItem(
            icon: Icons.card_giftcard_outlined,
            title: 'دعوة الأصدقاء',
            subtitle: 'شارك رمز الإحالة واكسب نقاط',
            onTap: () => context.push('/user/referral'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'اكسب نقاط',
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),

        // ─── تقدم لتصبح وسيطاً — للمستخدم العادي فقط ───
        if (!user.isBroker && !user.isAdmin)
          _menuItem(
            icon: Icons.handshake_outlined,
            title: 'تقدّم لتصبح وسيطاً',
            subtitle: 'احصل على صلاحيات إضافية',
            onTap: () => context.push('/user/become-broker'),
          ),

        // ─── لوحة التحكم — للموظفين فقط ───
        if (user.isAdmin)
          _menuItem(
            icon: Icons.dashboard_customize_outlined,
            title: 'لوحة التحكم الإدارية',
            subtitle: 'الانتقال إلى واجهة العمليات',
            onTap: () {
              if (user.isPhotographer) {
                context.go('/photographer/tasks');
              } else if (user.isSupervisor) {
                context.go('/executor/tasks');
              } else if (user.isEmployee) {
                context.go('/employee/dashboard');
              } else if (user.isSenior || user.isManager) {
                context.go('/admin/dashboard');
              }
            },
            trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryGold, size: 14),
          ),
      ],
    );
  }

  String _accountSubtitle(UserModel user) {
    if (user.isAdmin) return 'بيانات التعيين والتحقق الوظيفي ✅';
    if (user.isVerifiedOfficial) return 'حسابك موثق رسمياً ✓';
    if (user.vrf == 1) return 'طلب التوثيق قيد المراجعة';
    return 'معلوماتك الشخصية والتوثيق';
  }

  String _packageSubtitle(UserModel user) {
    if (user.bPkg == 0) return 'باقة مجانية';
    final name = user.bPkg == 1 ? 'فضي' : 'ذهبي';
    if (user.isPkgActive) return 'باقة $name نشطة';
    if (user.isInGracePeriod) {
      return 'باقة $name — فترة سماح ${user.graceDaysLeft} يوم';
    }
    return 'باقة $name منتهية';
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlack,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      color: AppTheme.primaryGold.withValues(alpha: 0.8),
                      size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.textGrey.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textGrey.withValues(alpha: 0.3),
                    size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  زر تسجيل الخروج
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLogoutButton(AuthProvider auth) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showLogoutDialog(auth),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل الخروج',
            style: TextStyle(color: AppTheme.textWhite)),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟',
            style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          TextButton(
            onPressed: () {
              auth.logout();
              context.go('/login');
            },
            child: const Text('خروج',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Helper class
// ═══════════════════════════════════════════════════════════════

class _StaffStatItem {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  _StaffStatItem(this.icon, this.label, this.value, this.color);
}
