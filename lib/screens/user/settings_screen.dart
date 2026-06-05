import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../core/constants/db_constants.dart';
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
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
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
          _sectionTitle('🔔 إعدادات الإشعارات'),
          _toggleTile('إشعارات العروض الجديدة', _notifOffers, (v) => _toggle('off', v)),
          _toggleTile('إشعارات المواعيد', _notifAppointments, (v) => _toggle('app', v)),
          _toggleTile('الإشعارات المالية', _notifFinance, (v) => _toggle('fin', v)),
          _toggleTile('التقييمات والتعليقات', _notifRatings, (v) => _toggle('rat', v)),

          const SizedBox(height: 20),

          // قسم الحساب
          _sectionTitle('👤 الحساب'),
          _settingsTile('تعديل الملف الشخصي', Icons.edit, () {}),
          _settingsTile('تغيير كلمة المرور', Icons.lock, () {}),
          _settingsTile('الباقة الحالية', Icons.card_membership,
              () => context.push('/user/packages')),

          const SizedBox(height: 20),

          // قسم التطبيق
          _sectionTitle('📱 التطبيق'),
          _settingsTile('عن التطبيق', Icons.info, () => _showAboutDialog()),
          _settingsTile('سياسة الخصوصية', Icons.privacy_tip, () {}),
          _settingsTile('شروط الاستخدام', Icons.gavel, () {}),

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
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 5),
      child: Text(title, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
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
    // 0 = مفعّل, 1 = معطّل (حسب SPEC)
    ntf[key] = value ? 0 : 1;

    try {
      await SupabaseService().client.from(DbTables.users).update({
        'ntf': ntf,
        'ts_upd': DateTime.now().toIso8601String(),
      }).eq('id', user.uid);

      await auth.refreshUser();

      if (!mounted) return;
      setState(() {
        switch (key) {
          case 'off':
            _notifOffers = value;
            break;
          case 'app':
            _notifAppointments = value;
            break;
          case 'fin':
            _notifFinance = value;
            break;
          case 'rat':
            _notifRatings = value;
            break;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ ✅'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      debugPrint('❌ toggle notif: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحفظ')),
        );
      }
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('عن التطبيق', style: TextStyle(color: AppTheme.primaryGold)),
        content: const Text(
          'عقارات السويداء — المكتب العقاري الإلكتروني\n\n'
          'تطبيق لتصفح وعرض العقارات والسيارات في محافظة السويداء\n\n'
          'الإصدار: 1.0.0\n'
          'Backend: Supabase\n'
          'Frontend: Flutter',
          style: TextStyle(color: AppTheme.textGrey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً', style: TextStyle(color: AppTheme.primaryGold))),
        ],
      ),
    );
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
