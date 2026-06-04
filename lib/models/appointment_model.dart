class AppointmentModel {
  final String id;
  final String offId;
  final String reqId;
  final String ownId;
  final String bkrId;
  final DateTime dt;
  final DateTime? dtEnd;
  final int sts;
  final String? cnlBy;
  final String? cnlRsn;
  final int fbkOwn;
  final int fbkReq;
  final DateTime? fbkOwnDt;
  final DateTime? fbkReqDt;
  final int fbkOwnDur;
  final int fbkReqDur;
  final String? adminNt;
  final int iForce;
  final String? forceBy;
  final int rmnd24;
  final int rmnd2;
  final int rmndQtr;
  final int rmndEnd;
  final DateTime tsCrt;

  AppointmentModel({
    required this.id, required this.offId, this.reqId = '',
    required this.ownId, this.bkrId = '', required this.dt,
    this.dtEnd, this.sts = 0, this.cnlBy, this.cnlRsn,
    this.fbkOwn = 0, this.fbkReq = 0, this.fbkOwnDt, this.fbkReqDt,
    this.fbkOwnDur = 0, this.fbkReqDur = 0, this.adminNt,
    this.iForce = 0, this.forceBy, this.rmnd24 = 0,
    this.rmnd2 = 0, this.rmndQtr = 0, this.rmndEnd = 0,
    required this.tsCrt,
  });

  factory AppointmentModel.fromSupabase(Map<String, dynamic> data, String id) {
    return AppointmentModel(
      id: id,
      offId: data['off_id'] ?? '', reqId: data['req_id'] ?? '',
      ownId: data['own_id'] ?? '', bkrId: data['bkr_id'] ?? '',
      dt: DateTime.parse(data['dt']),
      dtEnd: data['dt_end'] != null ? DateTime.parse(data['dt_end']) : null,
      sts: data['sts'] ?? 0, cnlBy: data['cnl_by'], cnlRsn: data['cnl_rsn'],
      fbkOwn: data['fbk_own'] ?? 0, fbkReq: data['fbk_req'] ?? 0,
      fbkOwnDt: data['fbk_own_dt'] != null ? DateTime.parse(data['fbk_own_dt']) : null,
      fbkReqDt: data['fbk_req_dt'] != null ? DateTime.parse(data['fbk_req_dt']) : null,
      fbkOwnDur: data['fbk_own_dur'] ?? 0, fbkReqDur: data['fbk_req_dur'] ?? 0,
      adminNt: data['admin_nt'], iForce: data['i_force'] ?? 0, forceBy: data['force_by'],
      rmnd24: data['rmnd_24'] ?? 0, rmnd2: data['rmnd_2'] ?? 0,
      rmndQtr: data['rmnd_qtr'] ?? 0, rmndEnd: data['rmnd_end'] ?? 0,
      tsCrt: DateTime.parse(data['ts_crt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'off_id': offId, 'req_id': reqId.isEmpty ? null : reqId,
      'own_id': ownId, 'bkr_id': bkrId.isEmpty ? null : bkrId,
      'dt': dt.toIso8601String(), 'dt_end': dtEnd?.toIso8601String(),
      'sts': sts, 'cnl_by': cnlBy, 'cnl_rsn': cnlRsn,
      'fbk_own': fbkOwn, 'fbk_req': fbkReq,
      'fbk_own_dt': fbkOwnDt?.toIso8601String(),
      'fbk_req_dt': fbkReqDt?.toIso8601String(),
      'fbk_own_dur': fbkOwnDur, 'fbk_req_dur': fbkReqDur,
      'admin_nt': adminNt, 'i_force': iForce, 'force_by': forceBy,
      'rmnd_24': rmnd24, 'rmnd_2': rmnd2,
      'rmnd_qtr': rmndQtr, 'rmnd_end': rmndEnd,
      'ts_crt': tsCrt.toIso8601String(),
    };
  }
}
