# Auditoría de interfaces del frontend BarLytics — 30/10/2026

**Rama:** `fix/dialogos-responsive-scroll-movil-20261030`  
**Estado:** revisión estática y correcciones parciales. **No certificada** para producción.

## Alcance revisado
- Inventario del repositorio: 689 archivos Dart, 47 archivos de pruebas Flutter y fuentes públicas web (HTML/CSS/JS).
- Patrones de interfaz inspeccionados en pantallas principales y componentes compartidos: `Dialog`, `AlertDialog`, `showModalBottomSheet`, listas, dimensiones fijas y conversiones numéricas.
- Se inspeccionaron los módulos extensos de mesero/caja, reportes/pedidos, productos, inventario, eventos/reservas, roles/permisos, usuarios, suscripciones, perfil, marcas, medios de pago y navegación.
- Revisión puntual de rutas GoRouter, providers de sesión/rol/sucursal, cliente HTTP y JS/CSS del sitio público.
- No se ejecutó un barrido dinámico pantalla por pantalla. La revisión de código no puede demostrar ausencia de todos los errores.

## Defectos encontrados y corregidos en esta fase
1. **Medios de pago, mesero:** selector de otros medios de pago: usar hoja inferior de altura controlable para que una lista extensa no quede cortada.
2. **Administración de mesas:** eliminar el ancho mínimo de contenido de 280 px en los diálogos crear/editar, que excedía el ancho disponible tras los márgenes de `AlertDialog` en móviles.
3. **Roles personalizados:** impedir que el editor fuerce 320 px de altura cuando el teclado deja menos espacio.
4. **Reportes y pedidos:** en la distribución de productos por proveedor, apilar nombre y selector en pantallas angostas.
5. **Correcciones anteriores en la misma rama:** scroll responsive de perfil, ayuda contextual, gastos de caja, eventos, pedidos manuales y varios diálogos de reportes.

## Comprobaciones ejecutadas
- Lectura del árbol de GitHub y revisión de código fuente.
- Revisión de balance de delimitadores sobre los archivos Dart modificados (control auxiliar; NO sustituye el compilador).
- Se verificó que `main` tiene builds recientes exitosos, pero esos builds NO corresponden a esta rama.
- `.github/workflows/ci.yml` solo se dispara manualmente. No se encontraron ejecuciones de CI para `fix/dialogos-responsive-scroll-movil-20261030`.

## Pruebas obligatorias antes de un PR o merge
1. En GitHub Actions, ejecutar **Frontend CI (manual)** seleccionando esta rama: Docker `target: test` ejecuta `flutter analyze` y `flutter test`.
2. Ejecutar en local `flutter pub get && flutter analyze && flutter test`.
3. Pruebas visuales en anchos **320, 360, 390, 430, 768 y 1280 px**, con altura reducida y escalado de texto grande.
4. Abrir y cerrar el teclado en todos los formularios con campos: comprobar que confirmar/guardar/cancelar permanezcan accesibles sin pérdida de datos.
5. Validar permisos por rol y cambio de sucursal sin nueva sesión; comprobar accesos por enlace directo y estados de error HTTP 401, 402 y 403.
6. Probar de extremo a extremo: ventas y mesas, pagos divididos y comprobantes, inventario/conteo, pedidos/proveedor, cierre de caja, suscripción, creación/edición de productos e ingredientes, eventos y reservas con pagos reales en ambiente de prueba.
7. Compilar y probar Web, Android, iOS, Windows, Linux y macOS; revisar consola Flutter, errores de red, cámara/QR, impresoras y navegación nativa.

## Criterio de cierre
No afirmar «cero bugs» sin pruebas de compilación, pruebas automatizadas satisfactorias y QA manual por plataforma. No crear PR, fusionar en main ni desplegar hasta completar esos controles.
