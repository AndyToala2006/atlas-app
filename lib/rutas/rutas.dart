import 'package:flutter/material.dart';

import '../modelos/idea.dart';
import '../pantallas/pantalla_carga.dart';
import '../pantallas/pantalla_conexion.dart';
import '../pantallas/pantalla_detalle_idea.dart';
import '../pantallas/pantalla_inicio.dart';
import '../pantallas/pantalla_login.dart';
import '../pantallas/pantalla_nueva_idea.dart';
import '../pantallas/pantalla_registro.dart';
import 'guardia_sesion.dart';

/// Tabla de rutas de Atlas.
///
/// La navegación es por rutas con nombre y un único `onGenerateRoute`. Tenerla
/// en un solo archivo deja a la vista qué pantallas son públicas y cuáles
/// exigen sesión: las protegidas se construyen envueltas en [GuardiaSesion],
/// así que no existe forma de llegar a ellas sin pasar por la comprobación,
/// venga la navegación de un botón, de un `pushNamed` suelto o de un error.
class Rutas {
  const Rutas._();

  /// Arranque: se comprueba si hay una sesión guardada en el almacén cifrado.
  static const String carga = '/';

  // Públicas
  static const String login = '/login';
  static const String registro = '/registro';
  static const String diagnostico = '/diagnostico';

  // Protegidas
  static const String inicio = '/inicio';
  static const String nuevaIdea = '/ideas/nueva';
  static const String detalleIdea = '/ideas/detalle';

  static const String rutaInicial = carga;

  static Route<dynamic> generar(RouteSettings ajustes) {
    switch (ajustes.name) {
      case carga:
        return _ruta(const PantallaCarga(), ajustes);

      case login:
        return _ruta(const PantallaLogin(), ajustes);

      case registro:
        return _ruta(const PantallaRegistro(), ajustes);

      case diagnostico:
        return _ruta(const PantallaConexion(), ajustes);

      case inicio:
        return _ruta(const GuardiaSesion(child: PantallaInicio()), ajustes);

      case nuevaIdea:
        return _ruta(const GuardiaSesion(child: PantallaNuevaIdea()), ajustes);

      case detalleIdea:
        final idea = ajustes.arguments;
        if (idea is! Idea) return _ruta(const _RutaInvalida(), ajustes);
        return _ruta(
          GuardiaSesion(child: PantallaDetalleIdea(idea: idea)),
          ajustes,
        );

      default:
        return _ruta(const _RutaInvalida(), ajustes);
    }
  }

  static MaterialPageRoute<dynamic> _ruta(Widget pantalla, RouteSettings ajustes) =>
      MaterialPageRoute<dynamic>(builder: (_) => pantalla, settings: ajustes);
}

/// Pantalla de respaldo para un nombre de ruta que no existe.
class _RutaInvalida extends StatelessWidget {
  const _RutaInvalida();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pantalla no encontrada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.help_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                'La ruta solicitada no está registrada en la aplicación.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(Rutas.login, (_) => false),
                child: const Text('Volver al inicio de sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
