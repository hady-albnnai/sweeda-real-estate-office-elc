class RequestModel {
  final String id;
  final int typ;
  final int elm;
  final String clNm;
  final String clPh;
  final double prc;
  final int cur;
  final String notes;
  final Map<String, dynamic> specs;
  final String usrId;
  final int sts;
  final Map<String, dynamic> matches;
  final int iDel;
  final DateTime tsCrt;

  /// Lifecycle fields for customer requests.
  /// Status contract:
  /// 0=active, 1=in processing, 2=fulfilled, 3=cancelled, 4=expired.
  final DateTime? tsEnd;
  final DateTime? tsRen;
  final int rmndRen;
  final DateTime? closedAt;
  final String closedBy;
  final String closedByName;
  final int? closedByRole;
  final String closedReason;
  final String closedNote;
  final String closedOfferId;
  final String closedAppointmentId;
  final String closedCompletionRequestId;

  RequestModel({
    required this.id,
    required this.typ,
    required this.elm,
    required this.clNm,
    required this.clPh,
    this.prc = 0,
    this.cur = 1,
    this.notes = '',
    Map<String, dynamic>? specs,
    required this.usrId,
    this.sts = 0,
    Map<String, dynamic>? matches,
    this.iDel = 0,
    required this.tsCrt,
    this.tsEnd,
    this.tsRen,
    this.rmndRen = 0,
    this.closedAt,
    this.closedBy = '',
    this.closedByName = '',
    this.closedByRole,
    this.closedReason = '',
    this.closedNote = '',
    this.closedOfferId = '',
    this.closedAppointmentId = '',
    this.closedCompletionRequestId = '',
  })  : specs = specs ?? {},
        matches = matches ?? {};

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  factory RequestModel.fromSupabase(Map<String, dynamic> data, String id) {
    return RequestModel(
      id: id,
      typ: _toInt(data['typ']),
      elm: _toInt(data['elm']),
      clNm: data['cl_nm']?.toString() ?? '',
      clPh: data['cl_ph']?.toString() ?? '',
      prc: _toDouble(data['prc']),
      cur: _toInt(data['cur'], 1),
      notes: data['notes']?.toString() ?? '',
      specs: data['specs'] != null
          ? Map<String, dynamic>.from(data['specs'] as Map)
          : {},
      usrId: data['usr_id']?.toString() ?? '',
      sts: _toInt(data['sts']),
      matches: data['matches'] != null
          ? Map<String, dynamic>.from(data['matches'] as Map)
          : {},
      iDel: _toInt(data['i_del']),
      tsCrt: _parseDate(data['ts_crt']) ?? DateTime.now(),
      tsEnd: _parseDate(data['ts_end']),
      tsRen: _parseDate(data['ts_ren']),
      rmndRen: _toInt(data['rmnd_ren']),
      closedAt: _parseDate(data['closed_at']),
      closedBy: data['closed_by']?.toString() ?? '',
      closedByName: data['closed_by_name']?.toString() ?? '',
      closedByRole: data['closed_by_role'] == null
          ? null
          : _toInt(data['closed_by_role']),
      closedReason: data['closed_reason']?.toString() ?? '',
      closedNote: data['closed_note']?.toString() ?? '',
      closedOfferId: data['closed_offer_id']?.toString() ?? '',
      closedAppointmentId: data['closed_appointment_id']?.toString() ?? '',
      closedCompletionRequestId:
          data['closed_completion_request_id']?.toString() ?? '',
    );
  }

  bool get isActive => sts == 0;
  bool get isProcessing => sts == 1;
  bool get isFulfilled => sts == 2;
  bool get isCancelled => sts == 3;
  bool get isExpired => sts == 4;
  bool get isOpen => sts == 0 || sts == 1;
  bool get isClosed => sts >= 2;
  bool get canRenew => sts == 0 || sts == 1 || sts == 4;
  bool get canCancel => sts == 0 || sts == 1 || sts == 4;

  /// تاريخ انتهاء الطلب الفعلي
  DateTime get expirationDate {
    if (tsEnd != null) return tsEnd!;
    return tsCrt.add(const Duration(days: 30));
  }

  /// عدد الأيام المتبقية حتى انتهاء الطلب
  int get daysUntilExpiration {
    final diff = expirationDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  String get statusLabel {
    switch (sts) {
      case 0:
        return 'نشط';
      case 1:
        return 'قيد المعالجة';
      case 2:
        return 'تمت تلبيته';
      case 3:
        return 'ملغي';
      case 4:
        return 'منتهي الصلاحية';
      default:
        return 'غير معروف';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'typ': typ,
      'elm': elm,
      'cl_nm': clNm,
      'cl_ph': clPh,
      'prc': prc,
      'cur': cur,
      'notes': notes,
      'specs': specs,
      'usr_id': usrId,
      'sts': sts,
      'matches': matches,
      'i_del': iDel,
      'ts_crt': tsCrt.toIso8601String(),
    };
  }
}
