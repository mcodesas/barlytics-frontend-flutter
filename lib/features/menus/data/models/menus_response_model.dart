/// Modelo de respuesta del módulo Menus basado en la colección Postman.
class MenusResponseModel {
  const MenusResponseModel({
    this.menuId,
    this.menuNombre,
    this.menuDescripcion,
    this.menuParametro,
    this.menuGrupoCodigo,
    this.menuGrupoNombre,
    this.menuGrupoIcono,
    this.menuGrupoOrden,
    this.menuOrden,
    this.menuVisible,
    this.menuBottomCodigo,
    this.menuBottomNombre,
    this.menuBottomIcono,
    this.menuBottomOrden,
    this.menuBottomVisible,
    this.menuBottomPrincipal,
    this.menuRegistradoPor,
    this.menuFechaCambio,
  });

  final int? menuId;
  final String? menuNombre;
  final String? menuDescripcion;
  final String? menuParametro;
  final String? menuGrupoCodigo;
  final String? menuGrupoNombre;
  final String? menuGrupoIcono;
  final int? menuGrupoOrden;
  final int? menuOrden;
  final int? menuVisible;
  final String? menuBottomCodigo;
  final String? menuBottomNombre;
  final String? menuBottomIcono;
  final int? menuBottomOrden;
  final int? menuBottomVisible;
  final int? menuBottomPrincipal;
  final String? menuRegistradoPor;
  final String? menuFechaCambio;

  factory MenusResponseModel.fromJson(Map<String, dynamic> json) => MenusResponseModel(
        menuId: (json['menuId'] as num?)?.toInt(),
        menuNombre: json['menuNombre']?.toString(),
        menuDescripcion: json['menuDescripcion']?.toString(),
        menuParametro: json['menuParametro']?.toString(),
        menuGrupoCodigo: json['menuGrupoCodigo']?.toString(),
        menuGrupoNombre: json['menuGrupoNombre']?.toString(),
        menuGrupoIcono: json['menuGrupoIcono']?.toString(),
        menuGrupoOrden: (json['menuGrupoOrden'] as num?)?.toInt(),
        menuOrden: (json['menuOrden'] as num?)?.toInt(),
        menuVisible: (json['menuVisible'] as num?)?.toInt(),
        menuBottomCodigo: json['menuBottomCodigo']?.toString(),
        menuBottomNombre: json['menuBottomNombre']?.toString(),
        menuBottomIcono: json['menuBottomIcono']?.toString(),
        menuBottomOrden: (json['menuBottomOrden'] as num?)?.toInt(),
        menuBottomVisible: (json['menuBottomVisible'] as num?)?.toInt(),
        menuBottomPrincipal: (json['menuBottomPrincipal'] as num?)?.toInt(),
        menuRegistradoPor: json['menuRegistradoPor']?.toString(),
        menuFechaCambio: json['menuFechaCambio']?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'menuId': menuId,
        'menuNombre': menuNombre,
        'menuDescripcion': menuDescripcion,
        'menuParametro': menuParametro,
        'menuGrupoCodigo': menuGrupoCodigo,
        'menuGrupoNombre': menuGrupoNombre,
        'menuGrupoIcono': menuGrupoIcono,
        'menuGrupoOrden': menuGrupoOrden,
        'menuOrden': menuOrden,
        'menuVisible': menuVisible,
        'menuBottomCodigo': menuBottomCodigo,
        'menuBottomNombre': menuBottomNombre,
        'menuBottomIcono': menuBottomIcono,
        'menuBottomOrden': menuBottomOrden,
        'menuBottomVisible': menuBottomVisible,
        'menuBottomPrincipal': menuBottomPrincipal,
        'menuRegistradoPor': menuRegistradoPor,
        'menuFechaCambio': menuFechaCambio,
      };

  Object? get id => menuId;

  String label() {
    final values = <Object?>[menuId, menuNombre, menuGrupoNombre, menuParametro];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
