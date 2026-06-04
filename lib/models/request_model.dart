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

  RequestModel({
    required this.id, required this.typ, required this.elm,
    required this.clNm, required this.clPh,
    this.prc = 0, this.cur = 1, this.notes = '',
    Map<String, dynamic>? specs, required this.usrId,
    this.sts = 0, Map<String, dynamic>? matches,
    this.iDel = 0, required this.tsCrt,
  })  : specs = specs ?? {}, matches = matches ?? {};

  factory RequestModel.fromSupabase(Map<String, dynamic> data, String id) {
    return RequestModel(
      id: id, typ: data['typ'] ?? 0, elm: data['elm'] ?? 0,
      clNm: data['cl_nm'] ?? '', clPh: data['cl_ph'] ?? '',
      prc: (data['prc'] ?? 0).toDouble(), cur: data['cur'] ?? 1,
      notes: data['notes'] ?? '',
      specs: data['specs'] != null ? Map<String, dynamic>.from(data['specs'] as Map) : {},
      usrId: data['usr_id'] ?? '', sts: data['sts'] ?? 0,
      matches: data['matches'] != null ? Map<String, dynamic>.from(data['matches'] as Map) : {},
      iDel: data['i_del'] ?? 0, tsCrt: DateTime.parse(data['ts_crt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'typ': typ, 'elm': elm, 'cl_nm': clNm, 'cl_ph': clPh,
      'prc': prc, 'cur': cur, 'notes': notes, 'specs': specs,
      'usr_id': usrId, 'sts': sts, 'matches': matches,
      'i_del': iDel, 'ts_crt': tsCrt.toIso8601String(),
    };
  }
}
