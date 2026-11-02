# Menú digital · Carta pública de BarLytics

## Alcance

Se incorpora un módulo de gestión independiente del antiguo CRUD técnico `menus`.

**Ruta interna:** `/menu_digital`  
**Ruta pública:** `/#/carta/{slug}`  
**Rama:** `fix/dialogos-responsive-scroll-movil-20261030`  
**Backend:** Spring Boot, módulo `com.barlytics.modules.menudigital`.  
**Migración:** Flyway `V62__menu_digital_publico.sql`.

El menú pertenece a una sucursal y comparte **productos seleccionados del catálogo real de esa misma sucursal**; los precios visibles se calculan desde el precio de venta vigente, nunca desde el costo de compra.

## Diseño y experiencia

- Vista **TIENDA**: tarjetas, imágenes, nombres, descripciones, categoría y precio.
- Vista **LIBRO**: una hoja por categoría, paso de página anterior/siguiente, precios y detalles.
- Colores: 6 paletas predefinidas o personalización HEX de fondo, color principal, letra y tarjetas.
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

1. Compilación backend `./gradlew test` y Flyway V62 en PostgreSQL de pruebas.
2. Flutter `flutter analyze`, `flutter test test/features/menu_digital`.
3. Permisos: rol gerencial y un rol personalizado con/sin `menu_digital`; nunca gestionar cartas de otra sucursal.
4. CRUD de la carta, carga de portada y precio vigente desde PostgreSQL.
5. Probar Tienda y Libro en 320, 390, 768 y 1440 px, temas claro/oscuro, contenido largo y teclado.
6. Publicación: los borradores y las cartas ocultas deben devolver **404** para JSON, OG, portada y QR.
7. Compartir desde WhatsApp, iOS, Android y desktop; comprobar imagen Open Graph y descarga real de PNG/PDF.
8. Escanear el PNG/PDF desde otro teléfono **sin sesión** y abrir la carta correcta, con HTTPS y productos de la sucursal.
9. Verificar que un cambio de sucursal en el editor no mezcle datos.
10. Confirmar que una carta no pueda incluir insumos ni productos de otra sucursal.
11. Verificar que las modificaciones a una carta publicada aparezcan en el enlace estable.

**Estado:** código y pruebas fuente incorporados a la rama, compilación y QA de ejecución pendientes. Sin PR, merge ni despliegue.
