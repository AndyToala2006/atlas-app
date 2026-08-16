import 'package:flutter/material.dart';

import 'api/atlas_api.dart';
import 'pantallas/pantalla_conexion.dart';
import 'pantallas/pantalla_ideas.dart';
import 'pantallas/pantalla_sesion.dart';

void main() => runApp(const AtlasApp());

/// Atlas — cliente móvil del proyecto integrador.
///
/// Taller Semana 9: proyecto base ejecutándose sobre un destino real y
/// consumiendo la API propia (atlas-backend).
class AtlasApp extends StatelessWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atlas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D5AFE)),
        useMaterial3: true,
      ),
      home: const PantallaPrincipal(),
    );
  }
}

/// Shell de navegación. Mantiene una única instancia de [AtlasApi] para que el
/// token obtenido en el login siga disponible en las demás pantallas.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final AtlasApi _api = AtlasApi();
  int _indice = 0;

  void _alCambiarSesion() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final paginas = [
      PantallaConexion(api: _api),
      PantallaSesion(api: _api, alCambiarSesion: _alCambiarSesion),
      PantallaIdeas(api: _api),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atlas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: paginas[_indice],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wifi_tethering_outlined),
            selectedIcon: Icon(Icons.wifi_tethering),
            label: 'Conexión',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline),
            selectedIcon: Icon(Icons.lock),
            label: 'Sesión',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Ideas',
          ),
        ],
      ),
    );
  }
}
