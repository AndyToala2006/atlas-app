import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../modelos/idea.dart';
import '../modelos/metrica.dart';
import '../modelos/publicacion.dart';
import '../modelos/respuesta_api.dart';
import '../servicios/atlas_api.dart';
import 'controlador_ideas.dart';
import 'controlador_panel.dart';
import 'controlador_sesion.dart';

/// Publicaciones generadas con IA y el trabajo de generación en curso.
///
/// El flujo contra el backend es asíncrono de punta a punta:
///
///   1. `POST /ideas/{id}/publicar` → 202 con el id del trabajo, al instante.
///   2. `GET /jobs/{id}` cada [intervaloConsulta] hasta `done` o `error`.
///   3. `GET /ideas/{id}/publicaciones` para traer el texto ya redactado.
///
/// Vive por encima del `Navigator`, igual que [ControladorIdeas]: si el
/// usuario sale del detalle mientras la IA redacta, la consulta sigue y la
/// publicación aparece al volver (y llega la notificación local si están
/// activadas). La pantalla se destruye, el trabajo no.
class ControladorPublicaciones extends ChangeNotifier {
  ControladorPublicaciones({
    required AtlasApi api,
    required ControladorSesion sesion,
    required ControladorIdeas ideas,
    ControladorPanel? panel,
    this.intervaloConsulta = const Duration(seconds: 2),
    this.esperaMaxima = const Duration(minutes: 2),
  }) : _api = api,
       _sesion = sesion,
       _ideas = ideas,
       _panel = panel;

  final AtlasApi _api;
  final ControladorSesion _sesion;
  final ControladorIdeas _ideas;

  /// Se avisa al panel tras cada escritura que mueve sus números (una
  /// publicación nueva, una métrica registrada).
  final ControladorPanel? _panel;

  /// Cada cuánto se pregunta al backend por el trabajo. Las pruebas lo bajan
  /// para no esperar segundos reales.
  final Duration intervaloConsulta;

  /// Tope de espera. Un modelo de lenguaje responde en segundos; si pasa de
  /// esto, lo más probable es que el worker no esté levantado, y seguir
  /// preguntando para siempre solo gastaría batería y datos.
  final Duration esperaMaxima;

  final Map<int, List<Publicacion>> _porIdea = {};
  final Set<int> _cargando = {};
  final Map<int, String> _trabajoEnCurso = {};
  final Map<int, String> _errores = {};

  /// Se incrementa al cerrar sesión. Una consulta en vuelo compara su época
  /// con la actual y se abandona si cambió: el resultado de un usuario no
  /// puede aterrizar en la sesión del siguiente.
  int _epoca = 0;

  List<Publicacion>? publicacionesDe(int ideaId) => _porIdea[ideaId];
  bool cargandoDe(int ideaId) => _cargando.contains(ideaId);
  bool generandoPara(int ideaId) => _trabajoEnCurso.containsKey(ideaId);

  /// `queued` o `processing` mientras hay un trabajo en curso para la idea.
  String? estadoTrabajoDe(int ideaId) => _trabajoEnCurso[ideaId];
  String? errorDe(int ideaId) => _errores[ideaId];

  void descartarError(int ideaId) {
    if (_errores.remove(ideaId) != null) notifyListeners();
  }

  /// `GET /ideas/{id}/publicaciones`.
  Future<void> cargar(int ideaId) async {
    final epoca = _epoca;
    _cargando.add(ideaId);
    _errores.remove(ideaId);
    notifyListeners();

    try {
      final respuesta = await _api.listarPublicaciones(ideaId);
      if (epoca != _epoca) return;
      _porIdea[ideaId] = respuesta.datos;
    } on ErrorApi catch (e) {
      if (epoca != _epoca) return;
      _errores[ideaId] = _traducir(e);
    } finally {
      if (epoca == _epoca) {
        _cargando.remove(ideaId);
        notifyListeners();
      }
    }
  }

  /// Pide a la IA una publicación para [red] y espera a que el worker la
  /// termine. Devuelve la publicación nueva, o `null` si falló o se agotó la
  /// espera (el motivo queda en [errorDe]).
  Future<Publicacion?> generar(Idea idea, RedSocial red) async {
    final id = idea.id;
    if (generandoPara(id)) return null;
    final epoca = _epoca;

    _trabajoEnCurso[id] = 'queued';
    _errores.remove(id);
    notifyListeners();

    try {
      final jobId = (await _api.publicarIdea(id, red)).datos;
      if (epoca != _epoca) return null;
      // El backend ya pasó la idea a "procesando"; se refleja en la lista sin
      // esperar a la próxima recarga para que la tarjeta no mienta.
      _ideas.marcarEstado(id, 'procesando');

      final intentos =
          esperaMaxima.inMilliseconds ~/
          math.max(1, intervaloConsulta.inMilliseconds);
      for (var i = 0; i < intentos; i++) {
        await Future<void>.delayed(intervaloConsulta);
        if (epoca != _epoca) return null;

        final trabajo = (await _api.consultarTrabajo(jobId)).datos;
        if (epoca != _epoca) return null;

        if (trabajo.fallido) {
          _errores[id] =
              trabajo.error ?? 'La IA no pudo generar la publicación.';
          // El backend devolvió la idea a su estado anterior; se relee.
          await _ideas.recargarIdea(id);
          return null;
        }
        if (trabajo.terminado) {
          await cargar(id);
          await _ideas.recargarIdea(id);
          await _ideas.avisarPublicacionLista(id);
          unawaited(_panel?.invalidar());
          return _porIdea[id]?.firstWhere(
            (p) => p.id == trabajo.publicacionId,
            orElse: () => _porIdea[id]!.first,
          );
        }
        if (_trabajoEnCurso[id] != trabajo.estado) {
          _trabajoEnCurso[id] = trabajo.estado;
          notifyListeners();
        }
      }

      _errores[id] =
          'La IA está tardando más de lo normal. Revisa que el '
          'worker del backend esté levantado y vuelve a abrir la idea en un '
          'momento: la publicación aparecerá aquí cuando termine.';
      return null;
    } on ErrorApi catch (e) {
      if (epoca == _epoca) _errores[id] = _traducir(e);
      return null;
    } finally {
      if (epoca == _epoca) {
        _trabajoEnCurso.remove(id);
        notifyListeners();
      }
    }
  }

  /// `POST /publicaciones/{id}/metricas`: registra el rendimiento actual de una
  /// publicación de [ideaId]. Devuelve `null` si se guardó, o el motivo del
  /// fallo para mostrarlo en el formulario.
  ///
  /// Tras guardar se relee la lista de publicaciones de la idea, que trae la
  /// nueva `ultima_metrica`, y se avisa al panel: el backend ya invalidó su
  /// caché y los totales de engagement cambiaron.
  Future<String?> registrarMetrica({
    required int ideaId,
    required int publicacionId,
    required int likes,
    required int comentarios,
    required int compartidos,
    required int alcance,
  }) async {
    final epoca = _epoca;
    try {
      await _api.registrarMetrica(
        publicacionId,
        likes: likes,
        comentarios: comentarios,
        compartidos: compartidos,
        alcance: alcance,
      );
    } on ErrorApi catch (e) {
      return _traducir(e);
    }
    if (epoca != _epoca) return null;
    await cargar(ideaId);
    unawaited(_panel?.invalidar());
    return null;
  }

  /// `GET /publicaciones/{id}/metricas`: evolución de una publicación.
  /// Lanza [ErrorApi] ya traducido si falla, para que la hoja lo muestre.
  Future<List<Metrica>> historial(int publicacionId) async {
    try {
      return (await _api.historialMetricas(publicacionId)).datos;
    } on ErrorApi catch (e) {
      throw ErrorApi(_traducir(e), codigoEstado: e.codigoEstado);
    }
  }

  /// Se invoca al cerrar sesión, junto con la limpieza de las ideas.
  void limpiar() {
    _epoca++;
    _porIdea.clear();
    _cargando.clear();
    _trabajoEnCurso.clear();
    _errores.clear();
    notifyListeners();
  }

  String _traducir(ErrorApi e) {
    if (e.esNoAutorizado) {
      _sesion.expirar();
      return 'La API rechazó la solicitud: la sesión ya no es válida.';
    }
    if (e.esDeRed) return '${e.mensaje}\n${e.sugerencia ?? ''}'.trim();
    return e.mensaje;
  }
}
