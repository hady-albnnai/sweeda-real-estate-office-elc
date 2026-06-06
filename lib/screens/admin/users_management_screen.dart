import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_theme.dart';

/// 👥 إدارة المستخدمين — بحث + حظر/تجميد/تفعيل + تغيير الدور
class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final _searchCtrl = TextEditingController();
  List<UserModel> _users = [];
  bool _loading = true;
  String _search = '';

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
    final users = await context.read<AdminProvider>().getAllUsers(search: _search);
    if (mounted) {
      setState(() {
        _users = users;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        backgroundColor: AppTheme.deepBlack,
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الهاتف...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: AppTheme.primaryGold),
                  onPressed: () {
                    _search = _searchCtrl.text.trim();
                    _load();
                  },
                ),
                filled: true,
                fillColor: AppTheme.surfaceBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (v) {
                _search = v.trim();
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryGold))
                : _users.isEmpty
                    ? const Center(
                        child: Text('لا يوجد مستخدمون',
                            style: TextStyle(color: AppTheme.textGrey)))
                    : RefreshIndicator(
                        color: AppTheme.primaryGold,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _users.length,
                          itemBuilder: (_, i) => _userTile(_users[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _userTile(UserModel u) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: () => context.push('/admin/user/${u.uid}'),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.15),
          child: Text(u.nm.isNotEmpty ? u.nm[0] : '؟',
              style: const TextStyle(color: AppTheme.primaryGold)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(u.nm.isEmpty ? 'بدون اسم' : u.nm,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            _statusDot(u.sts),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${u.ph}  •  ${u.roleName}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
            Text('${u.badgeName}  •  ⭐ ${u.pt}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.primaryGold),
          color: AppTheme.surfaceBlack,
          onSelected: (v) => _onAction(v, u),
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'role', child: Text('تغيير الدور', style: TextStyle(color: AppTheme.textWhite))),
            if (u.sts != 0)
              const PopupMenuItem(
                  value: 'activate', child: Text('تفعيل', style: TextStyle(color: Colors.green))),
            if (u.sts != 1)
              const PopupMenuItem(
                  value: 'freeze', child: Text('تجميد', style: TextStyle(color: Colors.orange))),
            if (u.sts != 2)
              const PopupMenuItem(
                  value: 'ban', child: Text('حظر', style: TextStyle(color: AppTheme.errorRed))),
          ],
        ),
      ),
    );
  }

  Widget _statusDot(int sts) {
    Color c;
    String t;
    switch (sts) {
      case 1:
        c = Colors.orange;
        t = 'مجمّد';
        break;
      case 2:
        c = AppTheme.errorRed;
        t = 'محظور';
        break;
      default:
        c = Colors.green;
        t = 'نشط';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(t, style: TextStyle(color: c, fontSize: 10)),
    );
  }

  Future<void> _onAction(String action, UserModel u) async {
    final admin = context.read<AdminProvider>();
    final adminId = context.read<AuthProvider>().userModel?.uid ?? '';

    switch (action) {
      case 'role':
        _showRoleDialog(u);
        break;
      case 'activate':
        if (await admin.activateUser(u.uid)) {
          _snack('تم تفعيل ${u.nm}');
          _load();
        }
        break;
      case 'freeze':
        final reason = await _askReason('سبب التجميد');
        if (reason != null) {
          if (await admin.freezeUser(u.uid, reason)) {
            _snack('تم تجميد ${u.nm}');
            _load();
          }
        }
        break;
      case 'ban':
        final reason = await _askReason('سبب الحظر');
        if (reason != null) {
          if (await admin.banUser(u.uid, reason)) {
            _snack('تم حظر ${u.nm}');
            _load();
          }
        }
        break;
    }
    // منع تحذير عدم استخدام adminId
    debugPrint('action by admin: $adminId');
  }

  void _showRoleDialog(UserModel u) {
    final roles = {
      0: 'مستخدم',
      1: 'وسيط',
      2: 'مشرف',
      3: 'نائب',
      4: 'مدير',
    };
    final admin = context.read<AdminProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('تغيير الدور', style: TextStyle(color: AppTheme.primaryGold)),
        content: RadioGroup<int>(
          groupValue: u.role,
          onChanged: (val) async {
            if (val == null) return;
            Navigator.pop(ctx);
            if (await admin.updateUserRole(u.uid, val)) {
              _snack('تم تغيير دور ${u.nm} إلى ${roles[val]}');
              _load();
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: roles.entries
                .map((e) => RadioListTile<int>(
                      value: e.key,
                      activeColor: AppTheme.primaryGold,
                      title: Text(e.value,
                          style: const TextStyle(color: AppTheme.textWhite)),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<String?> _askReason(String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: Text(title, style: const TextStyle(color: AppTheme.primaryGold)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(hintText: 'اكتب السبب...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? '—' : ctrl.text.trim()),
              child: const Text('تأكيد')),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
