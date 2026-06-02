import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// أدوات مساعدة للتنسيق والتحقق
class AppUtils {
  /// تنسيق السعر
  static String formatPrice(num price, {int currency = 0}) {
    final formatter = NumberFormat('#,###');
    final symbol = currency == 0 ? '\$' : 'ل.س';
    return '${formatter.format(price)} $symbol';
  }

  /// تحويل timestamp إلى نص
  static String formatTimestamp(dynamic ts, {String pattern = 'yyyy/MM/dd'}) {
    if (ts == null) return '';
    final date = (ts as Timestamp).toDate();
    return DateFormat(pattern, 'ar').format(date);
  }

  /// تحويل رقم الحالة إلى نص
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

  /// تحويل رقم نوع العرض إلى نص
  static String offerTypeText(int type) {
    return type == 0 ? 'عقار' : 'سيارة';
  }

  /// تحويل رقم المعاملة إلى نص
  static String transactionText(int type) {
    return type == 0 ? 'بيع' : 'إيجار';
  }

  /// التحقق من رقم الهاتف
  static bool isValidPhone(String phone) {
    final regex = RegExp(r'^09\d{8}$');
    return regex.hasMatch(phone);
  }

  /// تقطيع النص الطويل
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
