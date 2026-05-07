class LoginRequestModel {
  const LoginRequestModel({required this.identificador, required this.password});
  final String identificador;
  final String password;
  Map<String, dynamic> toJson() => {'identificador': identificador, 'password': password};
}
