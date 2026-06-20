import os

file_path = 'lib/providers/auth_provider.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final uid = response['uid'] as String;
      final role = response['role'] as int;
      final sts = response['sts'] as int;''',
'''      final uid = resultData['uid'] as String;
      final role = resultData['role'] as int;
      final sts = resultData['sts'] as int;'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
