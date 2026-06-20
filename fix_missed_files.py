import os

# 1. offer_detail_screen.dart -> create_report_internal
file1 = 'lib/screens/visitor/offer_detail_screen.dart'
with open(file1, 'r', encoding='utf-8') as f:
    content1 = f.read()

content1 = content1.replace(
'''      await SupabaseService().client.rpc(
        'create_report_internal',
        params: {
          'p_reporter_uid': auth.userModel!.uid,
          'p_report': {
            'tgt_uid': _offer!.usrId,
            'tgt_tp': 1,
            'tgt_id': _offer!.id,
            'rsn': rsnIndex < 0 ? 0 : rsnIndex,
            'det': notesCtrl.text.trim(),
          },
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-account',
        body: {
          'action': 'create_report',
          'user_uid': auth.userModel!.uid,
          'report': {
            'tgt_uid': _offer!.usrId,
            'tgt_tp': 1,
            'tgt_id': _offer!.id,
            'rsn': rsnIndex < 0 ? 0 : rsnIndex,
            'det': notesCtrl.text.trim(),
          },
        },
      );
      if (response.data == null || response.data['success'] != true) {
        throw Exception(response.data?['error'] ?? 'Report failed');
      }'''
)
with open(file1, 'w', encoding='utf-8') as f:
    f.write(content1)

# 2. appointments_admin_service.dart -> get_admin_requests_internal
file2 = 'lib/services/admin/appointments_admin_service.dart'
with open(file2, 'r', encoding='utf-8') as f:
    content2 = f.read()

if "import '../auth_service.dart';" not in content2:
    lines = content2.split('\\n')
    idx = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            idx = i + 1
    lines.insert(idx, "import '../auth_service.dart';")
    content2 = '\\n'.join(lines)

content2 = content2.replace(
'''      final response = await SupabaseService().client.rpc(
        'get_admin_requests_internal',
        params: {'p_admin_uid': adminUid},
      );
      clearError();
      return (response as List)
          .map((d) => RequestModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();''',
'''      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().client.functions.invoke(
        'admin-dashboard',
        body: {
          'action': 'admin_requests',
          'admin_uid': adminUid,
          'staff_session_token': token,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Error fetching requests');
      clearError();
      return (data['requests'] as List)
          .map((d) => RequestModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();'''
)
with open(file2, 'w', encoding='utf-8') as f:
    f.write(content2)

# 3. broker_provider.dart -> get_broker_offers_internal, get_broker_deals_internal
file3 = 'lib/providers/broker_provider.dart'
with open(file3, 'r', encoding='utf-8') as f:
    content3 = f.read()

content3 = content3.replace(
'''      final snap = await SupabaseService().client.rpc(
        'get_broker_offers_internal',
        params: {'p_broker_uid': brokerId},
      );
      _offers = (snap as List)''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'broker_offers',
          'user_uid': brokerId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Error');
      _offers = (data['offers'] as List)'''
)

content3 = content3.replace(
'''      final snap = await SupabaseService().client.rpc(
        'get_broker_deals_internal',
        params: {'p_broker_uid': brokerId},
      );
      _deals = (snap as List)''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'broker_deals',
          'user_uid': brokerId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Error');
      _deals = (data['deals'] as List)'''
)

content3 = content3.replace(
'''      final offersSnap = await SupabaseService().client.rpc(
        'get_broker_offers_internal',
        params: {'p_broker_uid': brokerId},
      );
      final offersList = offersSnap as List;''',
'''      final offersRes = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'broker_offers',
          'user_uid': brokerId,
        },
      );
      final offersList = offersRes.data != null && offersRes.data['success'] == true 
          ? offersRes.data['offers'] as List 
          : [];'''
)

content3 = content3.replace(
'''      final dealsSnap = await SupabaseService().client.rpc(
        'get_broker_deals_internal',
        params: {'p_broker_uid': brokerId},
      );
      final dealsList = dealsSnap as List;''',
'''      final dealsRes = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'broker_deals',
          'user_uid': brokerId,
        },
      );
      final dealsList = dealsRes.data != null && dealsRes.data['success'] == true 
          ? dealsRes.data['deals'] as List 
          : [];'''
)

# 4. Fix get_broker_appointments_internal in fetchBrokerStats that was replaced earlier but maybe incorrectly
content3 = content3.replace(
'''      final apptSnap = await SupabaseService().client.rpc(
        'get_broker_appointments_internal',
        params: {'p_broker_uid': brokerId},
      );
      final apptList = apptSnap as List;''',
'''      final apptRes = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'list_broker_appointments',
          'user_uid': brokerId,
        },
      );
      final apptList = apptRes.data != null && apptRes.data['success'] == true 
          ? apptRes.data['appointments'] as List 
          : [];'''
)
with open(file3, 'w', encoding='utf-8') as f:
    f.write(content3)

# 5. payment_provider.dart -> get_user_payments_internal
file4 = 'lib/providers/payment_provider.dart'
with open(file4, 'r', encoding='utf-8') as f:
    content4 = f.read()

content4 = content4.replace(
'''      final response = await SupabaseService().client.rpc(
        'get_user_payments_internal',
        params: {'p_user_uid': userId},
      );
      _payments = (response as List)''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-account',
        body: {
          'action': 'user_payments',
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Error fetching payments');
      _payments = (data['payments'] as List)'''
)
with open(file4, 'w', encoding='utf-8') as f:
    f.write(content4)

