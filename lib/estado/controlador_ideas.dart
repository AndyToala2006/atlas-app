import 'dart:async';

import 'package:flutter/foundation.dart';

import '../modelos/estado_permiso.dart';
import '../modelos/idea.dart';
import '../modelos/respuesta_api.dart';
import '../servicios/atlas_api.dart';
import '../servicios/notificaciones_servicio.dart';
import '../servicios/preferencias_locales.dart';
import 'controlador_sesion.dart';

/// Estado de las ideas del usuario autenticado.
///
/// Vive al mismo nivel que [ControladorSesion], fuera del árbol de pantallas.
/// Gracias a eso la lista cargada y el borrador a medio escribir sobreviven a
/// los cambios de pestaña y a las idas y vueltas al detalle de una idea: la
/// pantalla se destruye, el estado no.
///
/// Desde la Semana 14 también decide cuándo avisar con una notificación local
/// que una idea terminó de procesarse: compara el `estado` que trae cada
/// `GET /ideas` contra el que quedó guardado en [PreferenciasLocales] la
/// última vez, y dispara [NotificacionesServicio.mostrar] en la transición
/// `procesando` → `publicada`. Esa comparación funciona incluso si la
/// aplicación estuvo cerrada mientras el backend procesaba la idea, porque el
/// último estado visto vive en almacenamiento local, no en memoria.
class ControladorIdeas extends ChangeNotifier {
  ControladorIdeas({
    required AtlasApi api,
    required ControladorSesion sesion,
    required NotificacionesServicio notificaciones,
    required PreferenciasLocales preferencias,
  }) : _api = api,
       _sesion = sesion,
       _notificaciones = notificaciones,
       _preferencias = preferencias {
    unawaited(_cargarPreferenciaNotificaciones());
  }

  final AtlasApi _api;
  final ControladorSesion _sesion;
  final NotificacionesServicio _notificaciones;
  final PreferenciasLocales _preferencias;

  bool _notificacionesActivadas = false;

  List<Idea> _ideas = const [];
  bool _cargando = false;

  // Paginación y búsqueda (Semana 15). El backend entrega las ideas de
  // [tamanoPagina] en [tamanoPagina] y el total en `X-Total-Count`.
  static const int tamanoPagina = 20;
  int? _total;
  bool _cargandoMas = false;
  String _busqueda = '';
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

  /// Total de ideas que cumplen la búsqueda en el servidor, no solo las
  /// cargadas. Si el backend no lo informa, se usa lo que hay en memoria.
  int get total => _total ?? _ideas.length;
  bool get hayMas => _ideas.length < total;
  bool get cargandoMas => _cargandoMas;
  String get busqueda => _busqueda;

  /// `true` si el usuario activó el aviso de "idea publicada" Y el permiso de
  /// notificaciones sigue concedido. Se carga una sola vez, al construir el
  /// controlador, desde [PreferenciasLocales].
  bool get notificacionesActivadas => _notificacionesActivadas;

  Future<void> _cargarPreferenciaNotificaciones() async {
    _notificacionesActivadas = await _preferencias
        .leerNotificacionesActivadas();
    notifyListeners();
  }

  /// Pide el permiso de notificaciones y, si queda concedido, activa el
  /// aviso. Devuelve el [EstadoPermiso] resultante para que la pantalla de
  /// perfil decida qué diálogo mostrar (nada si se concedió, la explicación
  /// de reintentar si fue denegado, o el atajo a ajustes si quedó en
  /// denegación permanente o restringido).
  Future<EstadoPermiso> activarNotificaciones() async {
    await _notificaciones.inicializar();
    var estado = await _notificaciones.estadoPermiso();
    if (!estado.concedidoOk) {
      estado = await _notificaciones.solicitarPermiso();
    }
    _notificacionesActivadas = estado.concedidoOk;
    await _preferencias.guardarNotificacionesActivadas(
      _notificacionesActivadas,
    );
    notifyListeners();
    return estado;
  }

  Future<void> desactivarNotificaciones() async {
    _notificacionesActivadas = false;
    await _preferencias.guardarNotificacionesActivadas(false);
    notifyListeners();
  }

  Future<void> abrirAjustesDeNotificaciones() =>
      _notificaciones.abrirAjustesDeLaApp();

  String get borradorTitulo => _borradorTitulo;
  String get borradorContenido => _borradorContenido;
  String get borradorEtiquetas => _borradorEtiquetas;
  bool get hayBorrador =>
      _borradorTitulo.isNotEmpty ||
      _borradorContenido.isNotEmpty ||
      _borradorEtiquetas.isNotEmpty;

  void guardarBorrador({String? titulo, String? contenido, String? etiquetas}) {
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

  /// `GET /ideas` con el JWT del usuario en la cabecera: PRIMERA página de la
  /// búsqueda vigente. Lo que hubiera cargado antes se reemplaza.
  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await _api.listarIdeas(
        optimizado: _optimizado,
        limite: tamanoPagina,
        busqueda: _busqueda,
      );
      _ideas = respuesta.datos;
      _total = respuesta.totalElementos;
      _ultimaRespuesta = respuesta;
      await _avisarDeIdeasPublicadas(_ideas);
    } on ErrorApi catch (e) {
      _error = _traducir(e);
      _ultimaRespuesta = null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Siguiente página, que se AÑADE a la lista. No hace nada si ya está todo.
  Future<void> cargarMas() async {
    if (!hayMas || _cargandoMas || _cargando) return;
    _cargandoMas = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await _api.listarIdeas(
        optimizado: _optimizado,
        limite: tamanoPagina,
        desde: _ideas.length,
        busqueda: _busqueda,
      );
      // Si entre una página y otra se creó una idea, el desplazamiento corre una
      // posición y la primera fila de esta página ya estaba: se descarta.
      final yaCargadas = {for (final idea in _ideas) idea.id};
      _ideas = [
        ..._ideas,
        ...respuesta.datos.where((idea) => !yaCargadas.contains(idea.id)),
      ];
      _total = respuesta.totalElementos ?? _total;
      _ultimaRespuesta = respuesta;
      await _avisarDeIdeasPublicadas(respuesta.datos);
    } on ErrorApi catch (e) {
      _error = _traducir(e);
    } finally {
      _cargandoMas = false;
      notifyListeners();
    }
  }

  /// Busca en el título y el contenido de las ideas, en el servidor. Una
  /// búsqueda vacía vuelve al listado completo.
  Future<void> buscar(String texto) async {
    final limpio = texto.trim();
    if (limpio == _busqueda) return;
    _busqueda = limpio;
    await cargar();
  }

  /// Compara el `estado` recién leído contra el último que quedó guardado en
  /// [PreferenciasLocales] y notifica cada transición a "publicada".
  ///
  /// El guardado del nuevo mapa ocurre SIEMPRE, esté o no activado el aviso:
  /// así, si el usuario activa las notificaciones más tarde, no recibe un
  /// aluvión de avisos retroactivos por ideas que ya llevaban tiempo
  /// publicadas antes de que las pidiera.
  Future<void> _avisarDeIdeasPublicadas(List<Idea> ideas) async {
    final anteriores = await _preferencias.leerEstadosIdeas();

    if (_notificacionesActivadas) {
      for (final idea in ideas) {
        final estadoAnterior = anteriores[idea.id];
        if (estadoAnterior == 'procesando' && idea.estado == 'publicada') {
          await _notificaciones.mostrar(
            id: idea.id,
            titulo: 'Tu idea ya está publicada',
            cuerpo:
                '"${idea.titulo}" terminó de procesarse y tiene una '
                'publicación lista.',
          );
        }
      }
    }

    // Se FUSIONA con lo anterior en vez de reemplazarlo: con paginación cada
    // lectura trae solo una página, y reemplazar borraría el último estado
    // visto de las ideas que quedaron en otras páginas.
    await _preferencias.guardarEstadosIdeas({
      ...anteriores,
      for (final idea in ideas) idea.id: idea.estado,
    });
  }

  /// `POST /ideas`. Devuelve la idea creada o `null` si la API la rechazó.
  ///
  /// [origen] es `'audio'` cuando el contenido se dictó, en todo o en parte,
  /// con el micrófono (Taller Semana 14); por defecto es `'texto'`.
  Future<Idea?> crear({
    required String titulo,
    required String contenido,
    required List<String> etiquetas,
    String origen = 'texto',
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await _api.crearIdea(
        titulo: titulo.trim(),
        contenido: contenido.trim(),
        origen: origen,
        etiquetas: etiquetas,
      );
      _ideas = [respuesta.datos, ..._ideas];
      if (_total != null) _total = _total! + 1;
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

  /// `PATCH /ideas/{id}`. Devuelve la idea actualizada o `null` si falló.
  ///
  /// Sustituye la fila en [_ideas] CONSERVANDO SU POSICIÓN: si se reinsertara
  /// al principio, la lista daría un salto delante del usuario que solo corrigió
  /// una palabra del título. El borrador no se toca: es exclusivo del formulario
  /// de creación, y limpiarlo aquí borraría una idea nueva a medio escribir.
  Future<Idea?> editar({
    required int id,
    required String titulo,
    required String contenido,
    required List<String> etiquetas,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await _api.actualizarIdea(
        id: id,
        titulo: titulo.trim(),
        contenido: contenido.trim(),
        etiquetas: etiquetas,
      );
      _ideas = [
        for (final idea in _ideas)
          if (idea.id == id) respuesta.datos else idea,
      ];
      _ultimaRespuesta = respuesta;
      return respuesta.datos;
    } on ErrorApi catch (e) {
      _error = _traducir(e);
      return null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// `DELETE /ideas/{id}`. Devuelve `true` si el backend confirmó el borrado.
  ///
  /// La idea se quita de [_ideas] solo después del 204: si se quitara antes,
  /// un fallo de red dejaría la lista mintiendo sobre lo que hay en Postgres.
  Future<bool> eliminar(int id) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await _api.eliminarIdea(id);
      _ideas = [
        for (final idea in _ideas)
          if (idea.id != id) idea,
      ];
      if (_total != null && _total! > 0) _total = _total! - 1;
      _ultimaRespuesta = respuesta;
      return true;
    } on ErrorApi catch (e) {
      _error = _traducir(e);
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Idea ya cargada en el estado compartido, o `null` si no está en la lista.
  ///
  /// La usa el detalle para releer la versión vigente al volver de la pantalla
  /// de edición, en vez de quedarse con la copia con la que se abrió.
  Idea? ideaPorId(int id) {
    for (final idea in _ideas) {
      if (idea.id == id) return idea;
    }
    return null;
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

  /// Cambia el `estado` de una idea ya cargada sin ir al backend.
  ///
  /// Lo usa [ControladorPublicaciones] justo después del 202 de
  /// `POST /ideas/{id}/publicar`: el backend ya la pasó a "procesando" y la
  /// tarjeta del listado debe decirlo sin esperar a la próxima recarga.
  void marcarEstado(int id, String estado) {
    final actual = ideaPorId(id);
    if (actual == null || actual.estado == estado) return;
    _ideas = [
      for (final idea in _ideas)
        if (idea.id == id) idea.copiaCon(estado: estado) else idea,
    ];
    notifyListeners();
  }

  /// Notificación local de "publicación lista" al terminar una generación
  /// lanzada desde la app (Taller Semana 14 aplicado al flujo de la IA).
  ///
  /// Complementa a [_avisarDeIdeasPublicadas], que cubre el caso de la app
  /// cerrada durante el proceso. Se usa el id de la idea como id de la
  /// notificación, así que si ambos caminos avisan de lo mismo, la segunda
  /// sustituye a la primera en vez de duplicarla.
  Future<void> avisarPublicacionLista(int id) async {
    final idea = ideaPorId(id);
    if (!_notificacionesActivadas || idea == null) return;
    await _notificaciones.mostrar(
      id: id,
      titulo: 'Tu publicación está lista',
      cuerpo: 'La IA terminó de redactar "${idea.titulo}".',
    );
  }

  /// Se invoca al cerrar sesión: los datos de un usuario no pueden quedar
  /// visibles para el siguiente que inicie sesión en el mismo dispositivo.
  ///
  /// También se borra el mapa de "último estado visto" de
  /// [PreferenciasLocales]: son ids y estados de las ideas del usuario que
  /// cierra sesión, y no deberían influir en qué notificaciones dispara la
  /// cuenta que entre después en el mismo teléfono. La preferencia de
  /// notificaciones ACTIVADAS sí se conserva: es un ajuste del dispositivo,
  /// no un dato del usuario.
  void limpiar() {
    _ideas = const [];
    _total = null;
    _busqueda = '';
    _cargandoMas = false;
    _error = null;
    _ultimaRespuesta = null;
    _cargando = false;
    descartarBorrador();
    unawaited(_preferencias.guardarEstadosIdeas(const {}));
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
