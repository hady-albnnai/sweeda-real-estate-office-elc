import os

file_path = 'lib/screens/user/profile_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final token = await context.read<AuthProvider>().getStaffSessionToken();''',
'''      final token = await AuthService().getStaffSessionToken();'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
