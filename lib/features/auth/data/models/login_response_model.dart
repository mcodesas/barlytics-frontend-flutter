class LoginResponseModel {
  const LoginResponseModel({
    required this.token,
    this.userId,
    this.empresaId,
    this.email,
    this.roles = const [],
  });

  final String token;
  final int? userId;
  final int? empresaId;
  final String? email;
  final List<String> roles;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) => LoginResponseModel(
        token: json['token']?.toString() ?? '',
        userId: (json['userId'] as num?)?.toInt(),
        empresaId: (json['empresaId'] as num?)?.toInt(),
        email: json['email']?.toString(),
        roles: (json['roles'] as List? ?? const []).map((e) => e.toString()).toList(),
      );
}
