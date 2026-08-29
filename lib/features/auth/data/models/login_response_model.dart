class LoginResponseModel {
  const LoginResponseModel({
    required this.token,
    this.userId,
    this.empresaId,
    this.sucursalId,
    this.email,
    this.roles = const [],
    this.subscriptionStatus,
    this.subscriptionActive = true,
  });

  final String token;
  final int? userId;
  final int? empresaId;
  final int? sucursalId;
  final String? email;
  final List<String> roles;
  final String? subscriptionStatus;
  final bool subscriptionActive;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) => LoginResponseModel(
        token: json['token']?.toString() ?? '',
        userId: (json['userId'] as num?)?.toInt(),
        empresaId: (json['empresaId'] as num?)?.toInt(),
        sucursalId: (json['sucursalId'] as num?)?.toInt(),
        email: json['email']?.toString(),
        roles: (json['roles'] as List? ?? const []).map((e) => e.toString()).toList(),
        subscriptionStatus: json['subscriptionStatus']?.toString(),
        subscriptionActive: json['subscriptionActive'] == null ? true : json['subscriptionActive'] == true,
      );
}
