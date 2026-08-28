# Cambios de despliegue a produccion

- Dockerfile multi-stage para Flutter Web + Nginx.
- Nginx configurado para SPA, cache control y health check.
- En Web/produccion la API usa el mismo origen del navegador y Caddy enruta `/api/*` hacia Spring Boot.
- GitHub Actions para analisis/pruebas en Pull Requests y despliegue automatico despues del merge a `main`.
- La imagen Flutter queda compilada en modo `prod` y publicada en GHCR con tags `latest` y `sha-<commit>`.
