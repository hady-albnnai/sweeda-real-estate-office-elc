/// نموذج مهمة المنفذ — يُستخدم لعرض مهام المنفذ الميداني
class ExecutorTaskModel {
  final String appointmentId;
  final String offId;
  final String offerNumber;
  final String displayTitle;
  final String taskType; // property / car
  final String clientName;
  final String clientPhone;
  final DateTime appointmentDate;
  final Map<String, dynamic> location;
  final String description;
  final double price;
  final int currency;
  final String? outcome; // accept / reject / postpone / null
  final DateTime? completionDate;
  final String? rejectionReason;
  final int sts;

  ExecutorTaskModel({
    required this.appointmentId,
    required this.offId,
    this.offerNumber = '',
    this.displayTitle = '',
    this.taskType = 'property',
    this.clientName = '',
    this.clientPhone = '',
    required this.appointmentDate,
    this.location = const {},
    this.description = '',
    this.price = 0,
    this.currency = 0,
    this.outcome,
    this.completionDate,
    this.rejectionReason,
    this.sts = 0,
  });

  factory ExecutorTaskModel.fromMap(Map<String, dynamic> d) {
    return ExecutorTaskModel(
      appointmentId: d['appointment_id']?.toString() ?? '',
      offId: d['off_id']?.toString() ?? '',
      offerNumber: d['offer_number'] ?? '',
      displayTitle: d['display_title'] ?? '',
      taskType: d['task_type'] ?? 'property',
      clientName: d['client_name'] ?? '',
      clientPhone: d['client_phone'] ?? '',
      appointmentDate: DateTime.parse(
          d['appointment_date'] ?? DateTime.now().toIso8601String()),
      location: d['location'] is Map
          ? Map<String, dynamic>.from(d['location'])
          : {},
      description: d['description'] ?? '',
      price: (d['price'] ?? 0).toDouble(),
      currency: d['offer_cur'] ?? 0,
      outcome: d['outcome'],
      completionDate: d['completion_date'] != null
          ? DateTime.parse(d['completion_date'])
          : null,
      rejectionReason: d['rejection_reason'],
      sts: d['sts'] ?? 0,
    );
  }

  bool get isToday => appointmentDate.toLocal().day == DateTime.now().day &&
      appointmentDate.toLocal().month == DateTime.now().month &&
      appointmentDate.toLocal().year == DateTime.now().year;

  bool get isCompleted => outcome != null;
  bool get isAccepted => outcome == 'accept';
  bool get isRejected => outcome == 'reject';

  String get locationText {
    final d = location['d'];
    if (d != null && d.toString().isNotEmpty) return d.toString();
    return '';
  }

  String get taskTypeLabel => taskType == 'property' ? 'عقار' : 'سيارة';

  String get outcomeLabel {
    switch (outcome) {
      case 'accept': return 'مقبول';
      case 'reject': return 'مرفوض';
      case 'postpone': return 'مؤجل';
      default: return 'بانتظار التنفيذ';
    }
  }
}
