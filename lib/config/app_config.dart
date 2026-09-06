/// Configuración de entorno de la aplicación.
///
/// La URL base de la API NO se escribe fija en el código: se inyecta al
/// compilar mediante `--dart-define`, que es el mecanismo de variables de
/// entorno de Dart/Flutter. Así, el mismo código apunta al backend local, al
/// emulador o a un servidor remoto sin modificar una sola línea.
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.100.116:8000
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

  /// Credenciales de la cuenta de demostración, usadas por el botón que
  /// rellena el formulario de login durante una presentación.
  ///
  /// NO se escriben en el código ni se versionan: se inyectan al compilar, del
  /// mismo modo que la URL base. Si no se pasan, el botón no aparece y el
  /// formulario se llena a mano.
  ///
  ///   flutter run --dart-define=DEMO_EMAIL=... --dart-define=DEMO_PASSWORD=...
  static const String demoEmail = String.fromEnvironment('DEMO_EMAIL');
  static const String demoPassword = String.fromEnvironment('DEMO_PASSWORD');

  /// `true` cuando se inyectaron ambas credenciales de demostración.
  static bool get hayCredencialesDemo =>
      demoEmail.isNotEmpty && demoPassword.isNotEmpty;

  /// Tonos de redacción admitidos por el backend al crear una cuenta
  /// (`PerfilTono.nombre`). El primero es el valor por defecto.
  static const List<String> tonos = ['cercano', 'profesional', 'inspirador'];

  /// `true` cuando la URL base viaja sin cifrar (http). Se usa para advertir en
  /// pantalla que esa configuración solo es válida en desarrollo.
  static bool get usaTraficoSinCifrar => apiBaseUrl.startsWith('http://');
}
