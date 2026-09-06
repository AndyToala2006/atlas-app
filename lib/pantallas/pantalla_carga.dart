import 'package:flutter/material.dart';

import '../tema/tema_atlas.dart';
import '../widgets/marca_atlas.dart';

/// Pantalla de arranque.
///
/// Se muestra mientras el controlador de sesión lee el token del almacén
/// cifrado y, si existe, lo valida contra `GET /auth/me`. Dura lo que dure esa
/// comprobación: sin token es casi instantánea.
///
/// Existe para evitar el parpadeo de mostrar el login un instante y saltar
/// enseguida al área privada cuando la sesión sí estaba guardada.
class PantallaCarga extends StatelessWidget {
  const PantallaCarga({super.key, this.mensaje = 'Recuperando tu sesión…'});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MarcaAtlas(tamano: 84),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (limites) =>
                  TemaAtlas.degradado.createShader(limites),
              child: Text(
                'Atlas',
                style: tema.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(999),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 16),
            Text(mensaje, style: tema.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de configuración inválida.
///
/// Si `AppConfig.validar()` encuentra un problema con `API_BASE_URL`, no tiene
/// sentido dejar entrar al usuario: cada llamada fallaría con un error de red
/// confuso. Es mejor decir de una vez qué está mal y cómo se corrige.
class PantallaConfiguracionInvalida extends StatelessWidget {
  const PantallaConfiguracionInvalida({super.key, required this.motivo});

  final String motivo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_suggest_outlined,
                  size: 56, color: tema.colorScheme.error),
              const SizedBox(height: 20),
              Text(
                'Configuración incorrecta',
                style: tema.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(motivo, style: tema.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tema.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: TemaAtlas.bordeMedio,
                ),
                child: const SelectableText(
                  '.\\run.ps1',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
