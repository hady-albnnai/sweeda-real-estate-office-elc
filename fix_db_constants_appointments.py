import os

file_path = 'lib/core/constants/db_constants.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Just comment out the unneeded RPC constants to be safe
content = content.replace(
    "static const String ownerRespondAppointment     = 'owner_respond_appointment';",
    "// static const String ownerRespondAppointment     = 'owner_respond_appointment';"
)

content = content.replace(
    "static const String requesterCounterAppointment = 'requester_counter_appointment';",
    "// static const String requesterCounterAppointment = 'requester_counter_appointment';"
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
