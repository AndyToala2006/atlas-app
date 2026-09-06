import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import 'pantalla_ideas.dart';
import 'pantalla_panel.dart';
import 'pantalla_perfil.dart';

/// Contenedor del área privada: barra superior con el usuario en sesión y
/// barra inferior con las tres secciones.
///
/// Las tres pantallas se montan dentro de un [IndexedStack], así que cambiar
/// de pestaña no las destruye: la posición del scroll y lo que haya escrito el
/// usuario siguen ahí al volver. El dato del usuario, en cambio, no lo guarda
/// esta pantalla: lo lee del controlador de sesión, que es común a todas.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  int _indice = 0;

  static const _titulos = ['Mis ideas', 'Panel de métricas', 'Mi perfil'];

  @override
  Widget build(BuildContext context) {
    final sesion = AmbitoAtlas.sesionDe(context);

    return ListenableBuilder(
      listenable: sesion,
      builder: (context, _) {
        final usuario = sesion.usuario;

        return Scaffold(
          appBar: AppBar(
            title: Text(_titulos[_indice]),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              if (usuario != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        child: Text(
                          usuario.iniciales,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // El nombre visible en las tres pestañas es la prueba a
                      // simple vista de que el estado sobrevive a la navegación.
                      Text(
                        usuario.nombre,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          body: IndexedStack(
            index: _indice,
            children: const [
              PantallaIdeas(),
              PantallaPanel(),
              PantallaPerfil(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _indice,
            onDestinationSelected: (i) => setState(() => _indice = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.lightbulb_outline),
                selectedIcon: Icon(Icons.lightbulb),
                label: 'Ideas',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Panel',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}
