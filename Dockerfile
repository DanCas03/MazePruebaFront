# Imagen de desarrollo local (Docker Compose). Sirve el target web en modo
# `flutter run` (watch/hot-reload manual vía `docker attach`); no compila
# APK/IPA nativos — eso no es viable dentro de un contenedor.
FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

EXPOSE 8080

CMD ["sh", "-c", "flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080 --dart-define=API_BASE_URL=$API_BASE_URL"]
