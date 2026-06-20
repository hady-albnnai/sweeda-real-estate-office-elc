import os

file_path = 'lib/providers/broker_provider.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final response = await SupabaseService().client.rpc(
        'get_broker_appointments_internal',
        params: {'p_broker_uid': brokerId},
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'list_broker_appointments',
          'user_uid': brokerId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Unknown error');
      final list = data['appointments'] as List;'''
)

# Fix map for list_broker_appointments
content = content.replace(
'''      return (response as List)
          .map((d) => AppointmentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();''',
'''      return list
          .map((d) => AppointmentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();'''
)

content = content.replace(
'''      await SupabaseService().client.rpc(
        'broker_handle_appointment_internal',
        params: {
          'p_broker_uid': brokerId,
          'p_appointment_id': appointmentId,
          'p_action': 'accept',
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'broker_handle',
          'user_uid': brokerId,
          'appointment_id': appointmentId,
          'handle_action': 'accept',
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return false;'''
)

content = content.replace(
'''      await SupabaseService().client.rpc(
        'broker_handle_appointment_internal',
        params: {
          'p_broker_uid': brokerId,
          'p_appointment_id': appointmentId,
          'p_action': 'reject',
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'broker_handle',
          'user_uid': brokerId,
          'appointment_id': appointmentId,
          'handle_action': 'reject',
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return false;'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
