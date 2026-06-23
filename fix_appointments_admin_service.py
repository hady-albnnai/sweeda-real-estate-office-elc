import os

file_path = 'lib/services/admin/appointments_admin_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# إزالة الاستيراد الخاطئ من آخر الملف
content = content.replace("\nimport '../auth_service.dart';", "")

# إضافة الاستيراد في المكان الصحيح (في أعلى الملف)
if "import '../../services/auth_service.dart';" not in content:
    lines = content.split('\n')
    idx = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            idx = i + 1
    lines.insert(idx, "import '../../services/auth_service.dart';")
    content = '\n'.join(lines)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

