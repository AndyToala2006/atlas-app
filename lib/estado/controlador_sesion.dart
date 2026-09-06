import 'dart:async';

import 'package:flutter/foundation.dart';

import '../modelos/respuesta_api.dart';
import '../modelos/usuario.dart';
import '../servicios/almacen_sesion.dart';
import '../servicios/atlas_api.dart';

/// Situación de la sesión en un momento dado.
enum EstadoSesion {
  /// Arranque: se está leyendo el token guardado en el almacén cifrado.
  comprobando,

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
/// El JWT se guarda en el almacén cifrado del sistema ([AlmacenSesion]:
/// Keystore en Android, Keychain en iOS), nunca en almacenamiento en claro.
/// Así la sesión sobrevive al cierre de la aplicación sin dejar el token
/// legible en el dispositivo.
class ControladorSesion extends ChangeNotifier {
  ControladorSesion({required AtlasApi api, required AlmacenSesion almacen})
      : _api = api,
        _almacen = almacen;

  final AtlasApi _api;
  final AlmacenSesion _almacen;

  EstadoSesion _estado = EstadoSesion.comprobando;
  Usuario? _usuario;
  String? _token;
  String? _error;
  DateTime? _iniciadaEn;
  bool _sesionRestaurada = false;

  EstadoSesion get estado => _estado;
  Usuario? get usuario => _usuario;
  String? get error => _error;
  DateTime? get iniciadaEn => _iniciadaEn;

  bool get haySesion => _estado == EstadoSesion.autenticado && _usuario != null;
  bool get ocupado => _estado == EstadoSesion.autenticando;
  bool get comprobando => _estado == EstadoSesion.comprobando;

  /// `true` cuando la sesión actual se recuperó del almacén cifrado en lugar
  /// de haberse abierto con el formulario. Se usa solo para informarlo en el
  /// perfil.
  bool get sesionRestaurada => _sesionRestaurada;

  /// Vista recortada del JWT, para mostrarlo en el perfil sin exponerlo entero.
  String? get tokenAbreviado {
    final token = _token;
    if (token == null) return null;
    return token.length <= 28 ? token : '${token.substring(0, 28)}…';
  }

  /// Se llama una vez al arrancar: si hay un token guardado, lo valida contra
  /// `GET /auth/me` y reabre la sesión. Un token caducado se descarta en
  /// silencio y la aplicación queda en el login, como si nunca hubiera estado.
  Future<void> restaurar() async {
    final guardado = await _almacen.leerToken();
    if (guardado == null || guardado.isEmpty) {
      _estado = EstadoSesion.anonimo;
      notifyListeners();
      return;
    }

    _api.token = guardado;
    try {
      final perfil = await _api.perfil();
      _token = guardado;
      _usuario = perfil.datos;
      _iniciadaEn = DateTime.now();
      _sesionRestaurada = true;
      _estado = EstadoSesion.autenticado;
    } on ErrorApi {
      await _almacen.borrarToken();
      _api.token = null;
      _estado = EstadoSesion.anonimo;
    }
    notifyListeners();
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

  /// Cierra la sesión: borra el token del cliente HTTP, del almacén cifrado y
  /// de la memoria.
  ///
  /// A partir de aquí `haySesion` es `false`, así que la guardia de rutas
  /// vuelve a bloquear las pantallas protegidas y la API deja de enviar la
  /// cabecera `Authorization`.
  Future<void> cerrarSesion() async {
    await _almacen.borrarToken();
    _api.token = null;
    _token = null;
    _usuario = null;
    _error = null;
    _iniciadaEn = null;
    _sesionRestaurada = false;
    _estado = EstadoSesion.anonimo;
    notifyListeners();
  }

  /// Termina la sesión porque el backend rechazó el token (401 en una
  /// pantalla protegida): el token expiró o dejó de ser válido.
  void expirar() {
    unawaited(_almacen.borrarToken());
    _api.token = null;
    _token = null;
    _usuario = null;
    _iniciadaEn = null;
    _sesionRestaurada = false;
    _estado = EstadoSesion.anonimo;
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
      _sesionRestaurada = false;
      _estado = EstadoSesion.autenticado;

      await _almacen.guardarToken(token.datos);
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
