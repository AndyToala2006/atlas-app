import 'package:flutter/material.dart';

import '../modelos/idea.dart';

/// Fila del listado de ideas. Al pulsarla se abre el detalle.
class TarjetaIdea extends StatelessWidget {
  const TarjetaIdea({super.key, required this.idea, this.alPulsar});

  final Idea idea;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    final etiquetas =
        idea.etiquetas.isEmpty ? 'sin etiquetas' : idea.etiquetas.join(', ');

    return ListTile(
      onTap: alPulsar,
      leading: CircleAvatar(child: Text('${idea.id}')),
      title: Text(idea.titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'estado: ${idea.estado} · origen: ${idea.origen} · '
        'publicaciones: ${idea.numPublicaciones}\n$etiquetas',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
