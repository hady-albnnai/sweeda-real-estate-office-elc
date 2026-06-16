import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user_model.dart';

class ChangeRoleDialog extends StatefulWidget {
  final UserModel user;

  const ChangeRoleDialog({super.key, required this.user});

  @override
  State<ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<ChangeRoleDialog> {
  late int _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.role;
  }

  Future<void> _submit() async {
    if (_selectedRole == widget.user.role) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final adminProvider = context.read<AdminProvider>();
      final adminUid = auth.userModel?.uid ?? '';

      final success = await adminProvider.changeUserRole(
        adminUid,
        widget.user.uid,
        _selectedRole,
      );

      if (mounted) {
        Navigator.pop(context, success);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تغيير الدور بنجاح')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل تغيير الدور')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, false);
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
      title: Text('تغيير دور ${widget.user.nm}', style: const TextStyle(color: AppTheme.textWhite)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _selectedRole,
            dropdownColor: AppTheme.surfaceBlack,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: const InputDecoration(
              labelText: 'الدور الجديد',
              labelStyle: TextStyle(color: AppTheme.textGrey),
            ),
            items: [
              const DropdownMenuItem(value: 2, child: Text('مصور')),
              const DropdownMenuItem(value: 3, child: Text('مشرف ميداني')),
              const DropdownMenuItem(value: 4, child: Text('موظف مكتب')),
              if (isManager) const DropdownMenuItem(value: 5, child: Text('نائب مدير')),
            ],
            onChanged: (value) {
              setState(() => _selectedRole = value!);
            },
          ),
          const SizedBox(height: 16),
          if (widget.user.role == 6)
            const Text(
              'لا يمكن تغيير دور المدير الرئيسي',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey)),
        ),
        ElevatedButton(
          onPressed: (widget.user.role == 6 || _isLoading) ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('تغيير'),
        ),
      ],
    );
  }
}