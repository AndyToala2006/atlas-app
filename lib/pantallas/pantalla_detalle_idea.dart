import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../modelos/idea.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text('Idea #${_idea.id}')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_idea.titulo, style: tema.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('estado: ${_idea.estado}')),
              Chip(label: Text('origen: ${_idea.origen}')),
              Chip(label: Text('${_idea.numPublicaciones} publicaciones')),
            ],
          ),
          const SizedBox(height: 24),
          Text('Etiquetas', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_idea.etiquetas.isEmpty)
            const Text('Esta idea no tiene etiquetas.')
          else
            Wrap(
              spacing: 8,
              children: [
                for (final etiqueta in _idea.etiquetas)
                  Chip(
                    avatar: const Icon(Icons.sell_outlined, size: 16),
                    label: Text(etiqueta),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          Text('Registro', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Creada el ${_formatearFecha(_idea.creadoEn)}'),
          // Dato tomado del controlador de sesión: la identidad del usuario
          // sigue disponible en una pantalla abierta con push, no solo en las
          // pestañas del contenedor.
          if (sesion.usuario != null)
            Text('Pertenece a ${sesion.usuario!.nombre}'),
          const SizedBox(height: 32),
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
