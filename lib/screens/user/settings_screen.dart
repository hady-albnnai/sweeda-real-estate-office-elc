import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../widgets/bottom_nav_bar.dart';

/// شاشة الإعدادات
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifOffers = true;
  bool _notifAppointments = true;
  bool _notifFinance = true;
  bool _notifRatings = true;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ntf = auth.userModel?.ntf ?? {};
    setState(() {
      _notifOffers = (ntf['off'] ?? 0) == 0;
      _notifAppointments = (ntf['app'] ?? 0) == 0;
      _notifFinance = (ntf['fin'] ?? 0) == 0;
      _notifRatings = (ntf['rat'] ?? 0) == 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isInternal = auth.userModel?.isInternal ?? false;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: const Text('الإعدادات', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.primaryGold),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          // قسم الإشعارات
          _sectionTitle('إعدادات الإشعارات', Icons.notifications_outlined),
          if (isInternal) ...[
            // الإدارة: فقط إشعارات المواعيد
            _toggleTile('إشعارات المواعيد', _notifAppointments, (v) => _toggle('app', v)),
          ] else ...[
            // المستخدمون العاديون: كل الإشعارات
            _toggleTile('إشعارات العروض الجديدة', _notifOffers, (v) => _toggle('off', v)),
            _toggleTile('إشعارات المواعيد', _notifAppointments, (v) => _toggle('app', v)),
            _toggleTile('الإشعارات المالية', _notifFinance, (v) => _toggle('fin', v)),
            _toggleTile('التقييمات والتعليقات', _notifRatings, (v) => _toggle('rat', v)),
          ],

          const SizedBox(height: 20),

          // قسم الحساب
          _sectionTitle('الحساب', Icons.person_outline_rounded),
          _settingsTile('معلومات الحساب', Icons.person_outline, () => context.push('/user/account-info')),
          _settingsTile('تغيير كلمة المرور', Icons.lock_outline, () => context.push('/user/account-info')),
          if (!isInternal)
            _settingsTile('الباقة الحالية', Icons.card_membership,
                () => context.push('/user/packages')),

          const SizedBox(height: 20),

          // قسم التطبيق
          _sectionTitle('التطبيق', Icons.phone_android_outlined),
          _settingsTile('عن التطبيق', Icons.info, () => _showAboutDialog()),

          const SizedBox(height: 30),

          // تسجيل الخروج
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout, color: AppTheme.deepBlack),
              label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.deepBlack,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // إصدار التطبيق
          Center(
            child: Text('الإصدار 1.0.0', style: TextStyle(color: AppTheme.textGrey.withOpacity(0.5), fontSize: 12)),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(currentIndex: auth.userModel?.isInternal == true ? 0 : 4),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 5),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGold.withOpacity(0.8), size: 18),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _toggleTile(String title, bool value, Function(bool) onChanged) {
    return Card(
      color: AppTheme.surfaceBlack,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: AppTheme.textWhite)),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryGold,
        activeTrackColor: AppTheme.primaryGold.withOpacity(0.3),
      ),
    );
  }

  Widget _settingsTile(String title, IconData icon, VoidCallback onTap) {
    return Card(
      color: AppTheme.surfaceBlack,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryGold),
        title: Text(title, style: const TextStyle(color: AppTheme.textWhite)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textGrey),
        onTap: onTap,
      ),
    );
  }

  void _toggle(String key, bool value) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;
    if (user == null) return;

    final ntf = Map<String, dynamic>.from(user.ntf);
    ntf[key] = value ? 0 : 1;

    try {
      await SupabaseService().invokeFunction('user-notifications', body: {'action': 'update_settings', 'ntf': ntf});
      await auth.refreshUser();

      if (!mounted) return;
      setState(() {
        switch (key) {
          case 'off': _notifOffers = value; break;
          case 'app': _notifAppointments = value; break;
          case 'fin': _notifFinance = value; break;
          case 'rat': _notifRatings = value; break;
        }
      });
      AppTheme.showSnackBar(context,
        const SnackBar(content: Text('تم الحفظ ✅'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (mounted) {
        AppTheme.showSnackBar(context,
          const SnackBar(content: Text('فشل الحفظ')),
        );
      }
    }
  }

  void _showAboutDialog() {
    final configProv = Provider.of<ConfigProvider>(context, listen: false);
    final config = configProv.config;
    final facebook = config?.facebookPage ?? '';
    final instagram = config?.instagramPage ?? '';
    final devPhone = config?.developerPhone ?? '(سيتم إضافته لاحقاً)';
    final extraSocials = config?.socialPages ?? {};

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('عن التطبيق', style: TextStyle(color: AppTheme.primaryGold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // من نحن
              const Text(
                'من نحن',
                style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'نحن فريق من الشباب المبدعين الذين يؤمنون بتحويل تجربة الوساطة العقارية إلى نموذج يجمع بين الاحترافية العالية والأمان المطلق. نسعى لتحقيق أعلى معايير الشفافية، وحماية حقوق جميع الأطراف، وتسهيل كافة الإجراءات بأحدث التقنيات الرقمية.',
                style: TextStyle(color: AppTheme.textWhite, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),

              // صفحات التواصل الاجتماعي
              if (facebook.isNotEmpty || instagram.isNotEmpty || extraSocials.isNotEmpty) ...[
                const Text(
                  'تابعنا على',
                  style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (facebook.isNotEmpty)
                  _socialLinkTile('فيسبوك', Icons.facebook, facebook, () => _launchUrl(facebook)),
                if (instagram.isNotEmpty)
                  _socialLinkTile('إنستغرام', Icons.camera_alt, instagram, () => _launchUrl(instagram)),
                ...extraSocials.entries.map((e) {
                  final label = e.key.toString();
                  final url = e.value?.toString() ?? '';
                  if (url.isEmpty) return const SizedBox.shrink();
                  return _socialLinkTile(label, Icons.link, url, () => _launchUrl(url));
                }),
                const SizedBox(height: 16),
              ],

              // المطور
              const Text(
                'التطوير',
                style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // أيقونة لورانيم بسطر لحالها
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/loraneem_tech_logo.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Column(
                  children: [
                    Text(
                      'loraneem-tech',
                      style: TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'CODE • AI • LIMITLESS EVOLUTION',
                      style: TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // رقم المطور
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.deepBlack,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryGold.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone, color: AppTheme.primaryGold, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'رقم المطور: $devPhone',
                      style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // معلومات التطبيق
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              const Text(
                'عقارات السويداء — المكتب العقاري الإلكتروني\n\n'
                'تطبيق لتصفح وعرض العقارات والسيارات في محافظة السويداء',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'الإصدار: 1.0.0\nBackend: Supabase • Frontend: Flutter',
                style: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.7), fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً', style: TextStyle(color: AppTheme.primaryGold))),
        ],
      ),
    );
  }

  Widget _socialLinkTile(String label, IconData icon, String url, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.deepBlack,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryGold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.open_in_new, color: AppTheme.textGrey, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AppTheme.showSnackBar(context, const SnackBar(content: Text('تعذر فتح الرابط')));
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('تسجيل الخروج', style: TextStyle(color: AppTheme.textWhite)),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟', style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              context.go('/login');
            },
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
