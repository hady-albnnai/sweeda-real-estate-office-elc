/// نموذج طلب إتمام المعاملة
class CompletionRequestModel {
  final String id;
  final String appId;
  final String reqBy;
  final String notes;
  final String decision; // pending / approved / rejected
  final String? decidedBy;
  final String officeNotes;
  final DateTime tsCrt;
  final DateTime? tsDecided;

  CompletionRequestModel({
    required this.id,
    required this.appId,
    required this.reqBy,
    this.notes = '',
    this.decision = 'pending',
    this.decidedBy,
    this.officeNotes = '',
    required this.tsCrt,
    this.tsDecided,
  });

  factory CompletionRequestModel.fromMap(Map<String, dynamic> d) {
    return CompletionRequestModel(
      id: d['id'] ?? d['request_id'] ?? '',
      appId: d['app_id'] ?? d['appointment_id'] ?? '',
      reqBy: d['req_by'] ?? '',
      notes: d['notes'] ?? d['executor_notes'] ?? '',
      decision: d['decision'] ?? 'pending',
      decidedBy: d['decided_by'],
      officeNotes: d['office_notes'] ?? '',
      tsCrt: DateTime.parse(d['ts_crt'] ?? d['request_date'] ?? DateTime.now().toIso8601String()),
      tsDecided: d['ts_decided'] != null ? DateTime.parse(d['ts_decided']) : null,
    );
  }

  bool get isPending => decision == 'pending';
  bool get isApproved => decision == 'approved';
  bool get isRejected => decision == 'rejected';
}
