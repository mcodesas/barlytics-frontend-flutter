from pathlib import Path

path = Path('lib/features/mesero/presentation/pages/mesero_page.dart')
text = path.read_text(encoding='utf-8')

replacements = []

replacements.append((
    "import 'dart:convert';\nimport 'dart:typed_data';",
    "import 'dart:async';\nimport 'dart:convert';\nimport 'dart:typed_data';",
))

replacements.append((
'''  Future<void> _load() async {
    final results = await Future.wait([
      _dataSource.listarMesas(),
      _dataSource.listarProductos(),
      _dataSource.listarMediosPago(),
      _dataSource.listarVentasDirectasAbiertas(),
    ]);
    _mesas = results[0] as List<MeseroMesaResumenModel>;
    _productos = results[1] as List<MeseroProductoModel>;
    _mediosPago = results[2] as List<MeseroMedioPagoModel>;
    _ventasDirectasAbiertas = results[3] as List<MeseroVentaModel>;
    _cargaInicialCompletada = true;
  }
''',
'''  Future<void> _load() async {
    // Mesas es el dato critico para pintar la operacion. El catalogo, medios de
    // pago y ventas directas se cargan despues sin bloquear la primera vista.
    _mesas = await _dataSource.listarMesas();
    _cargaInicialCompletada = true;

    unawaited(_loadSecondaryOperationData());
  }

  Future<void> _loadSecondaryOperationData() async {
    final productosFuture = _dataSource.listarProductos();
    final mediosFuture = _dataSource.listarMediosPago();
    final directasFuture = _dataSource.listarVentasDirectasAbiertas();

    try {
      final productos = await productosFuture;
      if (!mounted) return;
      setState(() => _productos = productos);
    } catch (_) {
      // La operacion de mesas debe seguir disponible aunque falle el catalogo.
    }

    try {
      final medios = await mediosFuture;
      if (!mounted) return;
      setState(() => _mediosPago = medios);
    } catch (_) {
      // Los medios se reintentaran cuando la accion que los necesita recargue.
    }

    try {
      final directas = await directasFuture;
      if (!mounted) return;
      setState(() => _ventasDirectasAbiertas = directas);
    } catch (_) {
      // No bloqueamos la vista principal por una lista secundaria.
    }
  }
'''))

replacements.append((
'''  Future<List<MeseroVentaModel>> _cargarHistorialVentas() async {
    final ventas = await _dataSource.historialVentas();
    _historialVentas = ventas;
    return ventas;
  }
''',
'''  Future<List<MeseroVentaModel>> _cargarHistorialVentas() async {
    final filtro = _historialDiaFiltro;
    final fecha = filtro == null ? null : _fechaIso(filtro);
    final ventas = await _dataSource.historialVentas(
      desde: fecha,
      hasta: fecha,
      pagina: 0,
      tamano: filtro == null ? 200 : 500,
    );
    _historialVentas = ventas;
    return ventas;
  }
'''))

replacements.append((
'''    if (!mounted || picked == null) return;
    setState(() {
      _historialDiaFiltro = _soloFecha(picked);
    });
  }

  void _filtrarHistorialHoy() {
    setState(() {
      _historialDiaFiltro = _soloFecha(DateTime.now());
    });
  }

  void _limpiarFiltroHistorial() {
    setState(() {
      _historialDiaFiltro = null;
    });
  }
''',
'''    if (!mounted || picked == null) return;
    setState(() {
      _historialDiaFiltro = _soloFecha(picked);
    });
    unawaited(_reloadHistorialVentas());
  }

  void _filtrarHistorialHoy() {
    setState(() {
      _historialDiaFiltro = _soloFecha(DateTime.now());
    });
    unawaited(_reloadHistorialVentas());
  }

  void _limpiarFiltroHistorial() {
    setState(() {
      _historialDiaFiltro = null;
    });
    unawaited(_reloadHistorialVentas());
  }
'''))

for old, new in replacements:
    if old not in text:
        raise SystemExit(f'Bloque esperado no encontrado: {old[:80]!r}')
    text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8')
print('mesero_page.dart actualizado')
