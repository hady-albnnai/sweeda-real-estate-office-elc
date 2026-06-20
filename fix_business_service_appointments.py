import os

file_path = 'lib/core/services/business_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      await _sb.client.rpc(DbConstants.ownerRespondAppointment, params: {
        'p_owner_uid': ownerUid,
        'p_appointment_id': appointmentId,
        'p_accept': true,
      });''',
'''      final response = await _sb.client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'owner_respond',
          'user_uid': ownerUid,
          'appointment_id': appointmentId,
          'accept': true,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Error');'''
)

content = content.replace(
'''      await _sb.client.rpc(DbConstants.ownerRespondAppointment, params: {
        'p_owner_uid': ownerUid,
        'p_appointment_id': appointmentId,
        'p_accept': false,
        'p_reject_reason': rejectReason,
        'p_reject_text': rejectText,
        'p_proposed_dt': proposedDt?.toIso8601String(),
      });''',
'''      final response = await _sb.client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'owner_respond',
          'user_uid': ownerUid,
          'appointment_id': appointmentId,
          'accept': false,
          'reject_reason': rejectReason,
          'reject_text': rejectText,
          'proposed_dt': proposedDt?.toIso8601String(),
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Error');'''
)

content = content.replace(
'''      await _sb.client.rpc(DbConstants.requesterCounterAppointment, params: {
        'p_user_uid': userUid,
        'p_appointment_id': appointmentId,
        'p_accept': true,
      });''',
'''      final response = await _sb.client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'requester_counter',
          'user_uid': userUid,
          'appointment_id': appointmentId,
          'accept': true,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Error');'''
)

content = content.replace(
'''      await _sb.client.rpc(DbConstants.requesterCounterAppointment, params: {
        'p_user_uid': userUid,
        'p_appointment_id': appointmentId,
        'p_accept': false,
        'p_proposed_dt': proposedDt?.toIso8601String(),
      });''',
'''      final response = await _sb.client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'requester_counter',
          'user_uid': userUid,
          'appointment_id': appointmentId,
          'accept': false,
          'proposed_dt': proposedDt?.toIso8601String(),
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Error');'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
