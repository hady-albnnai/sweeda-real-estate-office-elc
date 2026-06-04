class ReportModel {
  final String id;
  final String repUid;
  final String tgtUid;
  final int tgtTp;
  final String tgtId;
  final int rsn;
  final String det;
  final int sts;
  final int act;
  final int actDur;
  final String note;
  final String? actBy;
  final DateTime tsCrt;

  ReportModel({
    required this.id, required this.repUid, required this.tgtUid,
    required this.tgtTp, required this.tgtId, required this.rsn,
    this.det = '', this.sts = 0, this.act = 0, this.actDur = 0,
    this.note = '', this.actBy, required this.tsCrt,
  });

  factory ReportModel.fromSupabase(Map<String, dynamic> data, String id) {
    return ReportModel(
      id: id, repUid: data['rep_uid'] ?? '', tgtUid: data['tgt_uid'] ?? '',
      tgtTp: data['tgt_tp'] ?? 0, tgtId: data['tgt_id'] ?? '',
      rsn: data['rsn'] ?? 0, det: data['det'] ?? '',
      sts: data['sts'] ?? 0, act: data['act'] ?? 0,
      actDur: data['act_dur'] ?? 0, note: data['note'] ?? '',
      actBy: data['act_by'], tsCrt: DateTime.parse(data['ts_crt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rep_uid': repUid, 'tgt_uid': tgtUid, 'tgt_tp': tgtTp,
      'tgt_id': tgtId, 'rsn': rsn, 'det': det, 'sts': sts,
      'act': act, 'act_dur': actDur, 'note': note,
      'act_by': actBy, 'ts_crt': tsCrt.toIso8601String(),
    };
  }
}
