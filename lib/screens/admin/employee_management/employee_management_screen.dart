import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';

/// شاشة إدارة الموظفين (الأولوية الأولى)
/// مستوحاة من مشروع Final + ملتزمة بالدستور
class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final adminProvider = context.read<AdminProvider>();
      // نفترض وجود دالة getAllStaff أو نستخدم getUsers
      final users = await adminProvider.getAllStaffUsers();
      
      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((user) {
          return user.nm.toLowerCase().contains(query) ||
                 (user.ph?.toLowerCase().contains(query) ?? false) ||
                 (user.eml?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _showAddEmployeeDialog() async {
    // سيتم تنفيذها في المرحلة التالية
    // حالياً نعرض رسالة
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم إضافة نموذج إضافة موظف في التحديث القادم')),
    );
  }

  Future<void> _changeRole(UserModel user) async {
    // سيتم تنفيذها لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم تنفيذ تغيير الدور في التحديث القادم')),
    );
  }

  Future<void> _toggleStatus(UserModel user) async {
    // سيتم تنفيذها لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم تنفيذ تفعيل/تعطيل في التحديث القادم')),
    );
  }

  Future<void> _resetPassword(UserModel user) async {
    // سيتم تنفيذها لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم تنفيذ إعادة تعيين كلمة السر في التحديث القادم')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.userModel;

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        title: const Text('إدارة الموظفين', style: TextStyle(color: AppTheme.textWhite)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primaryGold),
            onPressed: _showAddEmployeeDialog,
            tooltip: 'إضافة موظف جديد',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الهاتف أو البريد...',
                hintStyle: const TextStyle(color: AppTheme.textGrey),
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                filled: true,
                fillColor: AppTheme.surfaceBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // قائمة الموظفين
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _filteredUsers.isEmpty
                        ? const Center(
                            child: Text('لا يوجد موظفون', style: TextStyle(color: AppTheme.textGrey)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return _buildEmployeeCard(user);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(UserModel user) {
    final roleName = _getRoleName(user.role);
    final roleColor = _getRoleColor(user.role);
    final isActive = user.sts == 0;

    return Card(
      color: AppTheme.surfaceBlack,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.2),
                  child: Text(
                    user.nm.isNotEmpty ? user.nm[0] : '?',
                    style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nm,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          roleName,
                          style: TextStyle(color: roleColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textGrey),
                  onSelected: (value) {
                    switch (value) {
                      case 'change_role':
                        _changeRole(user);
                        break;
                      case 'toggle_status':
                        _toggleStatus(user);
                        break;
                      case 'reset_password':
                        _resetPassword(user);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'change_role', child: Text('تغيير الدور')),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Text(isActive ? 'تعطيل' : 'تفعيل'),
                    ),
                    const PopupMenuItem(value: 'reset_password', child: Text('إعادة تعيين كلمة السر')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: AppTheme.textGrey),
                const SizedBox(width: 6),
                Text(user.ph ?? '—', style: const TextStyle(color: AppTheme.textGrey)),
              ],
            ),
            if (user.eml != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: AppTheme.textGrey),
                  const SizedBox(width: 6),
                  Text(user.eml!, style: const TextStyle(color: AppTheme.textGrey)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive 
                    ? Colors.green.withValues(alpha: 0.2) 
                    : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isActive ? 'نشط' : 'معطل',
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleName(int role) {
    switch (role) {
      case 2: return 'مصور';
      case 3: return 'مشرف';
      case 4: return 'موظف مكتب';
      case 5: return 'نائب مدير';
      case 6: return 'مدير';
      default: return 'غير معروف';
    }
  }

  Color _getRoleColor(int role) {
    switch (role) {
      case 2: return Colors.teal;
      case 3: return Colors.orange;
      case 4: return Colors.blue;
      case 5: return Colors.purple;
      case 6: return AppTheme.primaryGold;
      default: return Colors.grey;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}