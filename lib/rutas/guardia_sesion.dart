import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../estado/controlador_sesion.dart';
import '../tema/tema_atlas.dart';
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
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Acceso restringido')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colores.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline, size: 44, color: colores.error),
              ),
              const SizedBox(height: 24),
              Text(
                'Esta sección es privada',
                style: tema.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Tus ideas, tus métricas y tu perfil solo están disponibles con '
                'la sesión iniciada.',
                style: tema.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colores.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: TemaAtlas.bordeMedio,
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 17, color: colores.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'La ruta quedó bloqueada por la guardia de sesión, antes '
                        'de construir la pantalla.',
                        style: tema.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('boton-ir-a-login'),
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(Rutas.login, (_) => false),
                  icon: const Icon(Icons.login),
                  label: const Text('Ir a iniciar sesión'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
