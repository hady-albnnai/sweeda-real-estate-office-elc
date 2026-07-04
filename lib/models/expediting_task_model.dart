class ChecklistItemModel {
  final String key;
  final String title;
  final int status; // 0: مطلوب، 1: قيد الاستخراج، 2: تم الاستخراج والرفع، 3: عائق قانوني
  final String inputValue; // حقل الكتابة التفاعلي مثل رقم السيارة أو العقار
  final String attachmentUrl; // رابط صورة السند المرفوعة
  final String notes; // ملاحظات المعقب الميدانية

  const ChecklistItemModel({
    required this.key,
    required this.title,
    this.status = 0,
    this.inputValue = '',
    this.attachmentUrl = '',
    this.notes = '',
  });

  factory ChecklistItemModel.fromMap(Map<String, dynamic> map) {
    return ChecklistItemModel(
      key: (map['key'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      status: int.tryParse(map['status']?.toString() ?? '0') ?? 0,
      inputValue: (map['input_value'] ?? '').toString(),
      attachmentUrl: (map['attachment_url'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'title': title,
      'status': status,
      'input_value': inputValue,
      'attachment_url': attachmentUrl,
      'notes': notes,
    };
  }
}

class ExpeditingTaskModel {
  final String id;
  final String lawyerUid;
  final String expediterUid;
  final String? offerId;
  final int itemType; // 0: عقار، 1: سيارة
  final String targetPropertyNum;
  final String targetZone;
  final List<ChecklistItemModel> checklist;
  final int status; // 0: انتظار، 1: استخراج، 2: مكتملة من المعقب، 3: معتمدة من المحامي
  final String lawyerNotes;
  final String expediterNotes;
  final DateTime? createdAt;

  const ExpeditingTaskModel({
    required this.id,
    required this.lawyerUid,
    required this.expediterUid,
    this.offerId,
    required this.itemType,
    this.targetPropertyNum = '',
    this.targetZone = '',
    required this.checklist,
    this.status = 0,
    this.lawyerNotes = '',
    this.expediterNotes = '',
    this.createdAt,
  });

  factory ExpeditingTaskModel.fromMap(Map<String, dynamic> map) {
    List<ChecklistItemModel> parsedChecklist = [];
    final rawList = map['checklist'];
    if (rawList is List) {
      parsedChecklist = rawList
          .map((e) => e is Map ? ChecklistItemModel.fromMap(Map<String, dynamic>.from(e)) : null)
          .whereType<ChecklistItemModel>()
          .toList();
    }

    return ExpeditingTaskModel(
      id: (map['id'] ?? '').toString(),
      lawyerUid: (map['lawyer_uid'] ?? '').toString(),
      expediterUid: (map['expediter_uid'] ?? '').toString(),
      offerId: map['offer_id']?.toString(),
      itemType: int.tryParse(map['item_type']?.toString() ?? '0') ?? 0,
      targetPropertyNum: (map['target_property_num'] ?? '').toString(),
      targetZone: (map['target_zone'] ?? '').toString(),
      checklist: parsedChecklist,
      status: int.tryParse(map['status']?.toString() ?? '0') ?? 0,
      lawyerNotes: (map['lawyer_notes'] ?? '').toString(),
      expediterNotes: (map['expediter_notes'] ?? '').toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lawyer_uid': lawyerUid,
      'expediter_uid': expediterUid,
      'offer_id': offerId,
      'item_type': itemType,
      'target_property_num': targetPropertyNum,
      'target_zone': targetZone,
      'checklist': checklist.map((e) => e.toMap()).toList(),
      'status': status,
      'lawyer_notes': lawyerNotes,
      'expediter_notes': expediterNotes,
    };
  }
}
