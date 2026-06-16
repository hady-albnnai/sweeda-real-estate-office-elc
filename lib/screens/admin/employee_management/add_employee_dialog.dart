import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/input_validators.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/auth_provider.dart';

class AddEmployeeDialog extends StatefulWidget {
  const AddEmployeeDialog({super.key});

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  int _selectedRole = 4; // موظف مكتب افتراضي
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) => InputValidators.validateUsername(value);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final adminProvider = context.read<AdminProvider>();
      final adminUid = auth.userModel?.uid;

      if (adminUid == null) {
        throw Exception('لم يتم العثور على جلسة المدير');
      }

      final result = await adminProvider.createStaffUser(
        adminUid: adminUid,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        role: _selectedRole,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pop(context, result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل إضافة الموظف: ${result['error'] ?? 'خطأ غير معروف'}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = context.read<AuthProvider>().userModel?.role == 6;

    return AlertDialog(
      backgroundColor: AppTheme.surfaceBlack,
      title: const Text('إضافة موظف جديد', style: TextStyle(color: AppTheme.textWhite)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل *',
                  labelStyle: TextStyle(color: AppTheme.textGrey),
                ),
                validator: InputValidators.validateName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف *',
                  labelStyle: TextStyle(color: AppTheme.textGrey),
                ),
                keyboardType: TextInputType.phone,
                validator: InputValidators.validateSyrianPhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم (اختياري)',
                  labelStyle: TextStyle(color: AppTheme.textGrey),
                  hintText: 'مثال: office_1',
                  hintStyle: TextStyle(color: AppTheme.textGrey),
                ),
                validator: _validateUsername,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني (اختياري)',
                  labelStyle: TextStyle(color: AppTheme.textGrey),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selectedRole,
                dropdownColor: AppTheme.surfaceBlack,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  labelText: 'الدور *',
                  labelStyle: TextStyle(color: AppTheme.textGrey),
                ),
                items: [
                  const DropdownMenuItem(value: 2, child: Text('مصور')),
                  const DropdownMenuItem(value: 3, child: Text('مشرف ميداني')),
                  const DropdownMenuItem(value: 4, child: Text('موظف مكتب')),
                  if (isManager) const DropdownMenuItem(value: 5, child: Text('نائب مدير')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedRole = value);
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.25)),
                ),
                child: const Text(
                  'سيتم توليد كلمة سر تلقائياً وعرضها مرة واحدة بعد الإضافة.',
                  style: TextStyle(color: AppTheme.primaryGold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('إضافة'),
        ),
      ],
    );
  }
}
