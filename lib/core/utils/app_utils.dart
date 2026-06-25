import 'package:intl/intl.dart';

/// أدوات مساعدة للتنسيق والتحقق
class AppUtils {
  static String formatPrice(num price, {int currency = 0}) {
    final formatter = NumberFormat('#,###');
    final symbol = currency == 0 ? '\$' : 'ل.س';
    return '${formatter.format(price)} $symbol';
  }

  static String formatTimestamp(dynamic ts, {String pattern = 'yyyy/MM/dd'}) {
    if (ts == null) return '';
    DateTime date;
    if (ts is DateTime) {
      date = ts;
    } else if (ts is String) {
      try {
        date = DateTime.parse(ts);
      } catch (_) {
        return '';
      }
    } else {
      return '';
    }
    // محاولة العربية، وعند الفشل نستخدم الافتراضي
    try {
      return DateFormat(pattern, 'ar').format(date);
    } catch (_) {
      return DateFormat(pattern).format(date);
    }
  }

  static String offerStatusText(int status) {
    switch (status) {
      case 0: return 'مسودة';
      case 1: return 'قيد المراجعة';
      case 2: return 'منشور';
      case 3: return 'مرفوض';
      case 4: return 'منتهي';
      case 5: return 'محجوز';
      case 6: return 'مكتمل';
      default: return 'غير معروف';
    }
  }

  static String offerTypeText(int type) => type == 0 ? 'عقار' : 'سيارة';
  static String transactionText(int type) => type == 0 ? 'بيع' : 'إيجار';

  static String deedTypeText(int type, int offerType) {
    if (offerType == 0) { // عقار
      switch (type) {
        case 0: return 'طابو أخضر';
        case 1: return 'حصة سهمية-حكم محكمة';
        case 2: return 'حصة سهمية-كاتب بالعدل';
        case 3: return 'مستملك';
        case 4: return 'تسلسل عقود';
        case 5: return 'جمعيات سكنية';
        case 6: return 'نمرة قديمة';
        case 7: return 'نمرة جديدة';
        case 8: return 'وارد';
        default: return 'غير محدد';
      }
    } else { // سيارة
      switch (type) {
        case 0: return 'مواصلات نظامي';
        case 1: return 'حكم محكمة';
        case 2: return 'وارد مع تسلسل ملكية حصراً';
        default: return 'غير محدد';
      }
    }
  }

  static bool isValidPhone(String phone) {
    return RegExp(r'^09\d{8}$').hasMatch(phone);
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
