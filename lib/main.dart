import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'estado/ambito_atlas.dart';
import 'estado/controlador_ideas.dart';
import 'estado/controlador_panel.dart';
import 'estado/controlador_sesion.dart';
import 'pantallas/pantalla_carga.dart';
import 'rutas/rutas.dart';
import 'servicios/almacen_sesion.dart';
import 'servicios/atlas_api.dart';
import 'tema/tema_atlas.dart';

void main() => runApp(const AtlasApp());

/// Atlas — cliente móvil del proyecto integrador.
///
/// Taller Semana 12: autenticación, navegación por rutas con nombre, manejo
/// de estado y formularios validados.
///
/// El árbol queda así, de fuera hacia dentro:
///
///   AtlasApp            crea el cliente HTTP, el almacén y los controladores
///     AmbitoAtlas       los reparte a toda la aplicación (InheritedWidget)
///       MaterialApp     navegación por rutas con nombre (`Rutas.generar`)
///         GuardiaSesion envuelve cada ruta privada y exige sesión abierta
///
/// El estado vive por ENCIMA del `Navigator`. Esa es la razón de que el
/// usuario autenticado, la lista de ideas y el borrador a medio escribir
/// sigan intactos al cambiar de pantalla: las pantallas se crean y se
/// destruyen, los controladores no.
class AtlasApp extends StatefulWidget {
  const AtlasApp({super.key, this.api, this.almacen});

  /// Permite inyectar un cliente con `http.Client` simulado en las pruebas.
  final AtlasApi? api;

  /// Permite sustituir el almacén cifrado por uno en memoria en las pruebas.
  final AlmacenSesion? almacen;

  @override
  State<AtlasApp> createState() => _AtlasAppState();
}

class _AtlasAppState extends State<AtlasApp> {
  late final AtlasApi _api = widget.api ?? AtlasApi();
  late final AlmacenSesion _almacen = widget.almacen ?? AlmacenSesionSeguro();

  late final ControladorSesion _sesion =
      ControladorSesion(api: _api, almacen: _almacen);
  late final ControladorIdeas _ideas =
      ControladorIdeas(api: _api, sesion: _sesion);
  late final ControladorPanel _panel =
      ControladorPanel(api: _api, sesion: _sesion);

  /// Motivo por el que la configuración es inválida, o `null` si es correcta.
  final String? _errorConfiguracion = AppConfig.validar();

  final _navegador = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Al terminar la sesión —por cierre voluntario o por token expirado— se
    // descartan los datos del usuario anterior, para que no queden a la vista
    // de quien inicie sesión después en el mismo dispositivo.
    _sesion.addListener(_alCambiarSesion);

    if (_errorConfiguracion == null) {
      // Se lee el token guardado y, si sigue siendo válido, se reabre la
      // sesión antes de decidir a qué pantalla entra el usuario.
      WidgetsBinding.instance.addPostFrameCallback((_) => _arrancar());
    }
  }

  Future<void> _arrancar() async {
    await _sesion.restaurar();
    final navegador = _navegador.currentState;
    if (navegador == null) return;
    navegador.pushNamedAndRemoveUntil(
      _sesion.haySesion ? Rutas.inicio : Rutas.login,
      (_) => false,
    );
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
    final motivo = _errorConfiguracion;

    return AmbitoAtlas(
      api: _api,
      sesion: _sesion,
      ideas: _ideas,
      panel: _panel,
      child: MaterialApp(
        title: 'Atlas',
        debugShowCheckedModeBanner: false,
        theme: TemaAtlas.claro(),
        darkTheme: TemaAtlas.oscuro(),
        themeMode: ThemeMode.system,
        navigatorKey: _navegador,
        // Una URL base mal formada se detecta una sola vez, al arrancar, en
        // lugar de producir errores de red confusos en cada pantalla.
        home: motivo == null
            ? null
            : PantallaConfiguracionInvalida(motivo: motivo),
        initialRoute: motivo == null ? Rutas.rutaInicial : null,
        onGenerateRoute: motivo == null ? Rutas.generar : null,
      ),
    );
  }
}
