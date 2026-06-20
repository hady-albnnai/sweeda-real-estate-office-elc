import os

file_path = 'lib/screens/user/profile_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

import_statement = "import '../../services/auth_service.dart';"
if import_statement not in content:
    lines = content.split('\n')
    insert_idx = 0
    for i, line in enumerate(lines):
        if line.startswith('import '):
            insert_idx = i + 1
    
    lines.insert(insert_idx, import_statement)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
