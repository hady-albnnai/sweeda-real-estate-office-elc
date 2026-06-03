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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إكمال الملف الشخصي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أهلاً بك في المكتب العقاري',
              style: TextStyle(color: AppTheme.textWhite, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'يرجى تزويدنا ببعض المعلومات الأساسية لتوثيق حسابك',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            const Text(
              'الاسم الكامل',
              style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(
                hintText: 'أدخل اسمك الثلاثي',
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'رقم الهوية الوطنية (SID)',
              style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sidController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(
                hintText: 'أدخل رقم الهوية',
              ),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  if (_nameController.text.isNotEmpty && _sidController.text.isNotEmpty) {
                    await authProvider.completeProfile(
                      name: _nameController.text,
                      sid: _sidController.text,
                    );
                    context.go('/'); // Go to home
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إكمال جميع الحقول')),
                    );
                  }
                },
                child: const Text('ابدأ الآن'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
