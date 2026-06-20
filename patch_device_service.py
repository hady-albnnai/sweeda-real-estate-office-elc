import os

file_path = 'lib/core/services/device_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      await _sb.client.rpc('register_device', params: {
        'p_device_id': deviceId,
        'p_ip_hint': null,
      });''',
'''      await _sb.client.functions.invoke(
        'user-account',
        body: {
          'action': 'register_device',
          'device_id': deviceId,
          'ip_hint': null,
        },
      );'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
