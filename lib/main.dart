import 'package:flutter/material.dart';

import 'estado/ambito_atlas.dart';
import 'estado/controlador_ideas.dart';
import 'estado/controlador_panel.dart';
import 'estado/controlador_sesion.dart';
import 'rutas/rutas.dart';
import 'servicios/atlas_api.dart';

void main() => runApp(const AtlasApp());

/// Atlas — cliente móvil del proyecto integrador.
///
/// Taller Semana 10: autenticación, navegación por rutas con nombre, manejo
/// de estado y formularios validados.
///
/// El árbol queda así, de fuera hacia dentro:
///
///   AtlasApp            crea el cliente HTTP y los tres controladores
///     AmbitoAtlas       los reparte a toda la aplicación (InheritedWidget)
///       MaterialApp     navegación por rutas con nombre (`Rutas.generar`)
///         GuardiaSesion envuelve cada ruta privada y exige sesión abierta
///
/// El estado vive por ENCIMA del `Navigator`. Esa es la razón de que el
/// usuario autenticado, la lista de ideas y el borrador a medio escribir
/// sigan intactos al cambiar de pantalla: las pantallas se crean y se
/// destruyen, los controladores no.
class AtlasApp extends StatefulWidget {
  const AtlasApp({super.key, this.api});

  /// Permite inyectar un cliente con `http.Client` simulado en las pruebas.
  final AtlasApi? api;

  @override
  State<AtlasApp> createState() => _AtlasAppState();
}

class _AtlasAppState extends State<AtlasApp> {
  late final AtlasApi _api = widget.api ?? AtlasApi();
  late final ControladorSesion _sesion = ControladorSesion(api: _api);
  late final ControladorIdeas _ideas =
      ControladorIdeas(api: _api, sesion: _sesion);
  late final ControladorPanel _panel =
      ControladorPanel(api: _api, sesion: _sesion);

  @override
  void initState() {
    super.initState();
    // Al terminar la sesión —por cierre voluntario o por token expirado— se
    // descartan los datos del usuario anterior, para que no queden a la vista
    // de quien inicie sesión después en el mismo dispositivo.
    _sesion.addListener(_alCambiarSesion);
  }

  void _alCambiarSesion() {
    if (_sesion.haySesion) return;
    _ideas.limpiar();
    _panel.limpiar();
  }

  @override
  void dispose() {
    _sesion.removeListener(_alCambiarSesion);
    _panel.dispose();
    _ideas.dispose();
    _sesion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AmbitoAtlas(
      api: _api,
      sesion: _sesion,
      ideas: _ideas,
      panel: _panel,
      child: MaterialApp(
        title: 'Atlas',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D5AFE)),
          useMaterial3: true,
        ),
        initialRoute: Rutas.rutaInicial,
        onGenerateRoute: Rutas.generar,
      ),
    );
  }
}
