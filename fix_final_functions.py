import os

# 1. become_broker_screen.dart
file1 = 'lib/screens/user/become_broker_screen.dart'
with open(file1, 'r', encoding='utf-8') as f:
    content1 = f.read()

content1 = content1.replace(
'''      await SupabaseService().client.rpc(
        'submit_broker_request_internal',
        params: {
          'p_user_uid': user.id,
          'p_business_name': _nameCtrl.text.trim(),
          'p_category': _selectedCategory,
          'p_experience': _expCtrl.text.trim(),
          'p_about': _aboutCtrl.text.trim(),
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'broker-actions',
        body: {
          'action': 'submit_request',
          'user_uid': user.id,
          'business_name': _nameCtrl.text.trim(),
          'category': _selectedCategory,
          'experience': _expCtrl.text.trim(),
          'about': _aboutCtrl.text.trim(),
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Submit failed');'''
)
with open(file1, 'w', encoding='utf-8') as f:
    f.write(content1)

# 2. stats_admin_service.dart
file2 = 'lib/services/admin/stats_admin_service.dart'
with open(file2, 'r', encoding='utf-8') as f:
    content2 = f.read()

content2 = content2.replace(
'''      final response = await SupabaseService().client.rpc(
        'get_admin_dashboard_stats',
        params: {'p_admin_uid': adminUid},
      );''',
'''      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().client.functions.invoke(
        'admin-dashboard',
        body: {
          'action': 'dashboard_stats',
          'admin_uid': adminUid,
          'staff_session_token': token,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Error');
      final res = data['stats'];'''
)
content2 = content2.replace(
'''      clearError();
      if (response == null) return null;
      return DashboardStatsModel.fromMap(
          Map<String, dynamic>.from(response as Map));''',
'''      clearError();
      if (res == null) return null;
      return DashboardStatsModel.fromMap(
          Map<String, dynamic>.from(res as Map));'''
)
with open(file2, 'w', encoding='utf-8') as f:
    f.write(content2)

# 3. profile_screen.dart
file3 = 'lib/screens/user/profile_screen.dart'
with open(file3, 'r', encoding='utf-8') as f:
    content3 = f.read()

content3 = content3.replace(
'''      final res = await SupabaseService().client.rpc('get_staff_stats_internal', params: {'p_user_uid': auth.userModel!.uid});''',
'''      final token = await context.read<AuthProvider>().getStaffSessionToken();
      final response = await SupabaseService().client.functions.invoke('admin-dashboard', body: {
        'action': 'staff_stats',
        'user_uid': auth.userModel!.uid,
        'staff_session_token': token,
      });
      final res = response.data != null && response.data['success'] == true ? response.data['stats'] : null;'''
)
with open(file3, 'w', encoding='utf-8') as f:
    f.write(content3)

# 4. staff_admin_service.dart
file4 = 'lib/services/admin/staff_admin_service.dart'
with open(file4, 'r', encoding='utf-8') as f:
    content4 = f.read()

content4 = content4.replace(
'''      final response = await SupabaseService().client.rpc(
        'get_all_staff_users',
        params: {'p_admin_uid': adminUid},
      );''',
'''      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().client.functions.invoke(
        'admin-dashboard',
        body: {
          'action': 'all_staff',
          'admin_uid': adminUid,
          'staff_session_token': token,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Error');
      final res = data['staff'] as List;'''
)
content4 = content4.replace(
'''      clearError();
      if (response == null) return [];
      return (response as List)
          .map((d) => UserModel.fromMap(Map<String, dynamic>.from(d)))
          .toList();''',
'''      clearError();
      return res
          .map((d) => UserModel.fromMap(Map<String, dynamic>.from(d)))
          .toList();'''
)

content4 = content4.replace(
'''      final response = await SupabaseService().client.rpc(
        'get_staff_stats_internal',
        params: {'p_user_uid': targetUid},
      );''',
'''      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().client.functions.invoke(
        'admin-dashboard',
        body: {
          'action': 'staff_stats',
          'user_uid': targetUid,
          'staff_session_token': token,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Error');
      final res = data['stats'];'''
)
content4 = content4.replace(
'''      clearError();
      if (response == null) return null;
      return Map<String, dynamic>.from(response as Map);''',
'''      clearError();
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);'''
)
with open(file4, 'w', encoding='utf-8') as f:
    f.write(content4)

# 5. fraud_suspects_screen.dart
file5 = 'lib/screens/admin/fraud_suspects_screen.dart'
with open(file5, 'r', encoding='utf-8') as f:
    content5 = f.read()

content5 = content5.replace(
'''          await SupabaseService().client.rpc('admin_fraud_suspects', params: {'p_admin_uid': adminId});''',
'''          await SupabaseService().client.functions.invoke('admin-dashboard', body: {
            'action': 'fraud_suspects',
            'admin_uid': adminId,
            'staff_session_token': await AuthService().getStaffSessionToken(),
          }).then((res) => res.data != null && res.data['success'] == true ? res.data['suspects'] : []);'''
)
with open(file5, 'w', encoding='utf-8') as f:
    f.write(content5)

# 6. auth_service.dart
file6 = 'lib/services/auth_service.dart'
with open(file6, 'r', encoding='utf-8') as f:
    content6 = f.read()

content6 = content6.replace(
'''          await _client.rpc('revoke_staff_session', params: {
            'p_user_uid': user.id,
            'p_token': staffToken,
          });''',
'''          await _client.functions.invoke('admin-dashboard', body: {
            'action': 'revoke_session',
            'user_uid': user.id,
            'staff_session_token': staffToken,
          });'''
)

# reset_password_with_otp is for resetting password, user-account is best
content6 = content6.replace(
'''      await _client.rpc(
        'reset_password_with_otp',
        params: {
          'p_user_uid': userUid,
          'p_new_password': newPassword,
        },
      );''',
'''      final response = await _client.functions.invoke(
        'user-account',
        body: {
          'action': 'reset_password',
          'user_uid': userUid,
          'new_password': newPassword,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Reset failed');'''
)

with open(file6, 'w', encoding='utf-8') as f:
    f.write(content6)
