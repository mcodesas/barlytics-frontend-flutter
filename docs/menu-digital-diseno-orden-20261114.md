# Menú digital: rediseño y orden por sucursal (14-11-2026)

## Ramas

- Frontend: `mcodesas/barlytics-frontend-flutter` → `feat/menu-digital-diseno-orden-20261114`
- Backend: `mcodesas/barlytics-commerce-service` → `feat/menu-digital-diseno-orden-20261114`
- Ambas parten de `main`. No se ha solicitado PR, merge ni despliegue.

## Diseño público

Se conservan cinco diseños y los datos existentes de la carta, pero se simplifica su composición:

- **Moderno:** tarjetas sobrias con foto, título, descripción cuando existe y precio destacado sin chips superpuestos.
- **Libro:** capítulo por categoría, filas legibles y navegación anterior/siguiente; se puede elegir capítulo en un selector.
- **Editorial:** lista tipográfica, detalles y precios, sin encabezados repetidos dentro de cada categoría.
- **Galería:** fotografías equilibradas y metadatos discretos.
- **Minimalista:** lista compacta para consultar precios rápidamente.

Las categorías dejan de mostrarse como una nube de botones. Por defecto se enseña **toda la carta agrupada** por secciones con títulos claros, en el orden configurado. Un selector `Ver sección` permite filtrar cuando el visitante lo desea. En el libro, el selector corresponde al capítulo. La búsqueda es global y restablece el filtro de categoría. La galería del local queda después del catálogo para dar prioridad a los productos.

Se mantienen paletas, modo de portada, logo, fotos, visor de productos, URL pública, slug y QR.

## Administración

En **Menú digital → Productos de la carta → Ordenar categorías y productos**:

1. Seleccionar primero los productos de la carta.
2. En **Categorías**, arrastrar, usar flechas o tocar la fila para asignar una posición numérica.
3. En **Productos**, elegir una categoría y ordenar sus artículos con los mismos controles.
4. Pulsar **Aplicar orden** y después **Guardar cambios** del menú para persistir.
5. Verificar la vista previa y la carta pública. Los cambios conservan el enlace/QR existente.

El orden se guarda por sucursal y no modifica los tipos ni el catálogo global del POS.

## Contrato API y base de datos

- La solicitud `PUT /api/v1/menu-digital?sucursalId=...` incluye `ordenTipos: string[]`, en el orden de aparición.
- `productos: number[]` utiliza el orden explícito; el backend ya persiste sus posiciones en `commerce.menu_digital_producto.mdpr_orden`.
- Las respuestas de administración y `GET /api/v1/menu-digital/public/{slug}` incluyen `ordenTipos`.
- Nueva migración Flyway `V74__menu_digital_orden_tipos.sql` agrega `commerce.menu_digital.mudi_orden_tipos TEXT NOT NULL DEFAULT '[]'`. Es aditiva: no elimina ni reescribe cartas anteriores.
- La validación del backend limita las categorías a 200, sin nombres vacíos, largos o duplicados (sin distinguir mayúsculas).
- **Compatibilidad:** cuando una aplicación antigua no envía `ordenTipos`, el backend conserva el orden existente de categorías y de productos seleccionados y anexa los nuevos. Las aplicaciones nuevas siempre envían la lista.

## Despliegue y QA

**Desplegar el backend con Flyway V74 primero**, y después frontend web y nuevas versiones móviles y escritorio. No actualizar el frontend antes de la migración del servicio.

Comandos para ejecutar en los repositorios clonados:

```bash
# Frontend
flutter analyze lib/features/menu_digital
flutter test test/features/menu_digital

# Backend
./gradlew test --tests 'com.barlytics.modules.menudigital.usecase.MenuDigitalServiceTest'
```

Matriz manual por ejecutar: Android/iOS/web/escritorio; anchos 320, 390, 768 y 1440; cinco diseños; categorías y productos ordenados; categoría sin tipo; listas grandes; colores claros y oscuros; cambios de sucursal; búsqueda tras filtrar; orden conservado tras recargar; compatibilidad de enlace público/QR; cliente antiguo que edita una carta; subida y visualización de imágenes; modo libro; accesibilidad y diálogos con teclado.

Se incorporaron pruebas de ordenamiento en Flutter, ampliación del test visual de dos a cinco diseños, y pruebas JUnit de validación de categorías. No se pudo ejecutar Flutter, Gradle ni un QA de navegador/dispositivos desde este entorno; se requiere CI local o ejecución en una copia de pruebas antes del merge.
