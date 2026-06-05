#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
# verify_functions_docs.sh
# سكريبت تحقق: يقارن دوال SQL الفعلية بـ FUNCTIONS_REFERENCE.md
# ════════════════════════════════════════════════════════════════════════════
# الاستخدام:
#   bash scripts/verify_functions_docs.sh
#
# يخرج بـ:
#   exit 0  → كل الدوال موثّقة بشكل صحيح
#   exit 1  → في دوال ناقصة (يطبع القائمة)
# ════════════════════════════════════════════════════════════════════════════

set -e

cd "$(dirname "$0")/.."

REF_FILE="supabase/FUNCTIONS_REFERENCE.md"

if [ ! -f "$REF_FILE" ]; then
  echo "❌ $REF_FILE غير موجود"
  exit 1
fi

echo "🔍 جاري التحقق من توثيق دوال SQL..."
echo ""

# استخراج كل أسماء الدوال من ملفات SQL
SQL_FUNCTIONS=$(grep -hE "^CREATE OR REPLACE FUNCTION|^CREATE FUNCTION" \
  supabase/setup.sql supabase/migrations/*.sql 2>/dev/null \
  | sed -E 's/CREATE OR REPLACE FUNCTION |CREATE FUNCTION //' \
  | sed 's/(.*//' \
  | sort -u)

TOTAL=$(echo "$SQL_FUNCTIONS" | wc -l)
echo "📊 عدد الدوال في SQL: $TOTAL"
echo ""

MISSING=()
MISSING_SECURITY=()

while IFS= read -r fn; do
  # فحص: في الجدول الرئيسي (يحتوي على " | `funcname` |" أو "| `funcname` 🆕")
  in_main=$(grep -cE "\| .*\`$fn\`( | 🆕)" "$REF_FILE" || true)

  # فحص: في جدول ملخص الأمان (يبدأ بـ "| `funcname`")
  in_security=$(grep -cE "^\| \`$fn\`( |🆕)" "$REF_FILE" || true)

  if [ "$in_main" -eq 0 ]; then
    MISSING+=("$fn")
  elif [ "$in_security" -eq 0 ]; then
    MISSING_SECURITY+=("$fn")
  fi
done <<< "$SQL_FUNCTIONS"

EXIT_CODE=0

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "❌ الدوال التالية غير مذكورة في الجدول الرئيسي:"
  for fn in "${MISSING[@]}"; do
    echo "   - $fn"
  done
  echo ""
  EXIT_CODE=1
fi

if [ ${#MISSING_SECURITY[@]} -gt 0 ]; then
  echo "⚠️  الدوال التالية مذكورة لكن غير موجودة في جدول الأمان:"
  for fn in "${MISSING_SECURITY[@]}"; do
    echo "   - $fn"
  done
  echo ""
  EXIT_CODE=1
fi

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ ممتاز! كل الدوال الـ$TOTAL موثّقة بشكل كامل (جدول رئيسي + جدول أمان)"
else
  echo "💡 الإصلاح: حدّث $REF_FILE بإضافة الدوال الناقصة"
fi

exit $EXIT_CODE
