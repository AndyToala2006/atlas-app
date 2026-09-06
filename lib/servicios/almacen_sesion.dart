import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el JWT de la sesión en el almacén cifrado del sistema operativo.
///
/// En Android se apoya en el **Keystore** (a través de `EncryptedSharedPreferences`)
/// y en iOS en el **Keychain**. Nunca se escribe en almacenamiento en claro:
/// un token en `SharedPreferences` sin cifrar es legible por cualquiera con
/// acceso al sistema de archivos en un dispositivo con root.
///
/// Se define como interfaz para poder sustituirlo en las pruebas por una
/// implementación en memoria, sin depender del canal nativo del plugin.
abstract class AlmacenSesion {
  Future<String?> leerToken();
  Future<void> guardarToken(String token);
  Future<void> borrarToken();
}

/// Implementación real, sobre `flutter_secure_storage`.
class AlmacenSesionSeguro implements AlmacenSesion {
  AlmacenSesionSeguro({FlutterSecureStorage? almacen})
      : _almacen = almacen ??
            const FlutterSecureStorage(
              // En Android el valor se guarda en EncryptedSharedPreferences,
              // cuya clave maestra vive en el Keystore del dispositivo.
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              // En iOS el Keychain solo devuelve el valor tras el primer
              // desbloqueo del terminal, y no se sincroniza con iCloud.
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const _clave = 'atlas.token';

  final FlutterSecureStorage _almacen;

  @override
  Future<String?> leerToken() async {
    try {
      return await _almacen.read(key: _clave);
    } catch (_) {
      // Si el almacén no está disponible (clave corrupta tras reinstalar, por
      // ejemplo) se trata como "no hay sesión guardada", nunca como un fallo
      // que impida abrir la aplicación.
      return null;
    }
  }

  @override
  Future<void> guardarToken(String token) async {
    try {
      await _almacen.write(key: _clave, value: token);
    } catch (_) {
      // La sesión sigue viva en memoria aunque no se haya podido persistir.
    }
  }

  @override
  Future<void> borrarToken() async {
    try {
      await _almacen.delete(key: _clave);
    } catch (_) {
      // Nada que hacer: el token de memoria se borra igual al cerrar sesión.
    }
  }
}

/// Implementación en memoria, para las pruebas de widget.
class AlmacenSesionEnMemoria implements AlmacenSesion {
  AlmacenSesionEnMemoria({String? tokenInicial}) : _token = tokenInicial;

  String? _token;

  @override
  Future<String?> leerToken() async => _token;

  @override
  Future<void> guardarToken(String token) async => _token = token;

  @override
  Future<void> borrarToken() async => _token = null;
}
