# Corrección: emprId al registrar sucursales desde empresa

Se agregó `emprId` al payload del formulario guiado de sucursales como respaldo de compatibilidad.

El flujo correcto es:

```http
POST /api/v1/empresas/{empresaId}/sucursales
```

El backend debe tomar la empresa desde el path. El frontend lo envía adicionalmente para evitar errores en versiones del backend que todavía validan `SucursalRequest.emprId` antes de asignarlo.
