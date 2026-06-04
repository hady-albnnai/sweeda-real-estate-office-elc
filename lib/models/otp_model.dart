class OtpModel {
  final String id;
  final String phone;
  final String code;
  final DateTime expiresAt;
  final int used;
  final DateTime tsCrt;

  OtpModel({
    required this.id, required this.phone, required this.code,
    required this.expiresAt, this.used = 0, required this.tsCrt,
  });

  bool get isExpired => expiresAt.isBefore(DateTime.now());
  bool get isUsed => used == 1;
  bool get isValid => !isExpired && !isUsed;
}
