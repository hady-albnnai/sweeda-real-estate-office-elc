import os
import re

file_path = 'lib/services/admin/appointments_admin_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the weird \n literal that was mistakenly injected
content = content.replace("\\nimport '../auth_service.dart';", "import '../auth_service.dart';")

# Make sure we have the import correctly at the top
if "import '../auth_service.dart';" not in content:
    lines = content.split('\n')
    idx = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            idx = i + 1
    lines.insert(idx, "import '../auth_service.dart';")
    content = '\n'.join(lines)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

