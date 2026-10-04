import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../estado/ambito_atlas.dart';
import '../modelos/estado_permiso.dart';
import '../rutas/rutas.dart';
import '../tema/tema_atlas.dart';
import '../widgets/marca_atlas.dart';

/// Perfil del usuario en sesión, cierre de sesión y preferencia de avisos.
///
/// Todo lo que se ve aquí sale del controlador de sesión: esta pantalla no
/// vuelve a llamar a `GET /auth/me`, porque el perfil se cargó una sola vez al
/// autenticar y sigue en el estado compartido. El interruptor de
/// notificaciones (Taller Semana 14) sí depende de un segundo controlador
/// -las ideas-, porque es ahí donde vive la comparación de estados que decide
/// cuándo avisar.
class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});

  /// Explica, ANTES de pedir el permiso, para qué sirve el aviso. Si el
  /// usuario cancela aquí, ni siquiera se llega a mostrar el diálogo nativo:
  /// es la explicación previa que exige el taller.
  Future<void> _activarNotificaciones(BuildContext context) async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: const Text('Avisar cuando una idea se publique'),
        content: const Text(
          'Atlas va a pedir permiso de notificaciones para avisarte, con una '
          'notificación local del propio teléfono, en cuanto una idea que '
          'capturaste termine de procesarse en el backend y tenga una '
          'publicación lista. No es necesario para usar la aplicación.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (continuar != true || !context.mounted) return;

    final ideas = AmbitoAtlas.ideasDe(context);
    final estado = await ideas.activarNotificaciones();
    if (!context.mounted || estado.concedidoOk) return;

    if (estado == EstadoPermiso.restringido) {
      // Una restricción de política (control parental, MDM) no se revierte
      // desde los ajustes de la aplicación: ofrecerlos sería un callejón sin
      // salida disfrazado de solución.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Las notificaciones están restringidas en este dispositivo por '
            'una política del sistema. Puedes revisar el estado de tus '
            'ideas entrando a mirarlas.',
          ),
        ),
      );
      return;
    }

    if (estado.requiereAjustes) {
      final abrir = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          icon: Icon(
            Icons.notifications_off_outlined,
            color: Theme.of(dialogo).colorScheme.error,
          ),
          title: const Text('Notificaciones bloqueadas'),
          content: const Text(
            'Bloqueaste el permiso de notificaciones y el sistema ya no '
            'vuelve a preguntar. Para recibir el aviso, actívalo desde los '
            'ajustes de la aplicación. Mientras tanto puedes revisar el '
            'estado de tus ideas entrando a mirarlas.',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Abrir ajustes'),
            ),
          ],
        ),
      );
      if (abrir == true) await ideas.abrirAjustesDeNotificaciones();
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sin permiso de notificaciones no se puede avisar. Puedes '
            'revisar el estado de tus ideas entrando a mirarlas.',
          ),
        ),
      );
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: Icon(Icons.logout, color: Theme.of(dialogo).colorScheme.error),
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Se borrará el token guardado en este dispositivo y tendrás que '
          'volver a autenticarte para entrar a tus ideas y a tu panel.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('boton-confirmar-salir'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogo).colorScheme.error,
              minimumSize: const Size(0, 46),
            ),
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
    ambito.publicaciones.limpiar();
    await ambito.sesion.cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final sesion = AmbitoAtlas.sesionDe(context);
    final ideas = AmbitoAtlas.ideasDe(context);
    final tema = Theme.of(context);

    return ListenableBuilder(
      // Se escuchan los dos controladores: el perfil sale de la sesión, pero
      // el interruptor de notificaciones vive en `ControladorIdeas`, que es
      // donde se decide cuándo avisar de una idea publicada.
      listenable: Listenable.merge([sesion, ideas]),
      builder: (context, _) {
        final usuario = sesion.usuario;
        if (usuario == null) return const SizedBox.shrink();

        return ListView(
          key: const Key('lista-perfil'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // Cabecera de identidad sobre el degradado de marca.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: TemaAtlas.degradado,
                borderRadius: TemaAtlas.bordeGrande,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: AvatarUsuario(iniciales: usuario.iniciales, radio: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario.nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          usuario.email,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('Sesión', style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _Fila(
                      icono: Icons.badge_outlined,
                      clave: 'Usuario id',
                      valor: '${usuario.id}',
                    ),
                    _Fila(
                      icono: Icons.schedule,
                      clave: 'Iniciada',
                      valor: _formatearHora(sesion.iniciadaEn),
                    ),
                    _Fila(
                      icono: Icons.vpn_key_outlined,
                      clave: 'Token JWT',
                      valor: sesion.tokenAbreviado ?? '—',
                    ),
                    _Fila(
                      icono: Icons.shield_outlined,
                      clave: 'Origen',
                      valor: sesion.sesionRestaurada
                          ? 'restaurada del almacén cifrado'
                          : 'iniciada en este arranque',
                      ultima: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            _NotaSeguridad(
              texto: 'El token se guarda cifrado por el sistema operativo '
                  '(Keystore en Android, Keychain en iOS). Nunca se escribe en '
                  'almacenamiento en claro.',
            ),
            const SizedBox(height: 24),

            Text('Notificaciones', style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                key: const Key('interruptor-notificaciones'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Avisarme cuando una idea se publique'),
                subtitle: const Text(
                  'Notificación local del teléfono; no depende de un servidor '
                  'de mensajería ni de que la aplicación esté abierta.',
                ),
                value: ideas.notificacionesActivadas,
                onChanged: (activar) => activar
                    ? _activarNotificaciones(context)
                    : ideas.desactivarNotificaciones(),
              ),
            ),
            const SizedBox(height: 24),

            Text('Conexión', style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _Fila(
                      icono: Icons.dns_outlined,
                      clave: 'API',
                      valor: AppConfig.apiBaseUrl,
                    ),
                    _Fila(
                      icono: Icons.tune,
                      clave: 'Entorno',
                      valor: AppConfig.entorno,
                      ultima: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(Rutas.diagnostico),
              icon: const Icon(Icons.network_check),
              label: const Text('Diagnóstico de conexión'),
            ),
            const SizedBox(height: 28),

            OutlinedButton.icon(
              key: const Key('boton-cerrar-sesion'),
              onPressed: () => _cerrarSesion(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: tema.colorScheme.error,
                side: BorderSide(
                  color: tema.colorScheme.error.withValues(alpha: 0.45),
                ),
              ),
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
  const _Fila({
    required this.icono,
    required this.clave,
    required this.valor,
    this.ultima = false,
  });

  final IconData icono;
  final String clave;
  final String valor;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: ultima
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tema.colorScheme.outlineVariant),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Text(clave, style: tema.textTheme.bodySmall),
          ),
          Expanded(
            child: SelectableText(
              valor,
              style: tema.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotaSeguridad extends StatelessWidget {
  const _NotaSeguridad({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TemaAtlas.acento.withValues(alpha: 0.07),
        borderRadius: TemaAtlas.bordeMedio,
        border: Border.all(color: TemaAtlas.acento.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 17, color: TemaAtlas.acento),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: tema.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
