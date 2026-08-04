#!/usr/bin/env python3
"""
Fix borderRadius property to use BorderRadius objects instead of double values
"""
import re
import os

FIXES = {
    r'borderRadius:\s*AppTheme\.borderRadiusXS\b': 'borderRadius: AppTheme.radiusXS',
    r'borderRadius:\s*AppTheme\.borderRadiusSmall\b': 'borderRadius: AppTheme.radiusSmall',
    r'borderRadius:\s*AppTheme\.borderRadiusMedium\b': 'borderRadius: AppTheme.radiusMedium',
    r'borderRadius:\s*AppTheme\.borderRadiusLarge\b': 'borderRadius: AppTheme.radiusLarge',
    r'borderRadius:\s*AppTheme\.borderRadiusXL\b': 'borderRadius: AppTheme.radiusXL',
    r'borderRadius:\s*AppTheme\.borderRadiusXXL\b': 'borderRadius: AppTheme.radiusXXL',
    r'borderRadius:\s*AppTheme\.borderRadiusRound\b': 'borderRadius: AppTheme.radiusRound',
}

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    for pattern, replacement in FIXES.items():
        content = re.sub(pattern, replacement, content)
    
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Fixed: {filepath}")
        return True
    return False

def main():
    count = 0
    for root, dirs, files in os.walk('lib'):
        for filename in files:
            if filename.endswith('.dart'):
                filepath = os.path.join(root, filename)
                if fix_file(filepath):
                    count += 1
    print(f"\n✅ Fixed {count} files")

if __name__ == '__main__':
    main()
