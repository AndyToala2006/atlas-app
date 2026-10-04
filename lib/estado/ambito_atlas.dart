import 'package:flutter/widgets.dart';

import '../servicios/atlas_api.dart';
import '../servicios/voz_servicio.dart';
import 'controlador_ideas.dart';
import 'controlador_panel.dart';
import 'controlador_publicaciones.dart';
import 'controlador_sesion.dart';

/// Punto de acceso al estado de la aplicación desde cualquier pantalla.
///
/// Es un [InheritedWidget] colocado por encima del `Navigator`, así que todas
/// las rutas —las de la barra inferior y las abiertas con `push`— leen los
/// mismos controladores. Ese es el mecanismo de manejo de estado del
/// proyecto: `ChangeNotifier` para guardar y notificar, `InheritedWidget` para
/// repartir, `ListenableBuilder` para redibujar solo lo que depende del dato.
///
/// Se resuelve con las herramientas del propio Flutter, sin paquetes de
/// terceros: la aplicación tiene tres piezas de estado bien delimitadas y
/// añadir una dependencia externa no aportaría nada que este esquema no cubra.
class AmbitoAtlas extends InheritedWidget {
  const AmbitoAtlas({
    super.key,
    required this.api,
    required this.sesion,
    required this.ideas,
    required this.panel,
    required this.publicaciones,
    required this.voz,
    required super.child,
  });

  /// Cliente HTTP compartido. Las pantallas usan los controladores; solo la de
  /// diagnóstico lo necesita directamente, porque `GET /health` no pertenece a
  /// ningún estado de la aplicación.
  final AtlasApi api;

  final ControladorSesion sesion;
  final ControladorIdeas ideas;
  final ControladorPanel panel;

  /// Publicaciones generadas con IA y el trabajo de generación en curso
  /// (Semana 15).
  final ControladorPublicaciones publicaciones;

  /// Dictado por voz (Taller Semana 14). No es un `ChangeNotifier`: la
  /// escucha es una interacción efímera de una sola pantalla (el formulario
  /// de nueva idea), no un dato que deba sobrevivir a la navegación como sí
  /// pasa con la sesión, las ideas o el panel.
  final VozServicio voz;

  static AmbitoAtlas de(BuildContext context) {
    final ambito = context.dependOnInheritedWidgetOfExactType<AmbitoAtlas>();
    assert(ambito != null, 'No hay un AmbitoAtlas por encima de este widget.');
    return ambito!;
  }

  /// Igual que [de], pero sin registrar dependencia. Es la forma válida de
  /// alcanzar los controladores desde `initState`, donde todavía no se puede
  /// depender de un `InheritedWidget`.
  static AmbitoAtlas leer(BuildContext context) {
    final ambito = context.getInheritedWidgetOfExactType<AmbitoAtlas>();
    assert(ambito != null, 'No hay un AmbitoAtlas por encima de este widget.');
    return ambito!;
  }

  static ControladorSesion sesionDe(BuildContext context) => de(context).sesion;
  static ControladorIdeas ideasDe(BuildContext context) => de(context).ideas;
  static ControladorPanel panelDe(BuildContext context) => de(context).panel;
  static ControladorPublicaciones publicacionesDe(BuildContext context) =>
      de(context).publicaciones;
  static VozServicio vozDe(BuildContext context) => de(context).voz;

  /// Los controladores son las mismas instancias durante toda la ejecución;
  /// quien necesita enterarse de un cambio escucha al `ChangeNotifier`, no a
  /// este widget.
  @override
  bool updateShouldNotify(AmbitoAtlas oldWidget) =>
      api != oldWidget.api ||
      sesion != oldWidget.sesion ||
      ideas != oldWidget.ideas ||
      panel != oldWidget.panel ||
      publicaciones != oldWidget.publicaciones ||
      voz != oldWidget.voz;
}
