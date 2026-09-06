import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../modelos/metricas_panel.dart';
import '../widgets/aviso_error.dart';
import '../widgets/bloque_resultado.dart';

/// Panel de métricas del usuario (`GET /dashboard/metricas`).
///
/// Es la operación más costosa del backend y está protegida con caché-aside:
/// la primera llamada la calcula (MISS) y las siguientes la sirven desde Redis
/// (HIT). Ese dato viaja en la cabecera `X-Cache` y se muestra en pantalla.
class PantallaPanel extends StatefulWidget {
  const PantallaPanel({super.key});

  @override
  State<PantallaPanel> createState() => _PantallaPanelState();
}

class _PantallaPanelState extends State<PantallaPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final panel = AmbitoAtlas.leer(context).panel;
      if (panel.metricas == null && !panel.cargando && panel.error == null) {
        panel.cargar();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controlador = AmbitoAtlas.panelDe(context);

    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        final metricas = controlador.metricas;

        return RefreshIndicator(
          onRefresh: controlador.cargar,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                onPressed: controlador.cargando ? null : controlador.cargar,
                icon: controlador.cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.query_stats),
                label: const Text('Actualizar métricas'),
              ),

              if (controlador.error != null) ...[
                const SizedBox(height: 16),
                AvisoError(mensaje: controlador.error!),
              ],

              if (controlador.ultimaRespuesta != null &&
                  controlador.error == null) ...[
                const SizedBox(height: 16),
                BloqueResultado(
                  titulo: 'Reporte recibido',
                  detalle: 'GET /dashboard/metricas',
                  respuesta: controlador.ultimaRespuesta,
                ),
              ],

              if (metricas != null) ...[
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _Indicador(
                        rotulo: 'Ideas', valor: '${metricas.totalIdeas}'),
                    _Indicador(
                        rotulo: 'Publicaciones',
                        valor: '${metricas.totalPublicaciones}'),
                    _Indicador(rotulo: 'Likes', valor: '${metricas.likes}'),
                    _Indicador(
                        rotulo: 'Comentarios', valor: '${metricas.comentarios}'),
                    _Indicador(
                        rotulo: 'Compartidos', valor: '${metricas.compartidos}'),
                    _Indicador(rotulo: 'Alcance', valor: '${metricas.alcance}'),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Etiquetas más usadas',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (metricas.topEtiquetas.isEmpty)
                  const Text('Todavía no hay etiquetas registradas.')
                else
                  for (final EtiquetaUso etiqueta in metricas.topEtiquetas)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.sell_outlined),
                      title: Text(etiqueta.nombre),
                      trailing: Text('${etiqueta.usos}'),
                    ),
              ] else if (!controlador.cargando && controlador.error == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    'Sin métricas cargadas todavía.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colores.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              valor,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
