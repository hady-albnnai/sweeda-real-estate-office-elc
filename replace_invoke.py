import os
import re

root_dir = 'lib'
pattern = r'(\.client\.functions\.invoke)\s*\('
replacement = r'.invokeFunction('

for root, dirs, files in os.walk(root_dir):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            new_content = re.sub(pattern, replacement, content)
            
            if new_content != content:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f'Updated {path}')
