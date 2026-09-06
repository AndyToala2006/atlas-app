import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../estado/ambito_atlas.dart';
import '../rutas/rutas.dart';

/// Perfil del usuario en sesión y cierre de sesión.
///
/// Todo lo que se ve aquí sale del [ControladorSesion]: esta pantalla no
/// vuelve a llamar a `GET /auth/me`, porque el perfil se cargó una sola vez al
/// autenticar y sigue en el estado compartido.
class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Se borrará el token de este dispositivo y tendrás que volver a '
          'autenticarte para entrar a tus ideas y a tu panel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('boton-confirmar-salir'),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmado != true || !context.mounted) return;

    final ambito = AmbitoAtlas.de(context);
    // Primero se desmonta el área privada y después se limpia el estado, para
    // que ninguna pantalla protegida llegue a redibujarse sin sesión.
    Navigator.of(context).pushNamedAndRemoveUntil(Rutas.login, (_) => false);
    ambito.ideas.limpiar();
    ambito.panel.limpiar();
    ambito.sesion.cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final sesion = AmbitoAtlas.sesionDe(context);

    return ListenableBuilder(
      listenable: sesion,
      builder: (context, _) {
        final usuario = sesion.usuario;
        if (usuario == null) return const SizedBox.shrink();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(radius: 28, child: Text(usuario.iniciales)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            usuario.nombre,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(usuario.email),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sesión',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _Fila('Usuario id', '${usuario.id}'),
                    _Fila('Iniciada', _formatearHora(sesion.iniciadaEn)),
                    _Fila('Token JWT', sesion.tokenAbreviado ?? '—'),
                    _Fila('API', AppConfig.apiBaseUrl),
                    _Fila('Entorno', AppConfig.entorno),
                    const SizedBox(height: 8),
                    Text(
                      'El token se guarda solo en memoria: al cerrar la '
                      'aplicación la sesión termina.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              key: const Key('boton-cerrar-sesion'),
              onPressed: () => _cerrarSesion(context),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }

  static String _formatearHora(DateTime? fecha) {
    if (fecha == null) return '—';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.hour)}:${dos(fecha.minute)}:${dos(fecha.second)}';
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.clave, this.valor);

  final String clave;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              clave,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(valor, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
