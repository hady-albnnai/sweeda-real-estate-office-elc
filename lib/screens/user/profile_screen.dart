import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../models/user_model.dart';
import '../../widgets/bottom_nav_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _activeSection = 0; // 1: Signup, 2: Login
  int _signupWay = 0; // 1: Phone, 2: Email
  bool _obs = true;
  bool _loading = false;

  final _logUser = TextEditingController();
  final _logPass = TextEditingController();
  final _regPhone = TextEditingController();
  final _regEmail = TextEditingController();

  @override
  void dispose() {
    _logUser.dispose(); _logPass.dispose(); _regPhone.dispose(); _regEmail.dispose();
    super.dispose();
  }

  // ── العمليات الوظيفية ──
  Future<void> _login() async {
    if (_logUser.text.isEmpty || _logPass.text.isEmpty) { _snack('أدخل بياناتك'); return; }
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().loginWithPassword(_logUser.text.trim(), _logPass.text);
    if (mounted) setState(() => _loading = false);
    if (!ok) _snack('خطأ في الاسم أو كلمة المرور');
  }

  Future<void> _forgot() async {
    final ph = _logUser.text.trim();
    if (ph.length != 10 || !ph.startsWith('09')) { _snack('أدخل رقم هاتفك في خانة المستخدم أولاً'); return; }
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().sendSMSOTP(ph);
    if (mounted) setState(() => _loading = false);
    if (ok) { _snack('تم إرسال كود الاستعادة SMS'); context.push('/otp'); }
  }

  Future<void> _regSMS() async {
    if (_regPhone.text.length != 10 || !_regPhone.text.startsWith('09')) { _snack('أدخل رقم هاتف صحيح'); return; }
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().sendSMSOTP(_regPhone.text.trim());
    if (mounted) setState(() => _loading = false);
    if (ok) { _snack('تم إرسال كود التفعيل SMS'); context.push('/otp'); }
  }

  Future<void> _regMail() async {
    if (_regEmail.text.isEmpty || !_regEmail.text.contains('@')) { _snack('أدخل بريداً صحيحاً'); return; }
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().sendEmailMagicLink(_regEmail.text.trim());
    if (mounted) setState(() => _loading = false);
    if (ok) { _snack('تم إرسال رابط التفعيل لبريدك'); context.push('/check-email'); }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;

    // إذا لم يكن مسجلاً (زائر) نعرض الواجهة الجديدة المنظمة
    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.deepBlack,
        body: _buildGuestUI(),
        bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4),
      );
    }

    // إذا كان مسجلاً (موظف أو عميل) نعرض واجهته الخاصة
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _buildHeader(user)),
        SliverPadding(padding: const EdgeInsets.all(20), sliver: SliverList(delegate: SliverChildListDelegate([
          if (user.isInternal) _buildStaffStats(user) else ...[_buildUserStats(user), const SizedBox(height: 16), _buildActivityStats(user)],
          const SizedBox(height: 20), _buildMenuSection(user), const SizedBox(height: 20), _buildLogoutButton(auth), const SizedBox(height: 30),
        ]))),
      ]),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // واجهة الزائر - الكتالوج المنشود
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGuestUI() {
    final sz = MediaQuery.sizeOf(context);
    final logoSize = (sz.shortestSide * 0.95).clamp(320.0, 550.0);

    return Container(
      width: double.infinity,
      color: AppTheme.deepBlack,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 10),
            // 🔥 شعار عملاق (تصميم السبلاش)
            Hero(tag: 'logo', child: Container(
              width: logoSize, height: logoSize * 0.72,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppTheme.primaryGold.withValues(alpha: 0.25), blurRadius: 100, spreadRadius: 30)]),
              child: Stack(alignment: Alignment.center, children: [
                Container(width: logoSize * 0.72, height: logoSize * 0.72, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4), width: 4))),
                Container(width: logoSize * 0.65, height: logoSize * 0.65, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceBlack), padding: const EdgeInsets.all(35), child: Image.asset('assets/images/logo_app.png', fit: BoxFit.contain)),
              ]),
            )),
            Text('المكتب العقاري الإلكتروني', style: GoogleFonts.cairo(color: AppTheme.primaryGold, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 50),

            // ── البند الأول: تسجيل الدخول ──
            _expandableBlock(
              id: 2, title: 'تسجيل الدخول', icon: Icons.login_rounded, isGold: false,
              child: Column(children: [
                _input(_logUser, 'اسم المستخدم أو رقم الهاتف', Icons.person_outline),
                const SizedBox(height: 12),
                _input(_logPass, 'كلمة المرور', Icons.lock_outline, isPass: true, obs: _obs, onT: () => setState(() => _obs = !_obs)),
                const SizedBox(height: 16),
                _bigBtn(l: 'دخول', o: _login),
                TextButton(onPressed: _forgot, child: const Text('هل نسيت كلمة المرور؟ استعادة بـ SMS', style: TextStyle(color: AppTheme.primaryGold, decoration: TextDecoration.underline, fontSize: 13))),
              ]),
            ),

            const SizedBox(height: 16),

            // ── البند الثاني: تسجيل حساب جديد ──
            _expandableBlock(
              id: 1, title: 'تسجيل حساب جديد', icon: Icons.person_add_alt_1_outlined, isGold: true,
              child: Column(children: [
                // أ- تسجيل عن طريق الهاتف
                _innerOption(
                  t: 'تسجيل عن طريق رقم الهاتف', i: Icons.phone_android, sel: _signupWay == 1,
                  onT: () => setState(() => _signupWay = 1),
                  child: Column(children: [
                    _input(_regPhone, '09XXXXXXXX', Icons.phone_iphone, dark: true),
                    const SizedBox(height: 12),
                    _bigBtn(l: 'إرسال رمز التفعيل SMS', o: _regSMS, dark: true),
                  ]),
                ),
                const SizedBox(height: 12),
                // ب- تسجيل عن طريق الايميل
                _innerOption(
                  t: 'تسجيل عن طريق الإيميل', i: Icons.alternate_email, sel: _signupWay == 2,
                  onT: () => setState(() => _signupWay = 2),
                  child: Column(children: [
                    _input(_regEmail, 'example@mail.com', Icons.email_outlined, dark: true),
                    const SizedBox(height: 12),
                    _bigBtn(l: 'إرسال رابط التفعيل', o: _regMail, dark: true),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 60),
          ]),
        ),
      ),
    );
  }

  // ── المساعدات البنائية ──

  Widget _expandableBlock({required int id, required String title, required IconData icon, required bool isGold, required Widget child}) {
    final open = _activeSection == id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(color: isGold ? AppTheme.primaryGold : AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.5), width: 2)),
      child: Column(children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _activeSection = open ? 0 : id),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(icon, color: isGold ? Colors.black : AppTheme.primaryGold, size: 28),
                const SizedBox(width: 16),
                Text(title, style: TextStyle(color: isGold ? Colors.black : AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.w900)),
                const Spacer(),
                Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: isGold ? Colors.black : AppTheme.textGrey),
              ]),
            ),
          ),
        ),
        if (open) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: child),
      ]),
    );
  }

  Widget _innerOption({required String t, required IconData i, required bool sel, required VoidCallback onT, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onT,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Icon(i, color: Colors.black87),
                const SizedBox(width: 12),
                Text(t, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: Colors.black87),
              ]),
            ),
          ),
        ),
        if (sel) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), child: child),
      ]),
    );
  }

  Widget _input(TextEditingController c, String h, IconData i, {bool isPass = false, bool? obs, VoidCallback? onT, bool dark = false}) {
    return TextField(
      controller: c, obscureText: obs ?? false, textAlign: TextAlign.left,
      style: TextStyle(color: dark ? Colors.black : AppTheme.textWhite, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: h, prefixIcon: Icon(i, color: dark ? Colors.black45 : AppTheme.primaryGold),
        fillColor: dark ? Colors.white.withValues(alpha: 0.8) : AppTheme.surfaceBlack,
        suffixIcon: isPass ? IconButton(icon: Icon(obs! ? Icons.visibility_off : Icons.visibility, color: AppTheme.textGrey), onPressed: onT) : null,
      ),
    );
  }

  Widget _bigBtn({required String l, required VoidCallback? o, bool dark = false}) {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
      onPressed: _loading ? null : o,
      style: ElevatedButton.styleFrom(backgroundColor: dark ? Colors.black : Colors.white, foregroundColor: dark ? Colors.white : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
    ));
  }

  // ── المكونات الأخرى (للمسجلين) ──
  Widget _buildHeader(UserModel user) { return Container(padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 24, left: 20, right: 20), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.primaryGold.withValues(alpha: 0.2), AppTheme.deepBlack])), child: Column(children: [ Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(user.isAdmin ? 'الملف الوظيفي' : 'حسابي', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 22, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.settings_outlined, color: AppTheme.primaryGold), onPressed: () => context.push('/user/settings'))]), const SizedBox(height: 16), Container(width: 88, height: 88, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppTheme.primary Gold.withValues(alpha: 0.8), AppTheme.primaryGold.withValues(alpha: 0.4)]), boxShadow: [BoxShadow(color: AppTheme.primaryGold.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 2)]), child: Container(margin: const EdgeInsets.all(3), decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceBlack), child: Center(child: Text(user.nm.isNotEmpty ? user.nm[0] : '؟', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 36, fontWeight: FontWeight.bold))))), const SizedBox(height: 12), Text(user.nm.isNotEmpty ? user.nm : 'مستخدم جديد', style: const TextStyle(color: AppTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 6), if (user.isAdmin) ...[Text(user.roleName, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 4), if (user.sid.isNotEmpty) Text('الرقم الوطني: ${user.sid}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)), if (user.ad.isNotEmpty) Text('العنوان: ${user.ad}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12))] else if (user.usr != null) Text('@${user.usr}', style: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.8), fontSize: 14)), const SizedBox(height: 12), if (!user.isAdmin) Row(mainAxisAlignment: MainAxisAlignment.center, children: [_chip(user.roleName, AppTheme.primaryGold.withValues(alpha: 0.15), AppTheme.primaryGold), const SizedBox(width: 8), _chip(user.badgeName, Colors.white.withValues(alpha: 0.08), AppTheme.textWhite), if (user.isVerifiedOfficial) ...[const SizedBox(width: 8), _chip('✓ موثق', Colors.green.withValues(alpha: 0.15), Colors.green)]]) ])); }
  Widget _chip(String t, Color b, Color f) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: b, borderRadius: BorderRadius.circular(16), border: Border.all(color: f.withValues(alpha: 0.3))), child: Text(t, style: TextStyle(color: f, fontSize: 12, fontWeight: FontWeight.w600)));
  Widget _buildUserStats(UserModel u) => Row(children: [Expanded(child: _statTile(icon: Icons.star_rounded, value: '${u.pt}', label: 'النقاط', color: const Color(0xFFFFD700))), const SizedBox(width: 12), Expanded(child: _statTile(icon: Icons.local_fire_department_rounded, value: '${u.strk}', label: 'أيام متتالية', color: const Color(0xFFFF6B35)))]);
  Widget _statTile({required IconData icon, required String value, required String label, required Color color}) => Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.2))), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.7), fontSize: 11))])]));
  Widget _buildActivityStats(UserModel u) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.15))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.analytics_outlined, color: AppTheme.primaryGold.withValues(alpha: 0.8), size: 18), const SizedBox(width: 8), const Text('إحصائيات النشاط', style: TextStyle(color: AppTheme.primaryGold, fontSize: 14, fontWeight: FontWeight.w600))]), const SizedBox(height: 14), Row(children: [_miniStat('عروض', u.stats['off'] ?? 0, Icons.home_work_outlined), _miniStat('طلبات', u.stats['req'] ?? 0, Icons.assignment_outlined), _miniStat('مواعيد', u.stats['app'] ?? 0, Icons.calendar_today_outlined), _miniStat('صفقات', u.stats['dl'] ?? 0, Icons.handshake_outlined)])]));
  Widget _miniStat(String l, int c, IconData i) => Expanded(child: Column(children: [Icon(i, color: AppTheme.primaryGold.withValues(alpha: 0.7), size: 20), const SizedBox(height: 6), Text('$c', style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(l, style: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.6), fontSize: 10))]));
  Widget _buildStaffStats(UserModel user) { if (_loadingStats) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)); if (_staffStats == null) return const SizedBox.shrink(); List<_StaffStatItem> items = []; if (user.isPhotographer) items = [_StaffStatItem(Icons.check_circle_outline, 'مهام مكتملة', _staffStats!['completed_tasks'] ?? 0, Colors.green)]; else if (user.isSupervisor) items = [_StaffStatItem(Icons.check_circle_outline, 'زيارات منفذة', _staffStats!['completed_visits'] ?? 0, Colors.green)]; else if (user.isEmployee) items = [_StaffStatItem(Icons.rate_review_outlined, 'عروض مراجَعة', _staffStats!['reviewed_offers'] ?? 0, Colors.blue)]; else if (user.isSenior || user.isManager) items = [_StaffStatItem(Icons.handshake_outlined, 'صفقات', _staffStats!['total_deals'] ?? 0, Colors.green), _StaffStatItem(Icons.payments_outlined, 'مدفوعات', _staffStats!['approved_payments'] ?? 0, Colors.blue), _StaffStatItem(Icons.verified_user_outlined, 'موثقون', _staffStats!['verified_users'] ?? 0, Colors.teal)]; return Wrap(spacing: 10, runSpacing: 10, children: items.map((it) => Container(width: (MediaQuery.of(context).size.width - 60) / 2, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: it.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: it.color.withValues(alpha: 0.2))), child: Row(children: [Icon(it.icon, color: it.color, size: 18), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${it.value}', style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)), Text(it.label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10))])]))).toList()); }
  Widget _buildMenuSection(UserModel u) => Column(children: [_menuItem(i: Icons.person_outline, t: u.isAdmin ? 'بياناتي الوظيفية' : 'معلومات الحساب', s: u.isAdmin ? 'بيانات التعيين والتحقق الوظيفي ✅' : 'معلوماتك الشخصية والتوثيق', o: () => context.push('/user/account-info')), _menuItem(i: Icons.star_outline, t: 'تقييماتي المستلمة', s: 'شاهد تقييمات العملاء لك', o: () => context.push('/user/my-ratings')), if (u.isAdmin) _menuItem(i: Icons.dashboard_outlined, t: 'لوحة التحكم الإدارية', s: 'الانتقال لواجهة العمليات', o: () { if (u.isPhotographer) context.go('/photographer/tasks'); else if (u.isSupervisor) context.go('/executor/tasks'); else if (u.isEmployee) context.go('/employee/dashboard'); else context.go('/admin/dashboard'); })]);
  Widget _menuItem({required IconData i, required String t, required String s, required VoidCallback o}) => ListTile(onTap: o, leading: Icon(i, color: AppTheme.primaryGold), title: Text(t, style: const TextStyle(color: AppTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold)), subtitle: Text(s, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)), trailing: const Icon(Icons.chevron_right, color: AppTheme.textGrey, size: 18));
  Widget _buildLogoutButton(AuthProvider a) => OutlinedButton.icon(onPressed: () { a.logout(); context.go('/user/profile'); }, icon: const Icon(Icons.logout, color: Colors.red), label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size(double.infinity, 50)));

  void _loadStaffStats() async {
    final auth = context.read<AuthProvider>();
    if (auth.userModel == null || !auth.userModel!.isInternal) return;
    setState(() => _loadingStats = true);
    try {
      final res = await SupabaseService().client.rpc('get_staff_stats_internal', params: {'p_user_uid': auth.userModel!.uid});
      if (mounted) setState(() { _staffStats = res is Map ? Map<String, dynamic>.from(res) : null; _loadingStats = false; });
    } catch (_) { if (mounted) setState(() => _loadingStats = false); }
  }
}

class _StaffStatItem { final IconData icon; final String label; final int value; final Color color; _StaffStatItem(this.icon, this.label, this.value, this.color); }
