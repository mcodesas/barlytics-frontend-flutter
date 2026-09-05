from pathlib import Path

path = Path('lib/features/mesero/presentation/pages/mesero_page.dart')
text = path.read_text(encoding='utf-8')

anchor = "  String _fechaIso(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';\n"
helper = '''  String? _fotoDetalleProducto(MeseroDetalleProductoModel detalle) {
    final fotoDetalle = (detalle.productoFoto ?? '').trim();
    if (fotoDetalle.isNotEmpty) return fotoDetalle;
    final productoId = detalle.productoId;
    if (productoId == null) return null;
    for (final producto in _productos) {
      if (producto.prodId == productoId) {
        final fotoCatalogo = (producto.foto ?? '').trim();
        return fotoCatalogo.isEmpty ? null : fotoCatalogo;
      }
    }
    return null;
  }

'''
if helper not in text:
    if anchor not in text:
        raise SystemExit('No se encontro ancla para helper de imagen')
    text = text.replace(anchor, helper + anchor, 1)

count = text.count('producto.productoFoto')
if count == 0:
    raise SystemExit('No se encontraron usos de producto.productoFoto')
text = text.replace('producto.productoFoto', '_fotoDetalleProducto(producto)')

path.write_text(text, encoding='utf-8')
print(f'Fallback de imagen aplicado en {count} lugares')
