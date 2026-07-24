/// Modelo de respuesta del módulo Usuarios basado en la colección Postman.
class UsuariosResponseModel {
  const UsuariosResponseModel({
    this.usuaId,
    this.ciudId,
    this.emprId,
    this.sucuId,
    this.usuaEstado,
    this.usuaBloqueado,
    this.usuaPrimerNombre,
    this.usuaSegundoNombre,
    this.usuaSegundoApellido,
    this.usuaPrimerApellido,
    this.usuaEmail,
    this.usuaFechaNacimiento,
    this.usuaDireccion,
    this.usuaTelefonoPrincipal,
    this.usuaTelefonoSecundario,
    this.usuaFoto,
    this.usuaRegistradoPor,
    this.usuaFechaCambio,
  });

  final int? usuaId;
  final int? ciudId;
  final int? emprId;
  final int? sucuId;
  final int? usuaEstado;
  final int? usuaBloqueado;
  final String? usuaPrimerNombre;
  final String? usuaSegundoNombre;
  final String? usuaSegundoApellido;
  final String? usuaPrimerApellido;
  final String? usuaEmail;
  final String? usuaFechaNacimiento;
  final String? usuaDireccion;
  final String? usuaTelefonoPrincipal;
  final String? usuaTelefonoSecundario;
  final String? usuaFoto;
  final String? usuaRegistradoPor;
  final String? usuaFechaCambio;

  factory UsuariosResponseModel.fromJson(Map<String, dynamic> json) => UsuariosResponseModel(
      usuaId: (json['usuaId'] as num?)?.toInt(),
      ciudId: (json['ciudId'] as num?)?.toInt(),
      emprId: (json['emprId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      usuaEstado: (json['usuaEstado'] as num?)?.toInt(),
      usuaBloqueado: (json['usuaBloqueado'] as num?)?.toInt(),
      usuaPrimerNombre: json['usuaPrimerNombre']?.toString(),
      usuaSegundoNombre: json['usuaSegundoNombre']?.toString(),
      usuaSegundoApellido: json['usuaSegundoApellido']?.toString(),
      usuaPrimerApellido: json['usuaPrimerApellido']?.toString(),
      usuaEmail: json['usuaEmail']?.toString(),
      usuaFechaNacimiento: json['usuaFechaNacimiento']?.toString(),
      usuaDireccion: json['usuaDireccion']?.toString(),
      usuaTelefonoPrincipal: json['usuaTelefonoPrincipal']?.toString(),
      usuaTelefonoSecundario: json['usuaTelefonoSecundario']?.toString(),
      usuaFoto: json['usuaFoto']?.toString(),
      usuaRegistradoPor: json['usuaRegistradoPor']?.toString(),
      usuaFechaCambio: json['usuaFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'usuaId': usuaId,
      'ciudId': ciudId,
      'emprId': emprId,
      'sucuId': sucuId,
      'usuaEstado': usuaEstado,
      'usuaBloqueado': usuaBloqueado,
      'usuaPrimerNombre': usuaPrimerNombre,
      'usuaSegundoNombre': usuaSegundoNombre,
      'usuaSegundoApellido': usuaSegundoApellido,
      'usuaPrimerApellido': usuaPrimerApellido,
      'usuaEmail': usuaEmail,
      'usuaFechaNacimiento': usuaFechaNacimiento,
      'usuaDireccion': usuaDireccion,
      'usuaTelefonoPrincipal': usuaTelefonoPrincipal,
      'usuaTelefonoSecundario': usuaTelefonoSecundario,
      'usuaFoto': usuaFoto,
      'usuaRegistradoPor': usuaRegistradoPor,
      'usuaFechaCambio': usuaFechaCambio,
  };

  Object? get id => usuaId;

  String label() {
    final values = <Object?>[usuaId, usuaPrimerNombre, usuaPrimerApellido, usuaEmail];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
