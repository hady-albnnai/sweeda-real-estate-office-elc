import os

def ensure_import(file_path, import_statement):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if import_statement not in content:
        # Insert after the first import or at the top if no imports
        lines = content.split('\n')
        insert_idx = 0
        for i, line in enumerate(lines):
            if line.startswith('import '):
                insert_idx = i + 1
        
        lines.insert(insert_idx, import_statement)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))


# 1. fraud_suspects_screen.dart
file1 = 'lib/screens/admin/fraud_suspects_screen.dart'
ensure_import(file1, "import '../../services/auth_service.dart';")

# 2. staff_admin_service.dart
file2 = 'lib/services/admin/staff_admin_service.dart'
ensure_import(file2, "import '../auth_service.dart';")

# 3. stats_admin_service.dart
file3 = 'lib/services/admin/stats_admin_service.dart'
ensure_import(file3, "import '../auth_service.dart';")

