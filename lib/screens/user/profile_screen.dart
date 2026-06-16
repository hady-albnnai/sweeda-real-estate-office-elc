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
  Map<String, dynamic>? _staffStats;
  bool _loadingStats = false;
  int _activeBlock = 0; // 1: SignUp, 2: Login

  // ── حقول تسجيل الدخول ──
  final _loginIdCtrl = TextEditingController();
  final _loginPwdCtrl = TextEditingController();
  bool _loginObscure = true;
  bool _isLoginLoading = false;

  // ── حقول التسجيل الجديد ──
  final _signUpPhoneCtrl = TextEditingController();
  bool _isSignUpLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStaffStats();
  }

  @override
  void dispose() {
    _loginIdCtrl.dispose();
    _loginPwdCtrl.dispose();
    _signUpPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStaffStats() async {
    final auth = context.read<AuthProvider>();
    if (auth.userModel == null || !auth.userModel!.isInternal) return;
    setState(() => _loadingStats = true);
    try {
      final res = await SupabaseService().client.rpc('get_staff_stats_internal', params: {'p_user_uid': auth.userModel!.uid});
      if (mounted) setState(() { _staffStats = res is Map ? Map<String, dynamic>.from(res) : null; _loadingStats = false; });
    } catch (_) { if (mounted) setState(() => _loadingStats = false); }
  }

  // ── العمليات الوظيفية ──

  Future<void> _handleLogin() async {
    final id = _loginIdCtrl.text.trim();
    final pass = _loginPwdCtrl.text;
    if (id.isEmpty || pass.isEmpty) { _toast('يرجى إدخال البيانات المطلوبة'); return; }
    setState(() => _isLoginLoading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithPassword(id, pass);
    if (mounted) setState(() => _isLoginLoading = false);
    if (!ok) _toast(auth.lastError ?? 'بيانات الدخول غير صحيحة');
  }

  Future<void> _handleForgotPassword() async {
    final phone = _loginIdCtrl.text.trim();
    if (phone.length != 10 || !phone.startsWith('09')) { _toast('أدخل رقم هاتفك في الخانة الأولى أولاً (09xxxxxxxx)'); return; }
    setState(() => _isLoginLoading = true);
    final ok = await context.read<AuthProvider>().sendSMSOTP(phone);
    if (mounted) setState(() => _isLoginLoading = false);
    if (ok) { _toast('تم إرسال كود استعادة بـ SMS'); context.push('/otp'); }
  }

  Future<void> _handleSignUp() async {
    final phone = _signUpPhoneCtrl.text.trim();
    if (phone.length != 10 || !phone.startsWith('09')) { _toast('أدخل رقم هاتف صحيح'); return; }
    setState(() => _isSignUpLoading = true);
    final ok = await context.read<AuthProvider>().sendSMSOTP(phone);
    if (mounted) setState(() => _isSignUpLoading = false);
    if (ok) { _toast('تم إرسال رمز التفعيل SMS'); context.push('/otp'); }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.userModel == null) return Scaffold(backgroundColor: AppTheme.deepBlack, body: _buildGuestUI(), bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4));

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _buildHeader(auth.userModel!)),
        SliverPadding(padding: const EdgeInsets.all(20), sliver: SliverList(delegate: SliverChildListDelegate([
          if (auth.userModel!.isInternal) _buildStaffStats(auth.userModel!) else ...[_buildUserStats(auth.userModel!), const SizedBox(height: 16), _buildActivityStats(auth.userModel!)],
          const SizedBox(height: 20), _buildMenuSection(auth.userModel!), const SizedBox(height: 20), _buildLogoutButton(auth), const SizedBox(height: 30),
        ]))),
      ]),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // واجهة الزائر — الشعار الماكس والقائمتين
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGuestUI() {
    final sz = MediaQuery.sizeOf(context);
    final logoSize = (sz.shortestSide * 0.92).clamp(320.0, 600.0);

    return Container(
      width: double.infinity,
      color: AppTheme.deepBlack,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 10),
            // 🔥 الشعار بأقصى حجم (Maximized)
            Hero(tag: 'logo', child: Container(
              width: logoSize, height: logoSize * 0.72,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppTheme.primaryGold.withValues(alpha: 0.2), blurRadius: 100, spreadRadius: 30)]),
              child: Stack(alignment: Alignment.center, children: [
                Container(width: logoSize * 0.7, height: logoSize * 0.7, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4), width: 4))),
                Container(width: logoSize * 0.64, height: logoSize * 0.64, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceBlack), padding: const EdgeInsets.all(35), child: Image.asset('assets/images/logo_app.png', fit: BoxFit.contain)),
              ]),
            )),
            Text('المكتب العقاري الإلكتروني', style: GoogleFonts.cairo(color: AppTheme.primaryGold, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 40),

            // ── القائمة 1: تسجيل الدخول ──
            _buildActionBlock(
              id: 2, title: 'تسجيل الدخول', icon: Icons.login_rounded, isPrimary: false,
              child: Column(children: [
                _field(_loginIdCtrl, 'اسم المستخدم أو الهاتف', Icons.person_outline),
                const SizedBox(height: 12),
                _field(_loginPwdCtrl, 'كلمة المرور', Icons.lock_outline, isPass: true, obscure: _loginObscure, onToggle: () => setState(() => _loginObscure = !_loginObscure)),
                const SizedBox(height: 16),
                _btn(onTap: _isLoginLoading ? null : _handleLogin, label: 'دخول', loading: _isLoginLoading),
                TextButton(onPressed: _doForgotPassword, child: const Text('هل نسيت كلمة السر؟ استعادة بـ SMS', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13, decoration: TextDecoration.underline))),
              ]),
            ),
            const SizedBox(height: 16),

            // ── القائمة 2: تسجيل جديد ──
            _buildActionBlock(
              id: 1, title: 'تسجيل حساب جديد', icon: Icons.person_add_alt_1_outlined, isPrimary: true,
              child: Column(children: [
                const Text('سجل برقم هاتفك لتلقي رمز تفعيل SMS مجاني', textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _field(_signUpPhoneCtrl, '09XXXXXXXX', Icons.phone_android_outlined, light: true),
                const SizedBox(height: 16),
                _btn(onTap: _isSignUpLoading ? null : _doSignUp, label: 'إرسال رمز التفعيل', loading: _isSignUpLoading, isDark: true),
              ]),
            ),
            const SizedBox(height: 50),
          ]),
        ),
      ),
    );
  }

  // ── مساعدات الواجهة ──

  Widget _buildActionBlock({required int id, required String title, required IconData icon, required bool isPrimary, required Widget child}) {
    final open = _activeBlock == id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isPrimary ? AppTheme.primaryGold : AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.5), width: 2), boxShadow: [if (open) BoxShadow(color: AppTheme.primaryGold.withValues(alpha: 0.2), blurRadius: 40)]),
      child: Column(children: [
        InkWell(onTap: () => setState(() => _activeBlock = open ? 0 : id), child: Row(children: [
          Icon(icon, color: isPrimary ? Colors.black : AppTheme.primaryGold, size: 28),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(color: isPrimary ? Colors.black : AppTheme.textWhite, fontSize: 19, fontWeight: FontWeight.w900)),
          const Spacer(),
          Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: isPrimary ? Colors.black : AppTheme.textGrey),
        ])),
        if (open) ...[const SizedBox(height: 24), child],
      ]),
    );
  }

  Widget _field(TextEditingController c, String h, IconData i, {bool isPass = false, bool? obscure, VoidCallback? onToggle, bool light = false}) {
    return TextField(
      controller: c, obscureText: obscure ?? false, textAlign: TextAlign.left,
      style: TextStyle(color: light ? Colors.black : AppTheme.textWhite, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: h, prefixIcon: Icon(i, color: light ? Colors.black54 : AppTheme.primaryGold),
        fillColor: light ? Colors.white.withValues(alpha: 0.9) : AppTheme.surfaceBlack,
        suffixIcon: isPass ? IconButton(icon: Icon(obscure! ? Icons.visibility_off : Icons.visibility, color: AppTheme.textGrey), onPressed: onToggle) : null,
      ),
    );
  }

  Widget _btn({required VoidCallback? onTap, required String label, bool loading = false, bool isDark = false}) {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.black : Colors.white, foregroundColor: isDark ? Colors.white : Colors.black),
      child: loading ? CircularProgressIndicator(color: isDark ? Colors.white : Colors.black) : Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
    ));
  }

  // ── بقية المكونات (كما هي في النسخ الاحترافية السابقة) ──
  Widget _buildHeader(UserModel user) { return Container(padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 24, left: 20, right: 20), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.primaryGold.withValues(alpha: 0.2), AppTheme.deepBlack])), child: Column(children: [ Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(user.isAdmin ? 'الملف الوظيفي' : 'حسابي', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 22, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.settings_outlined, color: AppTheme.primaryGold), onPressed: () => context.push('/user/settings'))]), const SizedBox(height: 16), Container(width: 88, height: 88, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppTheme.primaryGold.withValues(alpha: 0.8), AppTheme.primaryGold.withValues(alpha: 0.4)]), boxShadow: [BoxShadow(color: AppTheme.primaryGold.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 2)]), child: Container(margin: const EdgeInsets.all(3), decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceBlack), child: Center(child: Text(user.nm.isNotEmpty ? user.nm[0] : '؟', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 36, fontWeight: FontWeight.bold))))), const SizedBox(height: 12), Text(user.nm.isNotEmpty ? user.nm : 'مستخدم جديد', style: const TextStyle(color: AppTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 6), if (user.isAdmin) ...[Text(user.roleName, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 4), if (user.sid.isNotEmpty) Text('الرقم الوطني: ${user.sid}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)), if (user.ad.isNotEmpty) Text('العنوان: ${user.ad}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12))] else if (user.usr != null) Text('@${user.usr}', style: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.8), fontSize: 14)), const SizedBox(height: 12), if (!user.isAdmin) Row(mainAxisAlignment: MainAxisAlignment.center, children: [_chip(user.roleName, AppTheme.primaryGold.withValues(alpha: 0.15), AppTheme.primaryGold), const SizedBox(width: 8), _chip(user.badgeName, Colors.white.withValues(alpha: 0.08), AppTheme.textWhite), if (user.isVerifiedOfficial) ...[const SizedBox(width: 8), _chip('✓ موثق', Colors.green.withValues(alpha: 0.15), Colors.green)]]) ])); }
  Widget _chip(String t, Color b, Color f) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: b, borderRadius: BorderRadius.circular(16), border: Border.all(color: f.withValues(alpha: 0.3))), child: Text(t, style: TextStyle(color: f, fontSize: 12, fontWeight: FontWeight.w600)));
  Widget _buildUserStats(UserModel u) => Row(children: [Expanded(child: _statTile(icon: Icons.star_rounded, value: '${u.pt}', label: 'النقاط', color: const Color(0xFFFFD700))), const SizedBox(width: 12), Expanded(child: _statTile(icon: Icons.local_fire_department_rounded, value: '${u.strk}', label: 'أيام متتالية', color: const Color(0xFFFF6B35)))]);
  Widget _statTile({required IconData icon, required String value, required String label, required Color color}) => Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.2))), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.7), fontSize: 11))])]));
  Widget _buildActivityStats(UserModel u) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.15))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.analytics_outlined, color: AppTheme.primaryGold.withValues(alpha: 0.8), size: 18), const SizedBox(width: 8), const Text('إحصائيات النشاط', style: TextStyle(color: AppTheme.primaryGold, fontSize: 14, fontWeight: FontWeight.w600))]), const SizedBox(height: 14), Row(children: [_miniStat('عروض', u.stats['off'] ?? 0, Icons.home_work_outlined), _miniStat('طلبات', u.stats['req'] ?? 0, Icons.assignment_outlined), _miniStat('مواعيد', u.stats['app'] ?? 0, Icons.calendar_today_outlined), _miniStat('صفقات', u.stats['dl'] ?? 0, Icons.handshake_outlined)])]));
  Widget _miniStat(String l, int c, IconData i) => Expanded(child: Column(children: [Icon(i, color: AppTheme.primaryGold.withValues(alpha: 0.7), size: 20), const SizedBox(height: 6), Text('$c', style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(l, style: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.6), fontSize: 10))]));
  Widget _buildStaffStats(UserModel user) { if (_loadingStats) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)); if (_staffStats == null) return const SizedBox.shrink(); List<_StaffStatItem> items = []; if (user.isPhotographer) items = [_StaffStatItem(Icons.check_circle_outline, 'مهام مكتملة', _staffStats!['completed_tasks'] ?? 0, Colors.green)]; else if (user.isSupervisor) items = [_StaffStatItem(Icons.check_circle_outline, 'زيارات منفذة', _staffStats!['completed_visits'] ?? 0, Colors.green)]; else if (user.isEmployee) items = [_StaffStatItem(Icons.rate_review_outlined, 'عروض مراجَعة', _staffStats!['reviewed_offers'] ?? 0, Colors.blue)]; else if (user.isSenior || user.isManager) items = [_StaffStatItem(Icons.handshake_outlined, 'صفقات', _staffStats!['total_deals'] ?? 0, Colors.green), _StaffStatItem(Icons.payments_outlined, 'مدفوعات', _staffStats!['approved_payments'] ?? 0, Colors.blue), _StaffStatItem(Icons.verified_user_outlined, 'موثقون', _staffStats!['verified_users'] ?? 0, Colors.teal)]; return Wrap(spacing: 10, runSpacing: 10, children: items.map((it) => Container(width: (MediaQuery.of(context).size.width - 60) / 2, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: it.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: it.color.withValues(alpha: 0.2))), child: Row(children: [Icon(it.icon, color: it.color, size: 18), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${it.value}', style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)), Text(it.label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10))])]))).toList()); }
  Widget _buildMenuSection(UserModel u) => Column(children: [_menuItem(i: Icons.person_outline, t: u.isAdmin ? 'بياناتي الوظيفية' : 'معلومات الحساب', s: u.isAdmin ? 'بيانات التعيين والتحقق الوظيفي ✅' : 'معلوماتك الشخصية والتوثيق', o: () => context.push('/user/account-info')), _menuItem(i: Icons.star_outline, t: 'تقييماتي المستلمة', s: 'شاهد تقييمات العملاء لك', o: () => context.push('/user/my-ratings')), if (u.isAdmin) _menuItem(i: Icons.dashboard_outlined, t: 'لوحة التحكم الإدارية', s: 'الانتقال لواجهة العمليات', o: () { if (u.isPhotographer) context.go('/photographer/tasks'); else if (u.isSupervisor) context.go('/executor/tasks'); else if (u.isEmployee) context.go('/employee/dashboard'); else context.go('/admin/dashboard'); })]);
  Widget _menuItem({required IconData i, required String t, required String s, required VoidCallback o}) => ListTile(onTap: o, leading: Icon(i, color: AppTheme.primaryGold), title: Text(t, style: const TextStyle(color: AppTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold)), subtitle: Text(s, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)), trailing: const Icon(Icons.chevron_right, color: AppTheme.textGrey, size: 18));
  Widget _buildLogoutButton(AuthProvider a) => OutlinedButton.icon(onPressed: () { a.logout(); context.go('/login'); }, icon: const Icon(Icons.logout, color: Colors.red), label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size(double.infinity, 50)));
}

class _StaffStatItem { final IconData icon; final String label; final int value; final Color color; _StaffStatItem(this.icon, this.label, this.value, this.color); }
