import os

file_path = 'lib/services/auth_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final data = result is Map ? Map<String, dynamic>.from(result) : null;''',
'''      final data = result.data is Map ? Map<String, dynamic>.from(result.data) : null;'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

