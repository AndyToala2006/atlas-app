import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../modelos/metricas_panel.dart';
import '../tema/tema_atlas.dart';
import '../widgets/aviso_error.dart';
import '../widgets/bloque_resultado.dart';
import '../widgets/estado_vacio.dart';

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
    final tema = Theme.of(context);

    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        final metricas = controlador.metricas;

        return RefreshIndicator(
          onRefresh: controlador.cargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (metricas != null) ...[
                _TarjetaProduccion(metricas: metricas),
                const SizedBox(height: 20),

                Text('Interacción acumulada', style: tema.textTheme.titleMedium),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _Indicador(
                      icono: Icons.favorite_outline,
                      rotulo: 'Likes',
                      valor: metricas.likes,
                      color: const Color(0xFFEC4899),
                    ),
                    _Indicador(
                      icono: Icons.mode_comment_outlined,
                      rotulo: 'Comentarios',
                      valor: metricas.comentarios,
                      color: TemaAtlas.acento,
                    ),
                    _Indicador(
                      icono: Icons.repeat_rounded,
                      rotulo: 'Compartidos',
                      valor: metricas.compartidos,
                      color: const Color(0xFF10B981),
                    ),
                    _Indicador(
                      icono: Icons.visibility_outlined,
                      rotulo: 'Alcance',
                      valor: metricas.alcance,
                      color: TemaAtlas.realce,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text('Etiquetas más usadas', style: tema.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (metricas.topEtiquetas.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Todavía no has etiquetado ninguna idea.',
                        style: tema.textTheme.bodySmall,
                      ),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          for (final etiqueta in metricas.topEtiquetas)
                            _FilaEtiqueta(
                              etiqueta: etiqueta,
                              maximo: metricas.topEtiquetas.first.usos,
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ] else if (controlador.cargando)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: EsqueletoLista(filas: 2),
                )
              else if (controlador.error == null)
                EstadoVacio(
                  icono: Icons.insights_outlined,
                  titulo: 'Sin métricas todavía',
                  mensaje:
                      'Cuando publiques y registres resultados, aquí verás cómo '
                      'está rindiendo tu contenido.',
                  textoAccion: 'Calcular ahora',
                  alPulsarAccion: controlador.cargar,
                ),

              if (controlador.error != null) ...[
                AvisoError(mensaje: controlador.error!),
                const SizedBox(height: 16),
              ],

              FilledButton.tonalIcon(
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

              if (controlador.ultimaRespuesta != null &&
                  controlador.error == null) ...[
                const SizedBox(height: 16),
                BloqueResultado(
                  titulo: 'Reporte recibido',
                  detalle: 'GET /dashboard/metricas',
                  respuesta: controlador.ultimaRespuesta,
                ),
                const SizedBox(height: 8),
                Text(
                  'Un reporte servido desde la caché (HIT) responde en '
                  'microsegundos y con 0 consultas SQL. Vuelve a pulsar '
                  '"Actualizar" para verlo.',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Cabecera del panel: ideas y publicaciones sobre el degradado de marca.
class _TarjetaProduccion extends StatelessWidget {
  const _TarjetaProduccion({required this.metricas});

  final MetricasPanel metricas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: TemaAtlas.degradado,
        borderRadius: TemaAtlas.bordeGrande,
        boxShadow: [
          BoxShadow(
            color: TemaAtlas.marca.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu producción',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Cifra(valor: metricas.totalIdeas, rotulo: 'ideas capturadas'),
              Container(
                width: 1,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white.withValues(alpha: 0.25),
              ),
              _Cifra(
                valor: metricas.totalPublicaciones,
                rotulo: 'publicaciones generadas',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.rotulo});

  final int valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$valor',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rotulo,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.icono,
    required this.rotulo,
    required this.valor,
    required this.color,
  });

  final IconData icono;
  final String rotulo;
  final int valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, size: 17, color: color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Una cifra larga se encoge en lugar de partirse en dos
                // lineas, que desbordaria la tarjeta.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatear(valor),
                    maxLines: 1,
                    style: tema.textTheme.headlineSmall?.copyWith(height: 1.1),
                  ),
                ),
                Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Abrevia los números grandes para que la tarjeta no se desborde.
  static String _formatear(int valor) {
    if (valor < 1000) return '$valor';
    if (valor < 1000000) return '${(valor / 1000).toStringAsFixed(1)}k';
    return '${(valor / 1000000).toStringAsFixed(1)}M';
  }
}

class _FilaEtiqueta extends StatelessWidget {
  const _FilaEtiqueta({required this.etiqueta, required this.maximo});

  final EtiquetaUso etiqueta;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final proporcion = maximo == 0 ? 0.0 : etiqueta.usos / maximo;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${etiqueta.nombre}',
                  style: tema.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${etiqueta.usos}',
                style: tema.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: proporcion,
              minHeight: 6,
              backgroundColor: tema.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
