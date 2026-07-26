import '../../../../core/constants/api_paths.dart';
import '../../../../core/crud/crud_field.dart';
import '../../../../core/network/api_client.dart';

class SucursalCatalogs {
  const SucursalCatalogs({
    this.empresas = const <int, String>{},
    this.ciudades = const <int, String>{},
    this.monedas = const <int, String>{},
    this.paises = const <int, String>{},
    this.zonasHorarias = const <int, String>{},
    this.empresaOptions = const <CrudLookupOption>[],
    this.ciudadOptions = const <CrudLookupOption>[],
    this.monedaOptions = const <CrudLookupOption>[],
    this.paisOptions = const <CrudLookupOption>[],
    this.zonaOptions = const <CrudLookupOption>[],
  });

  final Map<int, String> empresas;
  final Map<int, String> ciudades;
  final Map<int, String> monedas;
  final Map<int, String> paises;
  final Map<int, String> zonasHorarias;

  final List<CrudLookupOption> empresaOptions;
  final List<CrudLookupOption> ciudadOptions;
  final List<CrudLookupOption> monedaOptions;
  final List<CrudLookupOption> paisOptions;
  final List<CrudLookupOption> zonaOptions;

  String empresa(int? id) => _label(empresas, id, 'Empresa');
  String ciudad(int? id) => _label(ciudades, id, 'Ciudad');
  String moneda(int? id) => _label(monedas, id, 'Moneda');
  String pais(int? id) => _label(paises, id, 'País');
  String zona(int? id) => _label(zonasHorarias, id, 'Zona horaria');

  static String _label(Map<int, String> values, int? id, String fallback) {
    if (id == null) return 'Sin $fallback';
    return values[id] ?? '$fallback #$id';
  }

  static Future<SucursalCatalogs> load(ApiClient apiClient) async {
    Future<List<Map<String, dynamic>>> safeLoad(String path) async {
      try {
        final response = await apiClient.get<List<Map<String, dynamic>>>(
          path,
          _parseList,
        );
        return response.data ?? const <Map<String, dynamic>>[];
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }

    final results = await Future.wait([
      safeLoad(ApiPaths.empresas),
      safeLoad(ApiPaths.ciudades),
      safeLoad(ApiPaths.monedas),
      safeLoad(ApiPaths.paises),
      safeLoad(ApiPaths.zonashorarias),
    ]);

    final empresasRaw = results[0];
    final ciudadesRaw = results[1];
    final monedasRaw = results[2];
    final paisesRaw = results[3];
    final zonasRaw = results[4];

    return SucursalCatalogs(
      empresas: _mapLabels(
        empresasRaw,
        'emprId',
        const ['empreNombreComercial', 'emprRazonSocial'],
      ),
      ciudades: _mapLabels(
        ciudadesRaw,
        'ciudId',
        const ['ciudNombre', 'ciudCodigoDane'],
      ),
      monedas: _mapLabels(
        monedasRaw,
        'moneId',
        const ['moneCodigoiso', 'moneNombre', 'moneSimbolo'],
      ),
      paises: _mapLabels(
        paisesRaw,
        'paisId',
        const ['paisNombre', 'paisCodigo'],
      ),
      zonasHorarias: _mapLabels(
        zonasRaw,
        'zohoId',
        const ['zohoNombre', 'zohoAbreviatura', 'zohoOffsetOut'],
      ),
      empresaOptions: _toOptions(
        empresasRaw,
        'emprId',
        const ['empreNombreComercial', 'emprRazonSocial'],
      ),
      ciudadOptions: _toOptions(
        ciudadesRaw,
        'ciudId',
        const ['ciudNombre', 'ciudCodigoDane'],
      ),
      monedaOptions: _toOptions(
        monedasRaw,
        'moneId',
        const ['moneCodigoiso', 'moneNombre', 'moneSimbolo'],
      ),
      paisOptions: _toOptions(
        paisesRaw,
        'paisId',
        const ['paisNombre', 'paisCodigo'],
      ),
      zonaOptions: _toOptions(
        zonasRaw,
        'zohoId',
        const ['zohoNombre', 'zohoAbreviatura', 'zohoOffsetOut'],
      ),
    );
  }

  static List<Map<String, dynamic>> _parseList(Object? json) {
    return (json as List? ?? const <Object?>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<int, String> _mapLabels(
    List<Map<String, dynamic>> items,
    String idField,
    List<String> labelFields,
  ) {
    final result = <int, String>{};
    for (final item in items) {
      final id = (item[idField] as num?)?.toInt();
      if (id == null) continue;
      final label = _composeLabel(item, labelFields);
      result[id] = label.isEmpty ? 'Registro #$id' : label;
    }
    return result;
  }

  static List<CrudLookupOption> _toOptions(
    List<Map<String, dynamic>> items,
    String idField,
    List<String> labelFields,
  ) {
    final options = <CrudLookupOption>[];
    for (final item in items) {
      final id = item[idField];
      if (id == null) continue;
      final label = _composeLabel(item, labelFields);
      options.add(
        CrudLookupOption(
          id: id,
          label: label.isEmpty ? 'Registro #$id' : label,
          raw: item,
        ),
      );
    }
    options.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  static String _composeLabel(
    Map<String, dynamic> item,
    List<String> labelFields,
  ) {
    final values = labelFields
        .map((field) => item[field]?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    return values.join(' · ');
  }
}
