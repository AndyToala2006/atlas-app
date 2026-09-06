import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../rutas/rutas.dart';
import '../tema/tema_atlas.dart';
import '../widgets/aviso_error.dart';
import '../widgets/bloque_resultado.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/tarjeta_idea.dart';

/// Listado de ideas del usuario autenticado (`GET /ideas`).
///
/// La pantalla no guarda las ideas: las pide al controlador y se redibuja
/// cuando este avisa. Por eso al volver de otra pestaña o del detalle de una
/// idea la lista ya está cargada, sin repetir la llamada.
class PantallaIdeas extends StatefulWidget {
  const PantallaIdeas({super.key});

  @override
  State<PantallaIdeas> createState() => _PantallaIdeasState();
}

class _PantallaIdeasState extends State<PantallaIdeas> {
  bool _verDiagnostico = false;

  @override
  void initState() {
    super.initState();
    // Primera carga automática al entrar al área privada, solo si aún no hay
    // datos en el estado compartido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ideas = AmbitoAtlas.leer(context).ideas;
      if (!ideas.hayDatos && !ideas.cargando && ideas.error == null) {
        ideas.cargar();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controlador = AmbitoAtlas.ideasDe(context);
    final tema = Theme.of(context);

    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        final hayBorrador = controlador.hayBorrador;

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).pushNamed(Rutas.nuevaIdea),
            icon: Icon(hayBorrador ? Icons.edit_note : Icons.add),
            label: Text(hayBorrador ? 'Seguir borrador' : 'Nueva idea'),
          ),
          body: RefreshIndicator(
            onRefresh: controlador.cargar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                // Resumen del listado, con el contador y el acceso al detalle
                // técnico de la última respuesta.
                _BarraResumen(
                  total: controlador.ideas.length,
                  cargando: controlador.cargando,
                  verDiagnostico: _verDiagnostico,
                  alRecargar: controlador.cargando ? null : controlador.cargar,
                  alAlternarDiagnostico: () =>
                      setState(() => _verDiagnostico = !_verDiagnostico),
                ),

                if (_verDiagnostico) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Consulta optimizada'),
                            subtitle: const Text(
                              'eager loading en el backend (sin N+1)',
                            ),
                            value: controlador.optimizado,
                            onChanged: controlador.cargando
                                ? null
                                : (v) {
                                    controlador.cambiarOptimizado(v);
                                    controlador.cargar();
                                  },
                          ),
                          if (controlador.ultimaRespuesta != null &&
                              controlador.error == null) ...[
                            const SizedBox(height: 8),
                            BloqueResultado(
                              titulo: 'Respuesta del backend',
                              detalle:
                                  'GET /ideas?optimized=${controlador.optimizado}',
                              respuesta: controlador.ultimaRespuesta,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                if (hayBorrador) ...[
                  const SizedBox(height: 12),
                  _TarjetaBorrador(
                    titulo: controlador.borradorTitulo,
                    alContinuar: () =>
                        Navigator.of(context).pushNamed(Rutas.nuevaIdea),
                    alDescartar: controlador.descartarBorrador,
                  ),
                ],

                if (controlador.error != null) ...[
                  const SizedBox(height: 12),
                  AvisoError(mensaje: controlador.error!),
                ],

                const SizedBox(height: 12),

                if (controlador.cargando && controlador.ideas.isEmpty)
                  const EsqueletoLista()
                else if (controlador.ideas.isEmpty && controlador.error == null)
                  EstadoVacio(
                    icono: Icons.lightbulb_outline,
                    titulo: 'Todavía no hay ideas',
                    mensaje:
                        'Captura la primera y Atlas la preparará para convertirla '
                        'en una publicación.',
                    textoAccion: 'Crear mi primera idea',
                    alPulsarAccion: () =>
                        Navigator.of(context).pushNamed(Rutas.nuevaIdea),
                  )
                else
                  for (final idea in controlador.ideas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TarjetaIdea(
                        idea: idea,
                        alPulsar: () => Navigator.of(context).pushNamed(
                          Rutas.detalleIdea,
                          arguments: idea,
                        ),
                      ),
                    ),

                if (controlador.ideas.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Desliza para actualizar',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BarraResumen extends StatelessWidget {
  const _BarraResumen({
    required this.total,
    required this.cargando,
    required this.verDiagnostico,
    required this.alRecargar,
    required this.alAlternarDiagnostico,
  });

  final int total;
  final bool cargando;
  final bool verDiagnostico;
  final VoidCallback? alRecargar;
  final VoidCallback alAlternarDiagnostico;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: tema.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            total == 1 ? '1 idea' : '$total ideas',
            style: TextStyle(
              color: tema.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          key: const Key('boton-cargar-ideas'),
          onPressed: alRecargar,
          tooltip: 'Cargar ideas',
          icon: cargando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: alAlternarDiagnostico,
          tooltip: verDiagnostico
              ? 'Ocultar detalle técnico'
              : 'Ver detalle técnico de la respuesta',
          isSelected: verDiagnostico,
          icon: const Icon(Icons.speed_outlined),
          selectedIcon: Icon(Icons.speed, color: TemaAtlas.acento),
        ),
      ],
    );
  }
}

class _TarjetaBorrador extends StatelessWidget {
  const _TarjetaBorrador({
    required this.titulo,
    required this.alContinuar,
    required this.alDescartar,
  });

  final String titulo;
  final VoidCallback alContinuar;
  final VoidCallback alDescartar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: TemaAtlas.realce.withValues(alpha: 0.08),
        borderRadius: TemaAtlas.bordeGrande,
        border: Border.all(color: TemaAtlas.realce.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        onTap: alContinuar,
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        leading: Icon(Icons.edit_note, color: TemaAtlas.realce),
        title: Text(
          'Tienes un borrador sin guardar',
          style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          titulo.isEmpty ? 'Sin título' : titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          onPressed: alDescartar,
          tooltip: 'Descartar borrador',
          icon: const Icon(Icons.close, size: 18),
        ),
      ),
    );
  }
}
