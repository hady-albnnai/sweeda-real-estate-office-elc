class NotificationModel {
  final String id;
  final String uid;
  final int tp;
  final String ttl;
  final String bdy;
  final String act;
  final String refId;
  final int iRd;
  final int iDel;
  final DateTime tsCrt;

  NotificationModel({
    required this.id, required this.uid, required this.tp,
    required this.ttl, required this.bdy,
    this.act = '', this.refId = '',
    this.iRd = 0, this.iDel = 0, required this.tsCrt,
  });

  factory NotificationModel.fromSupabase(Map<String, dynamic> data, String id) {
    return NotificationModel(
      id: id, uid: data['uid'] ?? '', tp: data['tp'] ?? 0,
      ttl: data['ttl'] ?? '', bdy: data['bdy'] ?? '',
      act: data['act'] ?? '', refId: data['ref_id'] ?? '',
      iRd: data['i_rd'] ?? 0, iDel: data['i_del'] ?? 0,
      tsCrt: DateTime.parse(data['ts_crt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid, 'tp': tp, 'ttl': ttl, 'bdy': bdy,
      'act': act, 'ref_id': refId,
      'i_rd': iRd, 'i_del': iDel,
      'ts_crt': tsCrt.toIso8601String(),
    };
  }

  bool get isRead => iRd == 1;
}
