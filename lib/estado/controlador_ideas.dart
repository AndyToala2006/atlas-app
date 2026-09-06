import 'package:flutter/foundation.dart';

import '../modelos/idea.dart';
import '../modelos/respuesta_api.dart';
import '../servicios/atlas_api.dart';
import 'controlador_sesion.dart';

/// Estado de las ideas del usuario autenticado.
///
/// Vive al mismo nivel que [ControladorSesion], fuera del árbol de pantallas.
/// Gracias a eso la lista cargada y el borrador a medio escribir sobreviven a
/// los cambios de pestaña y a las idas y vueltas al detalle de una idea: la
/// pantalla se destruye, el estado no.
class ControladorIdeas extends ChangeNotifier {
  ControladorIdeas({required AtlasApi api, required ControladorSesion sesion})
      : _api = api,
        _sesion = sesion;

  final AtlasApi _api;
  final ControladorSesion _sesion;

  List<Idea> _ideas = const [];
  bool _cargando = false;
  bool _optimizado = true;
  String? _error;
  RespuestaApi<Object?>? _ultimaRespuesta;

  // Borrador del formulario de nueva idea. Se guarda aquí, y no dentro de la
  // pantalla, para poder demostrar que el estado no se pierde al navegar.
  String _borradorTitulo = '';
  String _borradorContenido = '';
  String _borradorEtiquetas = '';

  List<Idea> get ideas => List.unmodifiable(_ideas);
  bool get cargando => _cargando;
  bool get optimizado => _optimizado;
  String? get error => _error;
  RespuestaApi<Object?>? get ultimaRespuesta => _ultimaRespuesta;
  bool get hayDatos => _ideas.isNotEmpty;

  String get borradorTitulo => _borradorTitulo;
  String get borradorContenido => _borradorContenido;
  String get borradorEtiquetas => _borradorEtiquetas;
  bool get hayBorrador =>
      _borradorTitulo.isNotEmpty ||
      _borradorContenido.isNotEmpty ||
      _borradorEtiquetas.isNotEmpty;

  void guardarBorrador({
    String? titulo,
    String? contenido,
    String? etiquetas,
  }) {
    _borradorTitulo = titulo ?? _borradorTitulo;
    _borradorContenido = contenido ?? _borradorContenido;
    _borradorEtiquetas = etiquetas ?? _borradorEtiquetas;
    notifyListeners();
  }

  void descartarBorrador() {
    _borradorTitulo = '';
    _borradorContenido = '';
    _borradorEtiquetas = '';
    notifyListeners();
  }

  void cambiarOptimizado(bool valor) {
    _optimizado = valor;
    notifyListeners();
  }

  /// `GET /ideas` con el JWT del usuario en la cabecera.
  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await _api.listarIdeas(optimizado: _optimizado);
      _ideas = respuesta.datos;
      _ultimaRespuesta = respuesta;
    } on ErrorApi catch (e) {
      _error = _traducir(e);
      _ultimaRespuesta = null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// `POST /ideas`. Devuelve la idea creada o `null` si la API la rechazó.
  Future<Idea?> crear({
    required String titulo,
    required String contenido,
    required List<String> etiquetas,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await _api.crearIdea(
        titulo: titulo.trim(),
        contenido: contenido.trim(),
        etiquetas: etiquetas,
      );
      _ideas = [respuesta.datos, ..._ideas];
      _ultimaRespuesta = respuesta;
      descartarBorrador();
      return respuesta.datos;
    } on ErrorApi catch (e) {
      _error = _traducir(e);
      return null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// `GET /ideas/{id}`: vuelve a leer una idea concreta desde la base.
  Future<Idea?> recargarIdea(int id) async {
    try {
      final respuesta = await _api.obtenerIdea(id);
      _ideas = [
        for (final idea in _ideas)
          if (idea.id == id) respuesta.datos else idea,
      ];
      notifyListeners();
      return respuesta.datos;
    } on ErrorApi catch (e) {
      _error = _traducir(e);
      notifyListeners();
      return null;
    }
  }

  /// Se invoca al cerrar sesión: los datos de un usuario no pueden quedar
  /// visibles para el siguiente que inicie sesión en el mismo dispositivo.
  void limpiar() {
    _ideas = const [];
    _error = null;
    _ultimaRespuesta = null;
    _cargando = false;
    descartarBorrador();
  }

  /// Un 401 aquí significa token vencido: se cierra la sesión y la guardia de
  /// rutas devuelve al usuario al formulario de login.
  String _traducir(ErrorApi e) {
    if (e.esNoAutorizado) {
      _sesion.expirar();
      return 'La API rechazó la solicitud: la sesión ya no es válida.';
    }
    if (e.esDeRed) return '${e.mensaje}\n${e.sugerencia ?? ''}'.trim();
    return e.mensaje;
  }
}
