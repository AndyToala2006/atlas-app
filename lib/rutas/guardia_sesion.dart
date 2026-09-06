import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../estado/controlador_sesion.dart';
import 'rutas.dart';

/// Guardia de rutas: deja pasar solo si hay una sesión abierta.
///
/// Envuelve a cada pantalla protegida en `rutas.dart`. Escucha al
/// [ControladorSesion], de modo que la protección no se evalúa una sola vez al
/// abrir la pantalla: si la sesión se cierra —porque el usuario pulsó "cerrar
/// sesión" o porque la API devolvió 401— la pantalla protegida se reemplaza en
/// el acto por el aviso de acceso restringido, sin dejar datos a la vista.
class GuardiaSesion extends StatelessWidget {
  const GuardiaSesion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sesion = AmbitoAtlas.sesionDe(context);

    return ListenableBuilder(
      listenable: sesion,
      builder: (context, _) {
        if (sesion.haySesion) return child;
        return const _AccesoRestringido();
      },
    );
  }
}

class _AccesoRestringido extends StatelessWidget {
  const _AccesoRestringido();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Acceso restringido')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 56, color: colores.error),
              const SizedBox(height: 16),
              Text(
                'Esta sección es privada',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tus ideas, tus métricas y tu perfil solo están disponibles con '
                'la sesión iniciada. Inicia sesión para continuar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('boton-ir-a-login'),
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(Rutas.login, (_) => false),
                icon: const Icon(Icons.login),
                label: const Text('Ir a iniciar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
