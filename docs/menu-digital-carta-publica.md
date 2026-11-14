# Menú digital · Carta pública de BarLytics

## Alcance

Se incorpora un módulo de gestión independiente del antiguo CRUD técnico `menus`.

**Ruta interna:** `/menu_digital`  
**Ruta pública:** `/#/carta/{slug}`  
**Rama:** `fix/dialogos-responsive-scroll-movil-20261030`  
**Backend:** Spring Boot, módulo `com.barlytics.modules.menudigital`.  
**Migraciones:** Flyway `V62__menu_digital_publico.sql` y `V66__estilos_carta_digital.sql`.

El menú pertenece a una sucursal y comparte **productos seleccionados del catálogo real de esa misma sucursal**; los precios visibles se calculan desde el precio de venta vigente, nunca desde el costo de compra.

## Diseño y experiencia

- **Moderno (TIENDA):** tarjetas de producto con imagen, precio y descripción.
- **Carta tipo libro (LIBRO):** una hoja por categoría, paso de página y chip del tipo sincronizado con la hoja visible.
- **Editorial elegante (EDITORIAL):** lista editorial con tipografía amplia, líneas finas y precios alineados.
- **Galería fotográfica (GALERIA):** imágenes protagonistas y fichas grandes.
- **Minimalista (MINIMALISTA):** lista compacta de productos, detalles y precios.
- Los cinco estilos comparten productos seleccionados, enlace público, QR y las 32 paletas. La miniatura de selección es diferente por estilo, con altura suficiente para no desbordarse en Chrome.
- Colores: **32 paletas predefinidas visibles**, con filtros de claras/oscuras y cuatro tonos HEX personalizables: fondo, principal, texto y tarjetas. El botón «32 paletas de colores» del encabezado del editor desplaza a esta sección y cada opción presenta una miniatura con colores reales.
- Vista web de la portada: se utiliza `BoxFit.contain` en pantallas anchas para evitar cortar textos o logotipos incluidos en la fotografía del banner. En móvil se conserva la composición adaptativa.
- Encabezado administrativo web: el título compacto «Menú digital» evita truncamientos cuando hay selectores de rol y sucursal.
- Portada: carga de PNG/JPEG/WEBP de hasta 1,5 MB o enlace HTTPS; nombre y descripción personalizados.
- Editor con selección de productos, búsqueda, vista previa y estados de publicación.
- Enlace público estable de lectura, no requiere login del visitante. Funciona exclusivamente si el menú está publicado.
- Compartir mediante copiar enlace o WhatsApp.
- QR descargable en **PNG de 760×760** mediante endpoint propio de ZXing y en **PDF A5** para imprimir en las mesas.
- Open Graph para enlaces de WhatsApp/redes, con portada compartible incluso si fue subida en base64.
- La carta y los QR no crean pedidos ni afectan el stock o ventas del POS.

## APIs

Administrativas, requieren JWT, acceso a sucursal y permiso `menu_digital`:

```
GET  /api/v1/menu-digital?sucursalId=...
GET  /api/v1/menu-digital/catalogo?sucursalId=...
PUT  /api/v1/menu-digital?sucursalId=...
POST /api/v1/menu-digital/publicar?sucursalId=...
POST /api/v1/menu-digital/ocultar?sucursalId=...
```

Públicas, solo para cartas publicadas:

```
GET /api/v1/menu-digital/public/{slug}
GET /api/v1/menu-digital/public/{slug}/compartir
GET /api/v1/menu-digital/public/{slug}/imagen
GET /api/v1/menu-digital/public/{slug}/qr
```

La migración registra `Menú digital` en **Mi negocio**, con permiso inicial para roles predefinidos de gerencia y administración. Para roles personalizados, asignar manualmente `menu_digital` desde Roles.

El backend reutiliza `BARLYTICS_EVENTS_FRONTEND_URL` para componer la URL al navegador y acepta `BARLYTICS_PUBLIC_BACKEND_URL` opcional para el enlace social, cuya opción predeterminada es `https://www.barlytics.com.co`. La URL social debe apuntar a un dominio público que realmente enrute `/api/v1` al backend; un servidor local LAN no puede ser escaneado por visitantes externos.

## QA pendiente (sin ejecución)

1. Compilación backend `./gradlew test` y Flyway V62/V66 en PostgreSQL de pruebas.
2. Flutter `flutter analyze`, `flutter test test/features/menu_digital`.
3. Permisos: rol gerencial y un rol personalizado con/sin `menu_digital`; nunca gestionar cartas de otra sucursal.
4. CRUD de la carta, carga de portada y precio vigente desde PostgreSQL.
5. Probar los cinco estilos y la navegación por hojas en 320, 390, 768 y 1440 px, temas claro/oscuro, contenido largo, escalado de texto y teclado.
6. Publicación: los borradores y las cartas ocultas deben devolver **404** para JSON, OG, portada y QR.
7. Compartir desde WhatsApp, iOS, Android y desktop; comprobar imagen Open Graph y descarga real de PNG/PDF.
8. Escanear el PNG/PDF desde otro teléfono **sin sesión** y abrir la carta correcta, con HTTPS y productos de la sucursal.
9. Verificar que un cambio de sucursal en el editor no mezcle datos.
10. Confirmar que una carta no pueda incluir insumos ni productos de otra sucursal.
11. Verificar que las modificaciones a una carta publicada aparezcan en el enlace estable.

**Estado:** ajustes en rama de desarrollo; validación de estructura realizada, ejecución de Flutter y QA visual en navegador pendientes. Sin PR, merge ni despliegue.

## Identidad visual e imágenes de la carta (V67 y V68)

La carta ofrece **dos opciones de encabezado** independientes de sus cinco
diseños de productos y de las 32 paletas de color:

- **Foto completa arriba** (predeterminada): la foto se muestra con
  `BoxFit.contain`, sin cortar afiches ni logos incluidos en ella. Debajo se
  presentan el logo del negocio, el nombre de la sucursal, el título y la
  descripción de la carta.
- **Encabezado dividido clásico**: conserva la versión anterior, con el texto
  y la fotografía en el mismo bloque horizontal.

El logo de la carta utiliza por defecto `sucursal.sucu_foto`. El gerente
puede subir un logo distinto para esa carta, o restablecer el de la sucursal.
No se modifica el registro de la sucursal.

Además se puede subir una foto de **fondo opcional**, que se combina de forma
atenuada con el color de fondo seleccionado para garantizar la lectura, y
una **galería de hasta seis fotografías** con visor de zoom. Se puede activar
«Mostrar estas fotos también arriba» para alternarlas junto con la portada
principal en un carrusel. La galería inferior sigue visible.

Los cambios quedan almacenados por sucursal en
`menu_digital.mudi_logo`, `mudi_fondo_imagen`, `mudi_galeria`,
`mudi_portada_modo` (migración **V67**) y `mudi_galeria_arriba`
(migración **V68**). `mudi_slug` no cambia: los enlaces de compartir y el QR
que ya existen continúan funcionando.

Límites validados en backend: portada y fondo hasta 1,5 MB cada uno, logo
hasta 900 KB y seis fotografías de galería de 700 KB como máximo por foto.
Solo se admiten JPEG/PNG/WEBP en Data URI, o URLs HTTPS para imágenes
individuales. Las fotos de galería se cargan desde archivos en el editor;
no se admiten SVG ni rutas `file:`.

### Regresión requerida

1. Abrir una carta existente: conservar portada, colores, productos, enlaces y
   logo de sucursal sin tener que volver a cargar las imágenes.
2. Elegir portada completa y dividida, cambiar paletas y los cinco diseños.
3. Subir logo propio y pulsar «Usar logo de sucursal».
4. Subir fondo y comprobar lectura en temas claros y oscuros.
5. Agregar varias fotos, eliminar una, ampliar con zoom y recorrer el visor.
6. Activar galería superior, cambiar foto con flechas y abrir foto completa.
7. Confirmar responsividad en 320, 390, 768 y 1440 píxeles y sin desbordes.
8. Cambiar de sucursal: las imágenes temporales no deben compartirse entre
   negocios.
9. Guardar, publicar y abrir carta pública desde el QR y enlace anterior.

**Ejecución automatizada pendiente** en Flutter y PostgreSQL; validar sobre
una copia de datos antes de desplegar.


## Exportación de la carta completa en PDF y QR PNG offline

- **Descargar carta completa PDF** es independiente de los botones del QR.
  Exporta a A4 imprimible todos los productos seleccionados (no los seis de
  la vista previa administrativa), agrupados y ordenados por categoría;
  incluye nombres, descripciones, precios, fotografías de productos cuando
  el diseño las utiliza, portada y logo. **No incluye las fotografías de
  «Conoce el lugar»**. Repite la imagen de fondo configurada de forma tenue
  detrás del contenido en todas las páginas y adapta el aspecto de los diez
  estilos (incluido **ELEGANTE**, con cabeceras, productos y precios centrados).
  Mantiene la paleta configurada en el diseño **TIENDA**.
  El PDF adapta la presentación responsiva a hojas paginadas; no es una
  captura del viewport ni tiene elementos interactivos de búsqueda o filtro.
- Se puede generar desde **borrador**, sin necesidad de publicar. Si la
  carta está publicada, se añade al final un QR con el enlace público.
  Las fotos remotas se cargan de forma opcional y con límites de tamaño/
  tiempo; si alguna falla por conexión/CORS, los productos siempre se
  exportan con sus datos y precio.
- **Descargar QR PNG** ya no llama al endpoint HTTP antiguo: genera
  localmente un QR PNG de 760 × 760 con quiet zone blanca en Flutter
  Web, Android, iOS y escritorio. El diálogo **Compartir** también presenta
  el código localmente, incluso si el backend presenta un HTTP 500.
- El backend conserva `GET /api/v1/menu-digital/public/{slug}/qr` para
  clientes antiguos. Genera el PNG sin `java.awt` ni `ImageIO`, y solo
  consulta que el menú esté publicado y su sucursal activa, sin cargar
  fotos ni productos. Si hay una excepción, registra su causa en logs.
- Nueva dependencia Flutter: `qr_flutter ^4.1.0`. Después del
  `git pull` ejecutar `flutter pub get` y reiniciar la aplicación;
  **hot restart no instala dependencias**.
- Los nuevos tests de PDF y QR forman parte del paso `verify` del
  workflow `deploy-production.yml` al integrar la rama a main.

### Fidelidad visual de PDF Elegante (14-11-2026)

- No crea una portada adicional antes del catálogo: abre con nombre, título y
  descripción sobre la misma fotografía de fondo atenuada que utiliza la web.
- Cada categoría presenta el diamante ornamental, «LA CARTA», título centrado,
  líneas finas doradas y productos sin fotografías, con textos y precios
  centrados, como el diseño de alta cocina público.
- Repite la foto de fondo `fondoImagen` en **cada hoja A4**, con el velo oscuro
  del diseño público. Si la imagen no está disponible, utiliza el color oscuro
  original sin bloquear la exportación.
- La galería «Conoce el lugar» permanece en la **web pública**, pero no se
  descarga ni incorpora al PDF de la carta.
- Se verifican mediante pruebas: carga del fondo, ausencia de descargas de
  galería, exportación de diez estilos y paginación de una carta de 65 productos.
