import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../modelos/idea.dart';
import '../tema/tema_atlas.dart';
import '../widgets/tarjeta_idea.dart';

/// Detalle de una idea (`GET /ideas/{id}`).
///
/// Se abre con `Navigator.pushNamed(..., arguments: idea)`, así que llega con
/// los datos que ya estaban en la lista y se pinta al instante. El botón
/// "recargar" vuelve a pedirla al backend para comprobar que la ruta también
/// exige el token y que lo que se ve es lo que hay en la base de datos.
class PantallaDetalleIdea extends StatefulWidget {
  const PantallaDetalleIdea({super.key, required this.idea});

  final Idea idea;

  @override
  State<PantallaDetalleIdea> createState() => _PantallaDetalleIdeaState();
}

class _PantallaDetalleIdeaState extends State<PantallaDetalleIdea> {
  late Idea _idea = widget.idea;
  bool _recargando = false;

  Future<void> _recargar() async {
    setState(() => _recargando = true);
    final actualizada =
        await AmbitoAtlas.ideasDe(context).recargarIdea(_idea.id);
    if (!mounted) return;
    setState(() {
      if (actualizada != null) _idea = actualizada;
      _recargando = false;
    });
    if (actualizada != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Idea releída desde la base de datos.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sesion = AmbitoAtlas.sesionDe(context);
    final colorEstado = TemaAtlas.colorDeEstado(_idea.estado, tema.colorScheme);

    return Scaffold(
      appBar: AppBar(title: Text('Idea #${_idea.id}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.09),
              borderRadius: TemaAtlas.bordeGrande,
              border: Border.all(color: colorEstado.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InsigniaEstado(estado: _idea.estado),
                const SizedBox(height: 14),
                Text(_idea.titulo, style: tema.textTheme.headlineSmall),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // IntrinsicHeight iguala la altura de las dos tarjetas aunque una
          // tenga el rótulo más largo que la otra.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Dato(
                    icono: Icons.article_outlined,
                    valor: '${_idea.numPublicaciones}',
                    rotulo: 'publicaciones',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Dato(
                    icono: _idea.origen == 'audio'
                        ? Icons.mic_none
                        : Icons.short_text,
                    valor: _idea.origen,
                    rotulo: 'origen',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('Etiquetas', style: tema.textTheme.titleMedium),
          const SizedBox(height: 10),
          if (_idea.etiquetas.isEmpty)
            Text('Esta idea no tiene etiquetas.', style: tema.textTheme.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final etiqueta in _idea.etiquetas)
                  EtiquetaChip(texto: etiqueta),
              ],
            ),
          const SizedBox(height: 24),

          Text('Registro', style: tema.textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: tema.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Creada el ${_formatearFecha(_idea.creadoEn)}',
                        ),
                      ),
                    ],
                  ),
                  // Dato tomado del controlador de sesión: la identidad del
                  // usuario sigue disponible en una pantalla abierta con push,
                  // no solo en las pestañas del contenedor.
                  if (sesion.usuario != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 16, color: tema.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Pertenece a ${sesion.usuario!.nombre}'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          OutlinedButton.icon(
            onPressed: _recargando ? null : _recargar,
            icon: _recargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Recargar desde el backend'),
          ),
        ],
      ),
    );
  }

  static String _formatearFecha(DateTime fecha) {
    final local = fecha.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(local.day)}/${dos(local.month)}/${local.year} '
        '${dos(local.hour)}:${dos(local.minute)}';
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.valor, required this.rotulo});

  final IconData icono;
  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 18, color: tema.colorScheme.primary),
            const SizedBox(height: 10),
            Text(valor, style: tema.textTheme.titleLarge),
            Text(rotulo, style: tema.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
