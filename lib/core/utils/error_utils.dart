/// أدوات موحّدة لتطبيع أخطاء السيرفر والـ Edge Functions بدون طباعة في الكود النهائي.
class ErrorUtils {
  const ErrorUtils._();

  static String normalize(Object? error) {
    if (error == null) return 'UNKNOWN_ERROR';

    final raw = error.toString();
    if (raw.isEmpty) return 'UNKNOWN_ERROR';

    final knownCodes = <String>[
      'ADMIN_SESSION_REQUIRED',
      'INVALID_ADMIN_SESSION',
      'SESSION_TOKEN_REQUIRED',
      'INVALID_SESSION',
      'UNAUTHORIZED',
      'NOT_AUTHORIZED',
      'AUTH_MISMATCH',
      'USER_NOT_FOUND',
      'USER_NOT_FOUND_OR_INACTIVE',
      'USER_INACTIVE',
      'CANNOT_MODIFY_MANAGER',
      'CANNOT_DELETE_MANAGER',
      'ONLY_MANAGER_CAN_MANAGE_DEPUTIES',
      'ONLY_MANAGER_CAN_CREATE_DEPUTY',
      'INVALID_ROLE',
      'INVALID_STATUS',
      'PHONE_EXISTS',
      'PHONE_REQUIRED',
      'USERNAME_TAKEN',
      'USERNAME_LENGTH',
      'USERNAME_INVALID_CHARS',
      'PASSWORD_TOO_SHORT',
      'WRONG_PASSWORD',
      'NO_PASSWORD_SET',
      'USER_BANNED',
      'USER_FROZEN',
      'EMPTY_RESPONSE',
      'METHOD_NOT_ALLOWED',
    ];

    for (final code in knownCodes) {
      if (raw.contains(code)) return code;
    }

    return raw.length > 220 ? raw.substring(0, 220) : raw;
  }

  static String arabicMessage(Object? error) {
    final code = normalize(error);
    switch (code) {
      case 'ADMIN_SESSION_REQUIRED':
      case 'INVALID_ADMIN_SESSION':
      case 'SESSION_TOKEN_REQUIRED':
      case 'INVALID_SESSION':
        return 'انتهت جلسة الإدارة أو أنها غير صالحة. سجّل الدخول مجدداً.';
      case 'UNAUTHORIZED':
      case 'NOT_AUTHORIZED':
        return 'ليست لديك صلاحية لتنفيذ هذه العملية.';
      case 'AUTH_MISMATCH':
        return 'جلسة المستخدم لا تطابق منفذ العملية.';
      case 'USER_NOT_FOUND':
      case 'USER_NOT_FOUND_OR_INACTIVE':
        return 'المستخدم غير موجود أو غير نشط.';
      case 'USER_INACTIVE':
        return 'الحساب غير نشط.';
      case 'CANNOT_MODIFY_MANAGER':
      case 'CANNOT_DELETE_MANAGER':
        return 'لا يمكن تعديل أو حذف المدير الرئيسي.';
      case 'ONLY_MANAGER_CAN_MANAGE_DEPUTIES':
      case 'ONLY_MANAGER_CAN_CREATE_DEPUTY':
        return 'هذه العملية محصورة بالمدير الرئيسي.';
      case 'INVALID_ROLE':
        return 'الدور المحدد غير صالح.';
      case 'INVALID_STATUS':
        return 'حالة الحساب غير صالحة.';
      case 'PHONE_EXISTS':
        return 'رقم الهاتف مستخدم مسبقاً.';
      case 'PHONE_REQUIRED':
        return 'رقم الهاتف مطلوب.';
      case 'USERNAME_TAKEN':
        return 'اسم المستخدم محجوز.';
      case 'USERNAME_LENGTH':
        return 'اسم المستخدم يجب أن يكون بين 3 و 30 حرفاً.';
      case 'USERNAME_INVALID_CHARS':
        return 'اسم المستخدم يحتوي أحرفاً غير مسموحة.';
      case 'PASSWORD_TOO_SHORT':
        return 'كلمة المرور قصيرة جداً.';
      case 'WRONG_PASSWORD':
        return 'كلمة المرور غير صحيحة.';
      case 'NO_PASSWORD_SET':
        return 'لم يتم تعيين كلمة مرور لهذا الحساب.';
      case 'USER_BANNED':
        return 'الحساب محظور.';
      case 'USER_FROZEN':
        return 'الحساب مجمّد مؤقتاً.';
      case 'EMPTY_RESPONSE':
        return 'لم يصل رد صالح من السيرفر.';
      case 'METHOD_NOT_ALLOWED':
        return 'طريقة الطلب غير مسموحة.';
      default:
        return code;
    }
  }
}
