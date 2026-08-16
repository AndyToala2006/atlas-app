/// Configuración de entorno de la aplicación.
///
/// La URL base de la API NO se escribe fija en el código: se inyecta al
/// compilar mediante `--dart-define`, que es el mecanismo de variables de
/// entorno de Dart/Flutter. Así, el mismo código apunta al backend local, al
/// emulador o a un servidor remoto sin modificar una sola línea.
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.4:8000
///
/// El valor por defecto corresponde al emulador de Android, donde 10.0.2.2 es
/// el alias que el emulador usa para llegar al `localhost` del computador
/// anfitrión (dentro del emulador, 127.0.0.1 es el propio dispositivo virtual).
class AppConfig {
  const AppConfig._();

  /// URL base de la API de Atlas (proyecto atlas-backend).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Nombre del entorno, solo informativo para la pantalla de diagnóstico.
  static const String entorno = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'desarrollo',
  );

  /// Tiempo máximo de espera de cada solicitud HTTP.
  static const Duration timeout = Duration(seconds: 10);

  /// `true` cuando la URL base viaja sin cifrar (http). Se usa para advertir en
  /// pantalla que esa configuración solo es válida en desarrollo.
  static bool get usaTraficoSinCifrar => apiBaseUrl.startsWith('http://');
}
