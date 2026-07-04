import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

class PermissionsManagementScreen extends StatefulWidget {
  const PermissionsManagementScreen({super.key});

  @override
  State<PermissionsManagementScreen> createState() => _PermissionsManagementScreenState();
}

class _PermissionsManagementScreenState extends State<PermissionsManagementScreen> {
  final _searchCtrl = TextEditingController();
  List<UserModel> _users = [];
  UserModel? _selectedUser;
  Set<String> _selectedPermissions = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await context.read<AdminProvider>().getAllUsers(
          search: _searchCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _users = users;
      if (_selectedUser != null) {
        for (final user in users) {
          if (user.uid == _selectedUser!.uid) {
            _selectUser(user);
            break;
          }
        }
      }
      _loading = false;
    });
  }

  void _selectUser(UserModel user) {
    _selectedUser = user;
    _selectedPermissions = PermissionService.effectivePermissions(user).toSet();
  }

  Future<void> _save() async {
    final user = _selectedUser;
    if (user == null) return;
    setState(() => _saving = true);
    final ok = await context.read<AdminProvider>().updateUserPermissions(
          context.read<AuthProvider>().userModel?.uid ?? '',
          user.uid,
          _selectedPermissions.toList()..sort(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    AppTheme.showSnackBar(context,
      SnackBar(content: Text(ok ? 'تم حفظ الصلاحيات' : 'فشل حفظ الصلاحيات')),
    );
    if (ok) await _load();
  }

  Future<void> _resetToRoleDefault() async {
    final user = _selectedUser;
    if (user == null) return;
    setState(() => _saving = true);
    final ok = await context.read<AdminProvider>().updateUserPermissions(context.read<AuthProvider>().userModel?.uid ?? '', user.uid, const []);
    if (!mounted) return;
    setState(() => _saving = false);
    AppTheme.showSnackBar(context,
      SnackBar(content: Text(ok ? 'تمت العودة لصلاحيات الدور' : 'فشل إعادة الضبط')),
    );
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 820;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        title: const Text('إدارة الصلاحيات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : wide
              ? Row(
                  children: [
                    SizedBox(width: 360, child: _usersPane()),
                    const VerticalDivider(color: AppTheme.surfaceBlack, width: 1),
                    Expanded(child: _permissionsPane()),
                  ],
                )
              : _selectedUser == null
                  ? _usersPane()
                  : _permissionsPane(showBack: true),
    );
  }

  Widget _usersPane() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: InputDecoration(
              hintText: 'بحث عن مستخدم...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: AppTheme.primaryGold),
                onPressed: _load,
              ),
              filled: true,
              fillColor: AppTheme.surfaceBlack,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _users.length,
            itemBuilder: (_, index) {
              final user = _users[index];
              final selected = _selectedUser?.uid == user.uid;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryGold.withOpacity(0.10) : AppTheme.surfaceBlack,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? AppTheme.primaryGold : AppTheme.primaryGold.withOpacity(0.14)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryGold.withOpacity(0.15),
                    child: Text(user.nm.isNotEmpty ? user.nm[0] : '؟', style: const TextStyle(color: AppTheme.primaryGold)),
                  ),
                  title: Text(user.nm.isEmpty ? 'بدون اسم' : user.nm, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
                  subtitle: Text('${user.roleName} • ${PermissionService.effectivePermissions(user).length} صلاحية', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                  trailing: selected ? const Icon(Icons.check_circle, color: AppTheme.primaryGold) : const Icon(Icons.chevron_left, color: AppTheme.textGrey),
                  onTap: () => setState(() => _selectUser(user)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _permissionsPane({bool showBack = false}) {
    final user = _selectedUser;
    if (user == null) {
      return const Center(
        child: Text('اختر مستخدماً لتعديل صلاحياته', style: TextStyle(color: AppTheme.textGrey)),
      );
    }

    final grouped = PermissionService.grouped();
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBlack,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.20)),
          ),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
                  onPressed: () => setState(() => _selectedUser = null),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.nm.isEmpty ? 'بدون اسم' : user.nm, style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(user.perm.isEmpty ? 'صلاحيات الدور الافتراضية' : 'صلاحيات مخصصة', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                  ],
                ),
              ),
              Text('${_selectedPermissions.length}', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _selectedPermissions = PermissionService.defaultsForRole(user.role).toSet()),
                child: const Text('افتراضي الدور'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _selectedPermissions = PermissionService.permissions.map((permission) => permission.key).toSet()),
                child: const Text('تحديد الكل'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _selectedPermissions.clear()),
                child: const Text('إلغاء الكل'),
              ),
              TextButton(
                onPressed: _saving ? null : _resetToRoleDefault,
                child: const Text('حذف التخصيص'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: grouped.entries.map((entry) => _groupCard(entry.key, entry.value)).toList(),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'جار الحفظ...' : 'حفظ الصلاحيات'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupCard(String group, List<AppPermission> permissions) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...permissions.map((permission) {
            final checked = _selectedPermissions.contains(permission.key);
            return SwitchListTile(
              value: checked,
              activeColor: AppTheme.primaryGold,
              title: Text(permission.title, style: const TextStyle(color: AppTheme.textWhite)),
              subtitle: Text(permission.key, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
              onChanged: (value) {
                setState(() {
                  if (value) {
                    _selectedPermissions.add(permission.key);
                  } else {
                    _selectedPermissions.remove(permission.key);
                  }
                });
              },
            );
          }),
        ],
      ),
    );
  }
}
