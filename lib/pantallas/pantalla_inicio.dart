import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../widgets/marca_atlas.dart';
import 'pantalla_ideas.dart';
import 'pantalla_panel.dart';
import 'pantalla_perfil.dart';

/// Contenedor del área privada: cabecera con el usuario en sesión y barra
/// inferior con las tres secciones.
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
  static const _subtitulos = [
    'Todo lo que has capturado',
    'Cómo está rindiendo tu contenido',
    'Tu cuenta y tu sesión',
  ];

  @override
  Widget build(BuildContext context) {
    final sesion = AmbitoAtlas.sesionDe(context);
    final tema = Theme.of(context);

    return ListenableBuilder(
      listenable: sesion,
      builder: (context, _) {
        final usuario = sesion.usuario;

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            titleSpacing: 20,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_titulos[_indice], style: tema.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(_subtitulos[_indice], style: tema.textTheme.bodySmall),
              ],
            ),
            actions: [
              if (usuario != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Tooltip(
                    // El nombre completo está en la barra en las tres
                    // pestañas: es la señal a simple vista de que el estado
                    // sobrevive a la navegación.
                    message: '${usuario.nombre}\n${usuario.email}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => _indice = 2),
                      child: Row(
                        children: [
                          Text(
                            usuario.nombre,
                            style: tema.textTheme.labelLarge,
                          ),
                          const SizedBox(width: 10),
                          AvatarUsuario(iniciales: usuario.iniciales, radio: 18),
                        ],
                      ),
                    ),
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
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: tema.colorScheme.outlineVariant),
              ),
            ),
            child: NavigationBar(
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
          ),
        );
      },
    );
  }
}
