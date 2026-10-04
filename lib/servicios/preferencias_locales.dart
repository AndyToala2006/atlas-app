import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistencia local NO sensible: preferencias de la aplicación y el último
/// estado conocido de cada idea.
///
/// Es una interfaz por la misma razón que [AlmacenSesion]
/// (`servicios/almacen_sesion.dart`): las pruebas de widget la sustituyen por
/// una implementación en memoria, sin depender del canal nativo del plugin.
/// La diferencia con el almacén cifrado es deliberada: el JWT es un secreto y
/// vive en el Keystore/Keychain; esto no es secreto, es la comodidad de
/// recordar una preferencia entre arranques, así que le basta
/// `SharedPreferences`.
abstract class PreferenciasLocales {
  /// `true` si el usuario activó el aviso de "idea publicada".
  Future<bool> leerNotificacionesActivadas();
  Future<void> guardarNotificacionesActivadas(bool valor);

  /// Último `estado` (`borrador`, `procesando`, `publicada`) visto para cada
  /// id de idea. `ControladorIdeas` lo compara contra la respuesta de
  /// `GET /ideas` para detectar el cambio a "publicada" y disparar la
  /// notificación local, incluso si la aplicación estuvo cerrada mientras el
  /// backend terminaba de procesarla.
  Future<Map<int, String>> leerEstadosIdeas();
  Future<void> guardarEstadosIdeas(Map<int, String> estados);
}

class PreferenciasLocalesSharedPreferences implements PreferenciasLocales {
  static const _claveNotificaciones = 'atlas.notificaciones_activadas';
  static const _claveEstadosIdeas = 'atlas.estados_ideas';

  @override
  Future<bool> leerNotificacionesActivadas() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_claveNotificaciones) ?? false;
  }

  @override
  Future<void> guardarNotificacionesActivadas(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveNotificaciones, valor);
  }

  @override
  Future<Map<int, String>> leerEstadosIdeas() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_claveEstadosIdeas);
    if (crudo == null || crudo.isEmpty) return {};
    try {
      final mapa = jsonDecode(crudo) as Map<String, dynamic>;
      return mapa.map((clave, valor) => MapEntry(int.parse(clave), '$valor'));
    } catch (_) {
      // Formato corrupto de una versión anterior: se trata como si no hubiera
      // historial, nunca como un fallo que bloquee la lista de ideas.
      return {};
    }
  }

  @override
  Future<void> guardarEstadosIdeas(Map<int, String> estados) async {
    final prefs = await SharedPreferences.getInstance();
    final serializable = estados.map((id, estado) => MapEntry('$id', estado));
    await prefs.setString(_claveEstadosIdeas, jsonEncode(serializable));
  }
}

/// Implementación en memoria, para las pruebas de widget.
class PreferenciasLocalesEnMemoria implements PreferenciasLocales {
  PreferenciasLocalesEnMemoria({bool notificacionesActivadas = false})
    : _notificacionesActivadas = notificacionesActivadas;

  bool _notificacionesActivadas;
  Map<int, String> _estadosIdeas = {};

  @override
  Future<bool> leerNotificacionesActivadas() async => _notificacionesActivadas;

  @override
  Future<void> guardarNotificacionesActivadas(bool valor) async =>
      _notificacionesActivadas = valor;

  @override
  Future<Map<int, String>> leerEstadosIdeas() async =>
      Map.unmodifiable(_estadosIdeas);

  @override
  Future<void> guardarEstadosIdeas(Map<int, String> estados) async =>
      _estadosIdeas = Map.of(estados);
}
