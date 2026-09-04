/// Modelo de request para crear o actualizar registros del módulo Menus.
class MenusRequestModel {
  const MenusRequestModel({
    this.menuDescripcion,
    this.menuNombre,
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
  });

  final String? menuDescripcion;
  final String? menuNombre;
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

  factory MenusRequestModel.fromJson(Map<String, dynamic> json) => MenusRequestModel(
        menuDescripcion: json['menuDescripcion']?.toString(),
        menuNombre: json['menuNombre']?.toString(),
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
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (menuDescripcion != null) 'menuDescripcion': menuDescripcion,
        if (menuNombre != null) 'menuNombre': menuNombre,
        if (menuParametro != null) 'menuParametro': menuParametro,
        if (menuGrupoCodigo != null) 'menuGrupoCodigo': menuGrupoCodigo,
        if (menuGrupoNombre != null) 'menuGrupoNombre': menuGrupoNombre,
        if (menuGrupoIcono != null) 'menuGrupoIcono': menuGrupoIcono,
        if (menuGrupoOrden != null) 'menuGrupoOrden': menuGrupoOrden,
        if (menuOrden != null) 'menuOrden': menuOrden,
        if (menuVisible != null) 'menuVisible': menuVisible,
        if (menuBottomCodigo != null) 'menuBottomCodigo': menuBottomCodigo,
        if (menuBottomNombre != null) 'menuBottomNombre': menuBottomNombre,
        if (menuBottomIcono != null) 'menuBottomIcono': menuBottomIcono,
        if (menuBottomOrden != null) 'menuBottomOrden': menuBottomOrden,
        if (menuBottomVisible != null) 'menuBottomVisible': menuBottomVisible,
        if (menuBottomPrincipal != null) 'menuBottomPrincipal': menuBottomPrincipal,
      };
}
