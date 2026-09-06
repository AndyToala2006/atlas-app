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
  /// ADVERTENCIA: un valor pasado por `--dart-define` queda compilado dentro
  /// del binario y es extraíble de la APK. Sirve para mantenerlo FUERA del
  /// repositorio, no para guardar secretos. Aquí solo viaja la contraseña de
  /// una cuenta de demostración desechable; una credencial real jamás debe
  /// inyectarse por esta vía.
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

  /// Comprueba la configuración al arrancar y devuelve el motivo del fallo, o
  /// `null` si todo es correcto.
  ///
  /// Una URL base mal formada no produce un error entendible: produce fallos
  /// de red confusos en cada pantalla. Es preferible detectarlo una sola vez,
  /// al inicio, y decirlo con claridad.
  static String? validar() {
    if (apiBaseUrl.trim().isEmpty) {
      return 'API_BASE_URL está vacía. Lanza la aplicación con '
          '--dart-define=API_BASE_URL=http://IP:8000';
    }
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'API_BASE_URL no es una URL válida: "$apiBaseUrl". '
          'Debe incluir el esquema y el host, por ejemplo http://192.168.1.20:8000';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'API_BASE_URL usa el esquema "${uri.scheme}", que no es admitido. '
          'Usa http en desarrollo o https en producción.';
    }
    if (apiBaseUrl.endsWith('/')) {
      return 'API_BASE_URL no debe terminar en "/": las rutas ya lo incluyen.';
    }
    return null;
  }
}
