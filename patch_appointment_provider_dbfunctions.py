import os

file_path = 'lib/providers/appointment_provider.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      await SupabaseService().client.rpc(
        DbFunctions.ownerRespondAppointment,
        params: {
          'p_owner_uid':       ownerUid,
          'p_appointment_id':  appointmentId,
          'p_accept':          accept,
          'p_reject_reason':   rejectReason,
          'p_reject_text':     rejectText,
          'p_proposed_dt':     proposedDt?.toIso8601String(),
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'owner_respond',
          'user_uid': ownerUid,
          'appointment_id': appointmentId,
          'accept': accept,
          'reject_reason': rejectReason,
          'reject_text': rejectText,
          'proposed_dt': proposedDt?.toIso8601String(),
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return false;'''
)

content = content.replace(
'''      await SupabaseService().client.rpc(
        DbFunctions.requesterCounterAppointment,
        params: {
          'p_user_uid':        userUid,
          'p_appointment_id':  appointmentId,
          'p_accept':          accept,
          'p_proposed_dt':     proposedDt?.toIso8601String(),
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'requester_counter',
          'user_uid': userUid,
          'appointment_id': appointmentId,
          'accept': accept,
          'proposed_dt': proposedDt?.toIso8601String(),
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return false;'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
