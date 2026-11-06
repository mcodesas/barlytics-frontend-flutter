FROM ghcr.io/cirruslabs/flutter:3.41.9 AS base
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .

FROM base AS test
RUN flutter analyze --no-fatal-infos --no-fatal-warnings
RUN if [ -d "test" ]; then \
      flutter test; \
    else \
      echo "No existen pruebas Flutter; se omite flutter test"; \
    fi

FROM base AS build
ARG APP_ENV=prod
ARG API_BASE_URL=
ARG BARLYTICS_APP_VERSION=1.0.0
ARG BARLYTICS_APP_BUILD=1
RUN if [ -n "$API_BASE_URL" ]; then \
      flutter build web --release \
        --dart-define=ENV="$APP_ENV" \
        --dart-define=BARLYTICS_APP_VERSION="$BARLYTICS_APP_VERSION" \
        --dart-define=BARLYTICS_APP_BUILD="$BARLYTICS_APP_BUILD" \
        --dart-define=API_BASE_URL="$API_BASE_URL"; \
    else \
      flutter build web --release \
        --dart-define=ENV="$APP_ENV" \
        --dart-define=BARLYTICS_APP_VERSION="$BARLYTICS_APP_VERSION" \
        --dart-define=BARLYTICS_APP_BUILD="$BARLYTICS_APP_BUILD"; \
    fi

# Flutter conserva los recursos de web/, pero esta copia explícita garantiza que
# las páginas SEO y sus recursos estén siempre presentes en la imagen final.
RUN set -eux; \
    cp web/robots.txt web/sitemap.xml build/web/; \
    rm -rf build/web/public-site; \
    cp -R web/public-site build/web/public-site; \
    mkdir -p build/web/downloads; \
    if [ -d web/downloads ]; then cp -R web/downloads/. build/web/downloads/; fi; \
    for page in software-para-bares funcionalidades planes descargas contacto preguntas-frecuentes; do \
      mkdir -p "build/web/$page"; \
      cp "web/$page/index.html" "build/web/$page/index.html"; \
    done

FROM nginx:1.27-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O - http://127.0.0.1/healthz >/dev/null || exit 1
