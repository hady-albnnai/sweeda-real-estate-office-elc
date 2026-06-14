/// نتيجة موحدة للعمليات الحساسة تدريجياً.
/// الهدف منها تقليل الاعتماد على bool فقط ومنع إخفاء سبب الفشل.
class AppResult<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String? message;

  const AppResult._({
    required this.success,
    this.data,
    this.errorCode,
    this.message,
  });

  const AppResult.ok([T? data]) : this._(success: true, data: data);

  const AppResult.fail(String errorCode, {String? message})
      : this._(success: false, errorCode: errorCode, message: message);
}
