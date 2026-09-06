import 'package:flutter/foundation.dart';

import '../modelos/metricas_panel.dart';
import '../modelos/respuesta_api.dart';
import '../servicios/atlas_api.dart';
import 'controlador_sesion.dart';

/// Estado del panel de métricas (`GET /dashboard/metricas`).
///
/// Igual que los otros controladores, conserva el último reporte recibido, de
/// modo que al volver a la pestaña el usuario ve los datos que ya tenía en
/// lugar de una pantalla vacía y una nueva llamada a la API.
class ControladorPanel extends ChangeNotifier {
  ControladorPanel({required AtlasApi api, required ControladorSesion sesion})
      : _api = api,
        _sesion = sesion;

  final AtlasApi _api;
  final ControladorSesion _sesion;

  MetricasPanel? _metricas;
  RespuestaApi<Object?>? _ultimaRespuesta;
  bool _cargando = false;
  String? _error;

  MetricasPanel? get metricas => _metricas;
  RespuestaApi<Object?>? get ultimaRespuesta => _ultimaRespuesta;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await _api.metricas();
      _metricas = respuesta.datos;
      _ultimaRespuesta = respuesta;
    } on ErrorApi catch (e) {
      if (e.esNoAutorizado) {
        _sesion.expirar();
        _error = 'La API rechazó la solicitud: la sesión ya no es válida.';
      } else {
        _error = e.esDeRed ? '${e.mensaje}\n${e.sugerencia ?? ''}'.trim() : e.mensaje;
      }
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void limpiar() {
    _metricas = null;
    _ultimaRespuesta = null;
    _error = null;
    _cargando = false;
  }
}
