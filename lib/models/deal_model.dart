class DealModel {
  final String id;
  final String offId;
  final String appId;
  final String sellUid;
  final String buyUid;
  final String brkUid;
  final double finPrc;
  final int cur;
  final double comPct;
  final double comVal;
  final String? comNote;
  final Map<String, dynamic> form;
  final int sts;
  final String? cmplBy;
  final int iDel;
  final DateTime tsCrt;
  final DateTime? tsCmpl;

  DealModel({
    required this.id, required this.offId, this.appId = '',
    required this.sellUid, required this.buyUid,
    this.brkUid = '', this.finPrc = 0, this.cur = 1,
    this.comPct = 0, this.comVal = 0, this.comNote,
    Map<String, dynamic>? form, this.sts = 0, this.cmplBy,
    this.iDel = 0, required this.tsCrt, this.tsCmpl,
  }) : form = form ?? {};

  factory DealModel.fromSupabase(Map<String, dynamic> data, String id) {
    return DealModel(
      id: id, offId: data['off_id'] ?? '', appId: data['app_id'] ?? '',
      sellUid: data['sell_uid'] ?? '', buyUid: data['buy_uid'] ?? '',
      brkUid: data['brk_uid'] ?? '',
      finPrc: (data['fin_prc'] ?? 0).toDouble(), cur: data['cur'] ?? 1,
      comPct: (data['com_pct'] ?? 0).toDouble(),
      comVal: (data['com_val'] ?? 0).toDouble(),
      comNote: data['com_note'],
      form: data['form'] != null ? Map<String, dynamic>.from(data['form'] as Map) : {},
      sts: data['sts'] ?? 0, cmplBy: data['cmpl_by'],
      iDel: data['i_del'] ?? 0,
      tsCrt: DateTime.parse(data['ts_crt']),
      tsCmpl: data['ts_cmpl'] != null ? DateTime.parse(data['ts_cmpl']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'off_id': offId, 'app_id': appId.isEmpty ? null : appId,
      'sell_uid': sellUid, 'buy_uid': buyUid,
      'brk_uid': brkUid.isEmpty ? null : brkUid,
      'fin_prc': finPrc, 'cur': cur, 'com_pct': comPct, 'com_val': comVal,
      'com_note': comNote, 'form': form, 'sts': sts,
      'cmpl_by': cmplBy, 'i_del': iDel,
      'ts_crt': tsCrt.toIso8601String(),
      'ts_cmpl': tsCmpl?.toIso8601String(),
    };
  }
}
