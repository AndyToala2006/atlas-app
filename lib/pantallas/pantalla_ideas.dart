import 'package:flutter/material.dart';

import '../api/atlas_api.dart';
import '../widgets/bloque_resultado.dart';

/// Consumo de datos reales: `GET /ideas` con el JWT del usuario autenticado.
///
/// El interruptor "consulta optimizada" alterna el parámetro `optimized`, que
/// en el backend cambia entre eager loading y la versión con N+1. La diferencia
/// se evidencia en la cabecera `X-Query-Count` que se muestra en pantalla.
class PantallaIdeas extends StatefulWidget {
  const PantallaIdeas({super.key, required this.api});

  final AtlasApi api;

  @override
  State<PantallaIdeas> createState() => _PantallaIdeasState();
}

class _PantallaIdeasState extends State<PantallaIdeas> {
  bool _cargando = false;
  bool _optimizado = true;
  List<Idea> _ideas = const [];
  Widget? _resultado;

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _resultado = null;
    });
    try {
      final respuesta = await widget.api.listarIdeas(optimizado: _optimizado);
      setState(() {
        _ideas = respuesta.datos;
        _resultado = BloqueResultado(
          titulo: '${respuesta.datos.length} ideas recibidas',
          detalle: 'GET /ideas?optimized=$_optimizado',
          respuesta: respuesta,
        );
      });
    } on ErrorApi catch (e) {
      setState(() {
        _ideas = const [];
        _resultado = BloqueResultado(
          titulo: 'No se pudieron cargar las ideas',
          detalle: e.codigoEstado == 401
              ? 'La API rechazó la solicitud por falta de autenticación. '
                  'Inicia sesión en la pestaña Sesión y vuelve a intentarlo.'
              : e.mensaje,
          sugerencia: e.sugerencia,
          esError: true,
        );
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _crearIdea() async {
    final titulo = await showDialog<String>(
      context: context,
      builder: (contexto) => const _DialogoNuevaIdea(),
    );
    if (titulo == null || titulo.isEmpty) return;

    try {
      final respuesta = await widget.api.crearIdea(
        titulo: titulo,
        contenido: 'Idea capturada desde la aplicación móvil Atlas.',
        etiquetas: const ['movil'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Idea creada en la base de datos con id '
              '${respuesta.datos.id}'),
        ),
      );
      await _cargar();
    } on ErrorApi catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Consulta optimizada'),
                subtitle: const Text('eager loading en el backend (sin N+1)'),
                value: _optimizado,
                onChanged: (v) => setState(() => _optimizado = v),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _cargando ? null : _cargar,
                      icon: _cargando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_outlined),
                      label: const Text('Cargar ideas'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: widget.api.haySesion ? _crearIdea : null,
                    icon: const Icon(Icons.add),
                    tooltip: 'Crear idea',
                  ),
                ],
              ),
              if (_resultado != null) ...[
                const SizedBox(height: 16),
                _resultado!,
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _ideas.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Sin datos cargados todavía.\n'
                      'Inicia sesión y pulsa "Cargar ideas".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _ideas.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (contexto, i) {
                    final idea = _ideas[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text('${idea.id}')),
                      title: Text(idea.titulo),
                      subtitle: Text(
                        'estado: ${idea.estado} · origen: ${idea.origen} · '
                        'publicaciones: ${idea.numPublicaciones}\n'
                        '${idea.etiquetas.isEmpty ? "sin etiquetas" : idea.etiquetas.join(", ")}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DialogoNuevaIdea extends StatefulWidget {
  const _DialogoNuevaIdea();

  @override
  State<_DialogoNuevaIdea> createState() => _DialogoNuevaIdeaState();
}

class _DialogoNuevaIdeaState extends State<_DialogoNuevaIdea> {
  final _controlador = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _aceptar() {
    final texto = _controlador.text.trim();
    if (texto.length < 2) {
      setState(() => _error = 'El título debe tener al menos 2 caracteres');
      return;
    }
    Navigator.of(context).pop(texto);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva idea'),
      content: TextField(
        controller: _controlador,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Título',
          border: const OutlineInputBorder(),
          errorText: _error,
        ),
        onSubmitted: (_) => _aceptar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _aceptar, child: const Text('Guardar')),
      ],
    );
  }
}
