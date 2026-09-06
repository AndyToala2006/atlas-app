import 'package:flutter/material.dart';

import '../modelos/idea.dart';
import '../tema/tema_atlas.dart';

/// Tarjeta del listado de ideas. Al pulsarla se abre el detalle.
class TarjetaIdea extends StatelessWidget {
  const TarjetaIdea({super.key, required this.idea, this.alPulsar});

  final Idea idea;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colorEstado = TemaAtlas.colorDeEstado(idea.estado, tema.colorScheme);

    return Card(
      child: InkWell(
        onTap: alPulsar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Franja de color a la izquierda: identifica el estado de un
              // vistazo, sin tener que leer la etiqueta.
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: colorEstado,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      idea.titulo,
                      style: tema.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InsigniaEstado(estado: idea.estado),
                        _Dato(
                          icono: Icons.article_outlined,
                          texto: '${idea.numPublicaciones}',
                        ),
                        _Dato(
                          icono: idea.origen == 'audio'
                              ? Icons.mic_none
                              : Icons.short_text,
                          texto: idea.origen,
                        ),
                      ],
                    ),
                    if (idea.etiquetas.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final etiqueta in idea.etiquetas)
                            EtiquetaChip(texto: etiqueta),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Insignia coloreada con el estado de una idea.
class InsigniaEstado extends StatelessWidget {
  const InsigniaEstado({super.key, required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final color = TemaAtlas.colorDeEstado(estado, Theme.of(context).colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TemaAtlas.iconoDeEstado(estado), size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            estado,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de una idea, en formato compacto.
class EtiquetaChip extends StatelessWidget {
  const EtiquetaChip({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colores.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colores.outlineVariant),
      ),
      child: Text(
        '#$texto',
        style: TextStyle(
          fontSize: 11.5,
          color: colores.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 13, color: color),
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(fontSize: 11.5, color: color)),
      ],
    );
  }
}
