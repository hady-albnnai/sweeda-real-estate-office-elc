import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../models/user_model.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _staffStats;
  bool _loadingStats = false;
  int _activeBlock = 0; 
  int _signupMethod = 0;

  final _loginUserCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  final _signupPhoneCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  
  bool _isPassObscure = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadStaffStats();
  }

  @override
  void dispose() {
    _loginUserCtrl.dispose();
    _loginPassCtrl.dispose();
    _signupPhoneCtrl.dispose();
    _signupEmailCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _loadStaffStats() async {
    final auth = context.read<AuthProvider>();
    if (auth.userModel == null || !auth.userModel!.isInternal) return;
    setState(() => _loadingStats = true);
    try {
      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().invokeFunction('admin-dashboard', body: {
        'action': 'staff_stats',
        'user_uid': auth.userModel!.uid,
        'staff_session_token': token,
      });
      final res = response.data != null && response.data['success'] == true ? response.data['stats'] : null;
      if (mounted) setState(() { _staffStats = res is Map ? Map<String, dynamic>.from(res) : null; _loadingStats = false; });
    } catch (_) { if (mounted) setState(() => _loadingStats = false); }
  }

    Future<void> _handleLogin() async {
    final user = _loginUserCtrl.text.trim();
    final pass = _loginPassCtrl.text;
    if (user.isEmpty || pass.isEmpty) {
      _snack('يرجى إدخال كافة البيانات');
      return;
    }
    setState(() => _isBusy = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithPassword(user, pass);
    if (mounted) setState(() => _isBusy = false);
    if (!ok) {
      _snack('فشل تسجيل الدخول، تأكد من بياناتك');
    } else {
      // 🚀 توجيه فوري - لا ننتظر rebuild كي لا تظهر شاشة الحساب للحظة
      if (mounted) {
        if (auth.isSenior || auth.isLawyer) {
          context.go('/admin/dashboard');
        } else if (auth.isEmployee) {
          context.go('/employee/home');
        } else if (auth.isSupervisor || auth.isExpediter) {
          context.go('/executor/tasks');
        } else if (auth.isPhotographer) {
          context.go('/photographer/tasks');
        } else if (auth.isBroker) {
          context.go('/broker/dashboard');
        } else {
          context.go('/user/home');
        }
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final phone = _loginUserCtrl.text.trim();
    if (phone.length != 10 || !phone.startsWith('09')) {
      _snack('أدخل رقم هاتفك في خانة المستخدم أولاً');
      return;
    }
    setState(() => _isBusy = true);
    final ok = await context.read<AuthProvider>().sendSMSOTP(phone);
    if (mounted) {
      setState(() => _isBusy = false);
    }
    if (ok) {
      _snack('تم إرسال كود الاستعادة SMS');
      context.push('/otp');
    } else {
      _snack('فشل إرسال رسالة الاستعادة');
    }
  }

  Future<void> _handleSignupPhone() async {
    final phone = _signupPhoneCtrl.text.trim();
    if (phone.length != 10 || !phone.startsWith('09')) {
      _snack('أدخل رقم هاتف صحيح');
      return;
    }
    setState(() => _isBusy = true);
    final ok = await context.read<AuthProvider>().sendSMSOTP(phone);
    if (mounted) {
      setState(() => _isBusy = false);
    }
    if (ok) {
      _snack('تم إرسال رمز التفعيل SMS');
      context.push('/otp');
    } else {
      _snack('فشل إرسال SMS التفعيل');
    }
  }

  Future<void> _handleSignupEmail() async {
    final email = _signupEmailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('أدخل بريداً صحيحاً');
      return;
    }
    setState(() => _isBusy = true);
    final ok = await context.read<AuthProvider>().sendEmailMagicLink(email);
    if (mounted) {
      setState(() => _isBusy = false);
    }
    if (ok) {
      _snack('تم إرسال رابط التفعيل لبريدك');
      context.push('/check-email');
    } else {
      _snack('فشل إرسال رابط الإيميل');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.deepBlack,
        body: _buildVisitorUI(),
        bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(user)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (user.isInternal) _buildStaffStats(user)
                else ...[_buildUserStats(user), const SizedBox(height: 16), _buildActivityStats(user)],
                const SizedBox(height: 20),
                _buildMenuSection(user),
                const SizedBox(height: 20),
                _buildLogoutButton(auth),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4),
    );
  }

  Widget _buildVisitorUI() {
    final sz = MediaQuery.sizeOf(context);
    final logoSize = (sz.shortestSide * 0.9).clamp(300.0, 520.0);

    return Container(
      width: double.infinity,
      color: AppTheme.deepBlack,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Hero(
                tag: 'logo',
                child: Container(
                  width: logoSize, height: logoSize * 0.75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppTheme.primaryGold.withOpacity(0.2), blurRadius: 100, spreadRadius: 30),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: logoSize * 0.72, height: logoSize * 0.72,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4), width: 4)),
                      ),
                      Container(
                        width: logoSize * 0.65, height: logoSize * 0.65,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceBlack),
                        padding: const EdgeInsets.all(35),
                        child: Image.asset('assets/images/logo_app.png', fit: BoxFit.contain),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('المكتب العقاري الإلكتروني', style: GoogleFonts.cairo(color: AppTheme.primaryGold, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 50),

              _buildBlock(
                id: 2, title: 'تسجيل الدخول', icon: Icons.login_rounded, isGold: false,
                child: Column(children: [
                  _buildInput(_loginUserCtrl, 'اسم المستخدم أو رقم الهاتف', Icons.person_outline),
                  const SizedBox(height: 12),
                  _buildInput(_loginPassCtrl, 'كلمة المرور', Icons.lock_outline, isPass: true, obscure: _isPassObscure, onToggle: () => setState(() => _isPassObscure = !_isPassObscure)),
                  const SizedBox(height: 20),
                  _buildBigBtn(label: 'دخول', onTap: _handleLogin),
                  const SizedBox(height: 10),
                  TextButton(onPressed: _handleForgotPassword, child: const Text('هل نسيت كلمة المرور؟ استعادة بـ SMS', style: TextStyle(color: AppTheme.primaryGold, decoration: TextDecoration.underline, fontSize: 13))),
                ]),
              ),

              const SizedBox(height: 16),

              _buildBlock(
                id: 1, title: 'تسجيل حساب جديد', icon: Icons.person_add_alt_1_outlined, isGold: true,
                child: Column(children: [
                  _buildInnerOption(id: 1, title: 'تسجيل عن طريق رقم الهاتف', icon: Icons.phone_android, child: Column(children: [
                    const Text('سيصلك رمز تفعيل برسالة نصية SMS', style: TextStyle(color: Colors.black87, fontSize: 11)),
                    const SizedBox(height: 12),
                    _buildInput(_signupPhoneCtrl, '09XXXXXXXX', Icons.phone_iphone, dark: true),
                    const SizedBox(height: 12),
                    _buildBigBtn(label: 'إرسال رمز التفعيل SMS', onTap: _handleSignupPhone, dark: true),
                  ])),
                  const SizedBox(height: 12),
                  _buildInnerOption(id: 2, title: 'تسجيل عن طريق الإيميل', icon: Icons.alternate_email, child: Column(children: [
                    const Text('سيصلك رابط تفعيل إلى بريدك الإلكتروني', style: TextStyle(color: Colors.black87, fontSize: 11)),
                    const SizedBox(height: 12),
                    _buildInput(_signupEmailCtrl, 'example@mail.com', Icons.email_outlined, dark: true),
                    const SizedBox(height: 12),
                    _buildBigBtn(label: 'إرسال رابط التفعيل', onTap: _handleSignupEmail, dark: true),
                  ])),
                ]),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlock({required int id, required String title, required IconData icon, required bool isGold, required Widget child}) {
    final isOpen = _activeBlock == id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isGold ? AppTheme.primaryGold : AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.5), width: 2),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() { _activeBlock = isOpen ? 0 : id; if (id == 1) _signupMethod = 0; }),
          borderRadius: BorderRadius.circular(24),
          child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
            Icon(icon, color: isOpen && isGold ? Colors.black : (isGold ? Colors.black : AppTheme.primaryGold), size: 28),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: isGold ? Colors.black : AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.w900)),
            const Spacer(),
            Icon(isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: isGold ? Colors.black : AppTheme.textGrey),
          ])),
        ),
        if (isOpen) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: child),
      ]),
    );
  }

  Widget _buildInnerOption({required int id, required String title, required IconData icon, required Widget child}) {
    final sel = _signupMethod == id;
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        ListTile(
          onTap: () => setState(() => _signupMethod = sel ? 0 : id),
          leading: Icon(icon, color: Colors.black87),
          title: Text(title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
          trailing: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: Colors.black87),
        ),
        if (sel) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), child: child),
      ]),
    );
  }

  Widget _buildInput(TextEditingController c, String h, IconData i, {bool isPass = false, bool? obscure, VoidCallback? onToggle, bool dark = false}) {
    return TextField(
      controller: c, obscureText: obscure ?? false, textAlign: TextAlign.left,
      style: TextStyle(color: dark ? Colors.black : AppTheme.textWhite, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: h, prefixIcon: Icon(i, color: dark ? Colors.black45 : AppTheme.primaryGold),
        fillColor: dark ? Colors.white.withOpacity(0.8) : AppTheme.surfaceBlack,
        suffixIcon: isPass ? IconButton(icon: Icon(obscure! ? Icons.visibility_off : Icons.visibility, color: AppTheme.textGrey), onPressed: onToggle) : null,
      ),
    );
  }

  Widget _buildBigBtn({required String label, required VoidCallback? onTap, bool dark = false}) {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
      onPressed: _isBusy ? null : onTap,
      style: ElevatedButton.styleFrom(backgroundColor: dark ? Colors.black : Colors.white, foregroundColor: dark ? Colors.white : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: _isBusy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
    ));
  }

  Widget _buildHeader(UserModel user) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 24, left: 20, right: 20),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.primaryGold.withOpacity(0.2), AppTheme.deepBlack])),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(user.isAdmin ? 'الملف الوظيفي' : 'حسابي', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 22, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.settings_outlined, color: AppTheme.primaryGold), onPressed: () => context.push('/user/settings')),
        ]),
        const SizedBox(height: 16),
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [AppTheme.primaryGold, AppTheme.lightGold]), boxShadow: [BoxShadow(color: AppTheme.primaryGold.withOpacity(0.25), blurRadius: 20, spreadRadius: 2)]),
          child: Container(margin: const EdgeInsets.all(3), decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceBlack), child: Center(child: Text(user.nm.isNotEmpty ? user.nm[0] : '؟', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 36, fontWeight: FontWeight.bold)))),
        ),
        const SizedBox(height: 12),
        Text(user.nm.isNotEmpty ? user.nm : 'مستخدم جديد', style: const TextStyle(color: AppTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (user.isAdmin) ...[
          Text(user.roleName, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (user.sid.isNotEmpty) Text('الرقم الوطني: ${user.sid}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
          if (user.ad.isNotEmpty) Text('العنوان: ${user.ad}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ] else if (user.usr != null)
          Text('@${user.usr}', style: TextStyle(color: AppTheme.textGrey.withOpacity(0.8), fontSize: 14)),
        const SizedBox(height: 12),
        if (!user.isInternal)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _buildChip(user.roleName, AppTheme.primaryGold.withOpacity(0.15), AppTheme.primaryGold),
            const SizedBox(width: 8),
            _buildChip(user.badgeName, Colors.white.withOpacity(0.08), AppTheme.textWhite),
            if (user.isVerifiedOfficial) ...[const SizedBox(width: 8), _buildChip('✓ موثق', Colors.green.withOpacity(0.15), Colors.green)],
          ]),
      ]),
    );
  }

  Widget _buildChip(String t, Color b, Color f) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: b, borderRadius: BorderRadius.circular(16), border: Border.all(color: f.withOpacity(0.3))), child: Text(t, style: TextStyle(color: f, fontSize: 12, fontWeight: FontWeight.w600)));
  Widget _buildUserStats(UserModel u) => Row(children: [Expanded(child: _buildStatTile(icon: Icons.star_rounded, value: '${u.pt}', label: 'النقاط', color: const Color(0xFFFFD700))), const SizedBox(width: 12), Expanded(child: _buildStatTile(icon: Icons.local_fire_department_rounded, value: '${u.strk}', label: 'أيام متتالية', color: const Color(0xFFFF6B35)))]);
  Widget _buildStatTile({required IconData icon, required String value, required String label, required Color color}) => Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: TextStyle(color: AppTheme.textGrey.withOpacity(0.7), fontSize: 11))])]));
  Widget _buildActivityStats(UserModel u) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.analytics_outlined, color: AppTheme.primaryGold.withOpacity(0.8), size: 18), const SizedBox(width: 8), const Text('إحصائيات النشاط', style: TextStyle(color: AppTheme.primaryGold, fontSize: 14, fontWeight: FontWeight.w600))]), const SizedBox(height: 14), Row(children: [_buildMiniStat('عروض', u.stats['off'] ?? 0, Icons.home_work_outlined), _buildMiniStat('طلبات', u.stats['req'] ?? 0, Icons.assignment_outlined), _buildMiniStat('مواعيد', u.stats['app'] ?? 0, Icons.calendar_today_outlined), _buildMiniStat('صفقات', u.stats['dl'] ?? 0, Icons.handshake_outlined)])]));
  Widget _buildMiniStat(String l, int c, IconData i) => Expanded(child: Column(children: [Icon(i, color: AppTheme.primaryGold.withOpacity(0.7), size: 20), const SizedBox(height: 6), Text('$c', style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(l, style: TextStyle(color: AppTheme.textGrey.withOpacity(0.6), fontSize: 10))]));
  Widget _buildStaffStats(UserModel user) {
    if (_loadingStats) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppTheme.primaryGold),
        ),
      );
    }
    if (_staffStats == null) {
      return const SizedBox.shrink();
    }

    List<_StaffStatItem> items = [];
    if (user.isPhotographer) {
      items = [
        _StaffStatItem(Icons.check_circle_outline, 'مهام مكتملة',
            _staffStats!['completed_tasks'] ?? 0, Colors.green),
      ];
    } else if (user.isSupervisor) {
      items = [
        _StaffStatItem(Icons.check_circle_outline, 'زيارات منفذة',
            _staffStats!['completed_visits'] ?? 0, Colors.green),
      ];
    } else if (user.isEmployee) {
      items = [
        _StaffStatItem(Icons.rate_review_outlined, 'عروض مراجَعة',
            _staffStats!['reviewed_offers'] ?? 0, Colors.blue),
      ];
    } else if (user.isSenior || user.isManager) {
      items = [
        _StaffStatItem(Icons.handshake_outlined, 'صفقات',
            _staffStats!['total_deals'] ?? 0, Colors.green),
        _StaffStatItem(Icons.payments_outlined, 'مدفوعات',
            _staffStats!['approved_payments'] ?? 0, Colors.blue),
        _StaffStatItem(Icons.verified_user_outlined, 'موثقون',
            _staffStats!['verified_users'] ?? 0, Colors.teal),
      ];
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map((it) => Container(
                width: (MediaQuery.of(context).size.width - 60) / 2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: it.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: it.color.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Icon(it.icon, color: it.color, size: 18),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${it.value}',
                        style: const TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text(it.label,
                        style: const TextStyle(
                            color: AppTheme.textGrey, fontSize: 10)),
                  ]),
                ]),
              ))
          .toList(),
    );
  }

  Widget _buildMenuSection(UserModel u) => Column(children: [
        _buildMenuItem(
            i: Icons.person_outline,
            t: u.isAdmin ? 'بياناتي الوظيفية' : 'معلومات الحساب',
            s: u.isAdmin
                ? 'بيانات التعيين والتحقق الوظيفي ✅'
                : 'معلوماتك الشخصية والتوثيق',
            o: () => context.push('/user/account-info')),
        _buildMenuItem(
            i: Icons.star_outline,
            t: 'تقييماتي المستلمة',
            s: 'شاهد تقييمات العملاء لك',
            o: () => context.push('/user/my-ratings')),
        if (u.isAdmin)
          _buildMenuItem(
              i: Icons.dashboard_outlined,
              t: 'لوحة التحكم الإدارية',
              s: 'الانتقال لواجهة العمليات',
              o: () {
                if (u.isPhotographer) {
                  context.go('/photographer/tasks');
                } else if (u.isSupervisor) {
                  context.go('/executor/tasks');
                } else if (u.isEmployee) {
                  context.go('/employee/home');
                } else {
                  context.go('/admin/dashboard');
                }
              }),
      ]);
  Widget _buildMenuItem({required IconData i, required String t, required String s, required VoidCallback o}) => ListTile(onTap: o, leading: Icon(i, color: AppTheme.primaryGold), title: Text(t, style: const TextStyle(color: AppTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold)), subtitle: Text(s, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)), trailing: const Icon(Icons.chevron_right, color: AppTheme.textGrey, size: 18));
  Widget _buildLogoutButton(AuthProvider a) => OutlinedButton.icon(onPressed: () { a.logout(); context.go('/user/profile'); }, icon: const Icon(Icons.logout, color: Colors.red), label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size(double.infinity, 50)));
}

class _StaffStatItem { final IconData icon; final String label; final int value; final Color color; _StaffStatItem(this.icon, this.label, this.value, this.color); }
