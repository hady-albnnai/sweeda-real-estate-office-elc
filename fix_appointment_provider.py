import os

file_path = 'lib/providers/appointment_provider.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      await SupabaseService().client.rpc(
        'book_appointment_internal',
        params: {
          'p_user_uid': userId,
          'p_offer_id': offerId,
          'p_dt': dateTime.toIso8601String(),
          'p_broker_id': brokerId,
          'p_request_id': requestId,
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'book',
          'user_uid': userId,
          'offer_id': offerId,
          'dt': dateTime.toIso8601String(),
          'broker_id': brokerId,
          'request_id': requestId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return false;'''
)

content = content.replace(
'''      final res = await SupabaseService().client.rpc(
        'get_user_appointments_internal',
        params: {'p_user_uid': userId},
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'list_user_appointments',
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return [];
      final res = data['appointments'];'''
)

content = content.replace(
'''      final res = await SupabaseService().client.rpc(
        'get_owner_appointments_internal',
        params: {'p_owner_uid': ownerId},
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'list_owner_appointments',
          'user_uid': ownerId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return [];
      final res = data['appointments'];'''
)

content = content.replace(
'''      await SupabaseService().client.rpc(
        'cancel_appointment_internal',
        params: {
          'p_requester_uid': requesterId,
          'p_appointment_id': appointmentId,
          'p_reason': reason,
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'cancel',
          'user_uid': requesterId,
          'appointment_id': appointmentId,
          'reason': reason,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return false;'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
