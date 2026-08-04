#!/usr/bin/env python3
"""
سكريبت الترحيل التلقائي لنظام الثيم الموحد
Automated Theme Migration Script

Usage:
  python scripts/migrate_theme.py <file.dart>          # ملف واحد
  python scripts/migrate_theme.py lib/screens/         # مجلد كامل
  python scripts/migrate_theme.py --dry-run <path>     # عرض التغييرات بدون تطبيق
"""

import re
import os
import sys
import glob

# ═══════════════════════════════════════════════════════════════
# قواعد التحويل - Migration Rules
# ═══════════════════════════════════════════════════════════════

FONT_SIZE_RULES = {
    r'fontSize:\s*10\b': 'fontSize: AppTheme.fontSizeXS',
    r'fontSize:\s*11\b': 'fontSize: AppTheme.fontSizeCaption',
    r'fontSize:\s*12\b': 'fontSize: AppTheme.fontSizeSmall',
    r'fontSize:\s*13\b': 'fontSize: AppTheme.fontSizeBody',
    r'fontSize:\s*14\b': 'fontSize: AppTheme.fontSizeMedium',
    r'fontSize:\s*16\b': 'fontSize: AppTheme.fontSizeSubtitle',
    r'fontSize:\s*18\b': 'fontSize: AppTheme.fontSizeTitle',
    r'fontSize:\s*20\b': 'fontSize: AppTheme.fontSizeHeadline',
    r'fontSize:\s*24\b': 'fontSize: AppTheme.fontSizeLarge',
    r'fontSize:\s*28\b': 'fontSize: AppTheme.fontSizeXL',
    r'fontSize:\s*32\b': 'fontSize: AppTheme.fontSizeDisplay',
}

SPACING_RULES = {
    # SizedBox height only
    r'SizedBox\(height:\s*2\)': 'AppTheme.gapHeightXXS',
    r'SizedBox\(height:\s*4\)': 'AppTheme.gapHeightXS',
    r'SizedBox\(height:\s*8\)': 'AppTheme.gapHeightSmall',
    r'SizedBox\(height:\s*10\)': 'AppTheme.gapHeightSmall',  # تقريب
    r'SizedBox\(height:\s*12\)': 'AppTheme.gapHeightMedium',
    r'SizedBox\(height:\s*14\)': 'AppTheme.gapHeightMedium',  # تقريب
    r'SizedBox\(height:\s*16\)': 'AppTheme.gapHeightLarge',
    r'SizedBox\(height:\s*20\)': 'AppTheme.gapHeightXL',
    r'SizedBox\(height:\s*24\)': 'AppTheme.gapHeightXXL',
    r'SizedBox\(height:\s*32\)': 'const SizedBox(height: AppTheme.spacingXXXL)',
    # SizedBox width only
    r'SizedBox\(width:\s*2\)': 'AppTheme.gapWidthXXS',
    r'SizedBox\(width:\s*4\)': 'AppTheme.gapWidthXS',
    r'SizedBox\(width:\s*8\)': 'AppTheme.gapWidthSmall',
    r'SizedBox\(width:\s*10\)': 'AppTheme.gapWidthSmall',
    r'SizedBox\(width:\s*12\)': 'AppTheme.gapWidthMedium',
    r'SizedBox\(width:\s*14\)': 'AppTheme.gapWidthMedium',
    r'SizedBox\(width:\s*16\)': 'AppTheme.gapWidthLarge',
    r'SizedBox\(width:\s*20\)': 'AppTheme.gapWidthXL',
    r'SizedBox\(width:\s*24\)': 'AppTheme.gapWidthXXL',
}

PADDING_RULES = {
    r'const EdgeInsets\.all\(4\)': 'AppTheme.paddingAllSmall',  # تقريب
    r'const EdgeInsets\.all\(8\)': 'AppTheme.paddingAllSmall',
    r'const EdgeInsets\.all\(10\)': 'AppTheme.paddingAllMedium',  # تقريب
    r'const EdgeInsets\.all\(12\)': 'AppTheme.paddingAllMedium',
    r'const EdgeInsets\.all\(14\)': 'AppTheme.paddingAllLarge',  # تقريب
    r'const EdgeInsets\.all\(16\)': 'AppTheme.paddingAllLarge',
    r'const EdgeInsets\.all\(20\)': 'AppTheme.paddingAllXL',
    r'const EdgeInsets\.all\(24\)': 'const EdgeInsets.all(AppTheme.paddingXXL)',
    r'EdgeInsets\.all\(4\)': 'AppTheme.paddingAllSmall',
    r'EdgeInsets\.all\(8\)': 'AppTheme.paddingAllSmall',
    r'EdgeInsets\.all\(10\)': 'AppTheme.paddingAllMedium',
    r'EdgeInsets\.all\(12\)': 'AppTheme.paddingAllMedium',
    r'EdgeInsets\.all\(14\)': 'AppTheme.paddingAllLarge',
    r'EdgeInsets\.all\(16\)': 'AppTheme.paddingAllLarge',
    r'EdgeInsets\.all\(20\)': 'AppTheme.paddingAllXL',
}

BORDER_RADIUS_RULES = {
    r'BorderRadius\.circular\(4\)': 'AppTheme.borderRadiusXS',
    r'BorderRadius\.circular\(8\)': 'AppTheme.borderRadiusSmall',
    r'BorderRadius\.circular\(10\)': 'AppTheme.borderRadiusMedium',  # تقريب
    r'BorderRadius\.circular\(12\)': 'AppTheme.borderRadiusMedium',
    r'BorderRadius\.circular\(14\)': 'AppTheme.borderRadiusLarge',  # تقريب
    r'BorderRadius\.circular\(16\)': 'AppTheme.borderRadiusLarge',
    r'BorderRadius\.circular\(20\)': 'AppTheme.borderRadiusXL',
    r'BorderRadius\.circular\(24\)': 'AppTheme.borderRadiusXXL',
    r'BorderRadius\.circular\(999\)': 'AppTheme.borderRadiusRound',
}

COLOR_RULES = {
    r'Colors\.green(?!\w)': 'AppTheme.successGreen',
    r'Colors\.red(?!\w)': 'AppTheme.errorRed',
    r'Colors\.orange(?!\w)': 'AppTheme.warningOrange',
    r'Colors\.blue(?!\w)': 'AppTheme.infoBlue',
    r'Colors\.yellow(?!\w)': 'AppTheme.pendingYellow',
    r'Colors\.grey(?!\w)': 'AppTheme.textGrey',
    r'Color\(0xFFD4AF37\)': 'AppTheme.primaryGold',
    r'Color\(0xFF121212\)': 'AppTheme.deepBlack',
    r'Color\(0xFFFFFBF2\)': 'AppTheme.scaffoldBackground',
    r'Color\(0xFFF9E4B7\)': 'AppTheme.lightGold',
    r'Color\(0xFFB3261E\)': 'AppTheme.errorRed',
    r'Color\(0xFF17130A\)': 'AppTheme.textWhite',
    r'Color\(0xFF6F6656\)': 'AppTheme.textGrey',
}

ALL_RULES = {}
ALL_RULES.update(FONT_SIZE_RULES)
ALL_RULES.update(SPACING_RULES)
ALL_RULES.update(PADDING_RULES)
ALL_RULES.update(BORDER_RADIUS_RULES)
ALL_RULES.update(COLOR_RULES)


def count_changes(content, rules):
    """يعدد عدد التغييرات المحتملة"""
    count = 0
    for pattern in rules:
        matches = re.findall(pattern, content)
        count += len(matches)
    return count


def migrate_content(content, rules):
    """يطبق قواعد التحويل على المحتوى"""
    changes = []
    for pattern, replacement in rules.items():
        matches = re.findall(pattern, content)
        if matches:
            content = re.sub(pattern, replacement, content)
            changes.append(f"  {pattern} → {replacement} ({len(matches)}x)")
    
    # إزالة const قبل AppTheme لأنها ليست top-level constants
    content = re.sub(r'const AppTheme\.', 'AppTheme.', content)
    
    return content, changes


def migrate_file(filepath, dry_run=False):
    """يحول ملف واحد"""
    if not filepath.endswith('.dart'):
        return 0
    
    # تجاهل ملف الثيم نفسه
    if 'app_theme.dart' in filepath:
        return 0
    
    with open(filepath, 'r', encoding='utf-8') as f:
        original_content = f.read()
    
    potential_changes = count_changes(original_content, ALL_RULES)
    if potential_changes == 0:
        return 0
    
    new_content, changes = migrate_content(original_content, ALL_RULES)
    
    if not changes:
        return 0
    
    # إضافة import إذا لم يكن موجوداً
    if 'AppTheme.' in new_content and 'import' in new_content and 'app_theme.dart' not in new_content:
        # حساب المسار النسبي بناءً على موقع الملف
        rel_path = os.path.relpath(filepath, os.path.join(os.path.dirname(filepath), '..'))
        depth = filepath.count(os.sep) - filepath.count(os.sep)
        # حساب العمق من lib/
        lib_index = filepath.find('lib/')
        if lib_index >= 0:
            after_lib = filepath[lib_index + 4:]  # بعد 'lib/'
            dir_depth = after_lib.count('/')
            prefix = '../' * dir_depth
        else:
            prefix = '../../'
        
        import_path = f"{prefix}core/theme/app_theme.dart"
        
        # إيجاد آخر import وإضافة import الثيم بعده
        import_pattern = r"(import\s+'[^']*';\n)"
        last_import = None
        for match in re.finditer(import_pattern, new_content):
            last_import = match
        
        if last_import:
            insert_pos = last_import.end()
            new_content = (
                new_content[:insert_pos] +
                f"import '{import_path}';\n" +
                new_content[insert_pos:]
            )
            changes.append(f"  + import {import_path}")
    
    if dry_run:
        print(f"\n📄 {filepath}")
        print(f"   تغييرات محتملة: {potential_changes}")
        for change in changes:
            print(change)
    else:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"✅ {filepath}")
        for change in changes:
            print(f"   {change}")
    
    return len(changes)


def process_path(path, dry_run=False):
    """يعالج مسار (ملف أو مجلد)"""
    total_changes = 0
    
    if os.path.isfile(path):
        total_changes += migrate_file(path, dry_run)
    elif os.path.isdir(path):
        for root, dirs, files in os.walk(path):
            # تجاهل مجلدات معينة
            dirs[:] = [d for d in dirs if d not in ['build', '.dart_tool', 'test']]
            for filename in sorted(files):
                if filename.endswith('.dart'):
                    filepath = os.path.join(root, filename)
                    total_changes += migrate_file(filepath, dry_run)
    else:
        print(f"❌ المسار غير موجود: {path}")
        return 0
    
    return total_changes


def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python scripts/migrate_theme.py <file.dart>")
        print("  python scripts/migrate_theme.py lib/screens/")
        print("  python scripts/migrate_theme.py --dry-run lib/screens/")
        sys.exit(1)
    
    dry_run = False
    args = sys.argv[1:]
    
    if args[0] == '--dry-run':
        dry_run = True
        args = args[1:]
    
    if dry_run:
        print("🔍 وضع المعاينة (Dry Run) - لن يتم تعديل الملفات")
    else:
        print("🚀 بدء الترحيل التلقائي")
    
    print("=" * 60)
    
    total_changes = 0
    for path in args:
        total_changes += process_path(path, dry_run)
    
    print("=" * 60)
    if dry_run:
        print(f"📊 إجمالي التغييرات المحتملة: {total_changes}")
    else:
        print(f"✅ تم تطبيق {total_changes} مجموعة تغييرات")
    
    if total_changes > 0 and not dry_run:
        print("\n⚠️  تأكد من مراجعة التغييرات قبل الـ commit!")
        print("   git diff --stat")


if __name__ == '__main__':
    main()
