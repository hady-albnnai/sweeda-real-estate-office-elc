import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sidController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _sidController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _sidController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إكمال جميع الحقول')),
      );
      return;
    }
    setState(() => _loading = true);
    final authProvider = context.read<AuthProvider>();
    final ok = await authProvider.completeProfile(
      name: _nameController.text.trim(),
      sid: _sidController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      // التوجّه حسب الدور
      if (authProvider.isAdmin) {
        context.go('/admin/dashboard');
      } else if (authProvider.isBroker) {
        context.go('/broker/dashboard');
      } else {
        context.go('/user/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حفظ البيانات، حاول مرة أخرى')),
      );
    }
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
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 8),
              const Text(
                'يرجى تزويدنا ببعض المعلومات الأساسية لتوثيق حسابك',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 28),
              const Text(
                'الاسم الكامل',
                style: TextStyle(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  hintText: 'أدخل اسمك الثلاثي',
                  prefixIcon: Icon(Icons.person, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'رقم الهوية الوطنية',
                style: TextStyle(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sidController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  hintText: 'أدخل رقم الهوية',
                  prefixIcon: Icon(Icons.badge, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 28),
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
                  label: const Text('ابدأ الآن'),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlack,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.primaryGold, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'بياناتك مشفّرة ومحفوظة بأمان، ولن تُشارك مع أي طرف ثالث.',
                        style: TextStyle(
                            color: AppTheme.textGrey, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
