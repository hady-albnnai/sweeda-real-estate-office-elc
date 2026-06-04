class PaymentModel {
  final String id;
  final String uid;
  final int tp;
  final int pkg;
  final double amt;
  final int cur;
  final int mtd;
  final String proof;
  final String ref;
  final int sts;
  final String? apprBy;
  final DateTime tsCrt;

  PaymentModel({
    required this.id, required this.uid, required this.tp,
    this.pkg = 0, required this.amt, this.cur = 1, this.mtd = 0,
    this.proof = '', this.ref = '', this.sts = 0,
    this.apprBy, required this.tsCrt,
  });

  factory PaymentModel.fromSupabase(Map<String, dynamic> data, String id) {
    return PaymentModel(
      id: id, uid: data['uid'] ?? '', tp: data['tp'] ?? 0,
      pkg: data['pkg'] ?? 0, amt: (data['amt'] ?? 0).toDouble(),
      cur: data['cur'] ?? 1, mtd: data['mtd'] ?? 0,
      proof: data['proof'] ?? '', ref: data['ref'] ?? '',
      sts: data['sts'] ?? 0, apprBy: data['appr_by'],
      tsCrt: DateTime.parse(data['ts_crt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid, 'tp': tp, 'pkg': pkg, 'amt': amt,
      'cur': cur, 'mtd': mtd, 'proof': proof, 'ref': ref,
      'sts': sts, 'appr_by': apprBy,
      'ts_crt': tsCrt.toIso8601String(),
    };
  }
}
