/// Modelo de request para crear o actualizar registros del módulo Usuarios.
class UsuariosRequestModel {
  const UsuariosRequestModel({
    this.ciudId,
    this.emprId,
    this.sucuId,
    this.usuaEmail,
    this.usuaPrimerApellido,
    this.usuaPrimerNombre,
    this.usuaSegundoApellido,
    this.usuaEstado,
    this.usuaBloqueado,
    this.usuaSegundoNombre,
    this.usuaFechaNacimiento,
    this.usuaDireccion,
    this.usuaTelefonoPrincipal,
    this.usuaTelefonoSecundario,
    this.usuaFoto,
  });

  final int? ciudId;
  final int? emprId;
  final int? sucuId;
  final String? usuaEmail;
  final String? usuaPrimerApellido;
  final String? usuaPrimerNombre;
  final String? usuaSegundoApellido;
  final int? usuaEstado;
  final int? usuaBloqueado;
  final String? usuaSegundoNombre;
  final String? usuaFechaNacimiento;
  final String? usuaDireccion;
  final String? usuaTelefonoPrincipal;
  final String? usuaTelefonoSecundario;
  final String? usuaFoto;

  factory UsuariosRequestModel.fromJson(Map<String, dynamic> json) => UsuariosRequestModel(
      ciudId: (json['ciudId'] as num?)?.toInt(),
      emprId: (json['emprId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      usuaEmail: json['usuaEmail']?.toString(),
      usuaPrimerApellido: json['usuaPrimerApellido']?.toString(),
      usuaPrimerNombre: json['usuaPrimerNombre']?.toString(),
      usuaSegundoApellido: json['usuaSegundoApellido']?.toString(),
      usuaEstado: (json['usuaEstado'] as num?)?.toInt(),
      usuaBloqueado: (json['usuaBloqueado'] as num?)?.toInt(),
      usuaSegundoNombre: json['usuaSegundoNombre']?.toString(),
      usuaFechaNacimiento: json['usuaFechaNacimiento']?.toString(),
      usuaDireccion: json['usuaDireccion']?.toString(),
      usuaTelefonoPrincipal: json['usuaTelefonoPrincipal']?.toString(),
      usuaTelefonoSecundario: json['usuaTelefonoSecundario']?.toString(),
      usuaFoto: json['usuaFoto']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (ciudId != null) 'ciudId': ciudId,
      if (emprId != null) 'emprId': emprId,
      if (sucuId != null) 'sucuId': sucuId,
      if (usuaEmail != null) 'usuaEmail': usuaEmail,
      if (usuaPrimerApellido != null) 'usuaPrimerApellido': usuaPrimerApellido,
      if (usuaPrimerNombre != null) 'usuaPrimerNombre': usuaPrimerNombre,
      if (usuaSegundoApellido != null) 'usuaSegundoApellido': usuaSegundoApellido,
      if (usuaEstado != null) 'usuaEstado': usuaEstado,
      if (usuaBloqueado != null) 'usuaBloqueado': usuaBloqueado,
      if (usuaSegundoNombre != null) 'usuaSegundoNombre': usuaSegundoNombre,
      if (usuaFechaNacimiento != null) 'usuaFechaNacimiento': usuaFechaNacimiento,
      if (usuaDireccion != null) 'usuaDireccion': usuaDireccion,
      if (usuaTelefonoPrincipal != null) 'usuaTelefonoPrincipal': usuaTelefonoPrincipal,
      if (usuaTelefonoSecundario != null) 'usuaTelefonoSecundario': usuaTelefonoSecundario,
      if (usuaFoto != null) 'usuaFoto': usuaFoto,
  };
}
