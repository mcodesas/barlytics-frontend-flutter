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
RUN if [ -n "$API_BASE_URL" ]; then \
      flutter build web --release \
        --dart-define=ENV="$APP_ENV" \
        --dart-define=API_BASE_URL="$API_BASE_URL"; \
    else \
      flutter build web --release \
        --dart-define=ENV="$APP_ENV"; \
    fi

FROM nginx:1.27-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O - http://127.0.0.1/healthz >/dev/null || exit 1
