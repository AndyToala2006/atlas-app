import 'package:flutter/foundation.dart';

import '../modelos/respuesta_api.dart';
import '../modelos/usuario.dart';
import '../servicios/atlas_api.dart';

/// Situación de la sesión en un momento dado.
enum EstadoSesion {
  /// Nadie ha iniciado sesión: solo se puede ver login, registro y diagnóstico.
  anonimo,

  /// Hay una petición de login o de registro en curso.
  autenticando,

  /// Credenciales validadas por el backend y perfil cargado.
  autenticado,
}

/// Fuente única de verdad de la sesión del usuario.
///
/// Es un [ChangeNotifier]: guarda el estado y avisa a quien lo escuche cuando
/// cambia. Se crea una sola vez en `main.dart`, vive por encima del navegador
/// y se alcanza desde cualquier pantalla con `AmbitoAtlas.sesionDe(context)`.
/// Por eso el usuario autenticado no se pierde al cambiar de pantalla: el
/// estado no vive dentro de ningún widget, sino fuera de todos ellos.
///
/// La sesión se mantiene en memoria durante la ejecución de la aplicación. No
/// se escribe en disco de forma deliberada: un JWT guardado en el dispositivo
/// exige almacenamiento cifrado y una política de expiración, que es trabajo
/// de una entrega posterior.
class ControladorSesion extends ChangeNotifier {
  ControladorSesion({required AtlasApi api}) : _api = api;

  final AtlasApi _api;

  EstadoSesion _estado = EstadoSesion.anonimo;
  Usuario? _usuario;
  String? _token;
  String? _error;
  DateTime? _iniciadaEn;

  EstadoSesion get estado => _estado;
  Usuario? get usuario => _usuario;
  String? get error => _error;
  DateTime? get iniciadaEn => _iniciadaEn;

  bool get haySesion => _estado == EstadoSesion.autenticado && _usuario != null;
  bool get ocupado => _estado == EstadoSesion.autenticando;

  /// Vista recortada del JWT, para mostrarlo en el perfil sin exponerlo entero.
  String? get tokenAbreviado {
    final token = _token;
    if (token == null) return null;
    return token.length <= 28 ? token : '${token.substring(0, 28)}…';
  }

  /// `POST /auth/login` seguido de `GET /auth/me`.
  ///
  /// Devuelve `true` si la sesión quedó abierta. El mensaje de un intento
  /// fallido queda en [error] para que el formulario lo muestre.
  Future<bool> iniciarSesion({
    required String email,
    required String password,
  }) {
    return _autenticar(
      () => _api.iniciarSesion(email: email.trim(), password: password),
    );
  }

  /// `POST /auth/register`: crea la cuenta y deja la sesión iniciada.
  Future<bool> registrar({
    required String nombre,
    required String email,
    required String password,
    required String tono,
  }) {
    return _autenticar(
      () => _api.registrar(
        email: email.trim(),
        nombre: nombre.trim(),
        password: password,
        tono: tono,
      ),
    );
  }

  /// Cierra la sesión: borra el token del cliente HTTP y la identidad local.
  ///
  /// A partir de aquí `haySesion` es `false`, así que la guardia de rutas
  /// vuelve a bloquear las pantallas protegidas y la API deja de enviar la
  /// cabecera `Authorization`.
  void cerrarSesion() {
    _api.token = null;
    _token = null;
    _usuario = null;
    _error = null;
    _iniciadaEn = null;
    _estado = EstadoSesion.anonimo;
    notifyListeners();
  }

  /// Termina la sesión porque el backend rechazó el token (401 en una
  /// pantalla protegida): el token expiró o dejó de ser válido.
  void expirar() {
    cerrarSesion();
    _error = 'Tu sesión expiró. Vuelve a iniciar sesión para continuar.';
    notifyListeners();
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _autenticar(
    Future<RespuestaApi<String>> Function() peticion,
  ) async {
    _estado = EstadoSesion.autenticando;
    _error = null;
    notifyListeners();

    try {
      final token = await peticion();
      _api.token = token.datos;
      _token = token.datos;

      final perfil = await _api.perfil();
      _usuario = perfil.datos;
      _iniciadaEn = DateTime.now();
      _estado = EstadoSesion.autenticado;
      notifyListeners();
      return true;
    } on ErrorApi catch (e) {
      _api.token = null;
      _token = null;
      _usuario = null;
      _estado = EstadoSesion.anonimo;
      _error = _traducir(e);
      notifyListeners();
      return false;
    }
  }

  /// Convierte el error de la API en un mensaje que el usuario entienda.
  static String _traducir(ErrorApi e) {
    if (e.esNoAutorizado) {
      return 'Correo o contraseña incorrectos. Revisa los datos e inténtalo otra vez.';
    }
    if (e.esConflicto) {
      return 'Ese correo ya tiene una cuenta. Inicia sesión o usa otro correo.';
    }
    if (e.esValidacion) {
      return 'El servidor rechazó los datos:\n${e.mensaje}';
    }
    if (e.esDeRed) {
      return '${e.mensaje}\n${e.sugerencia ?? ''}'.trim();
    }
    return e.mensaje;
  }
}
