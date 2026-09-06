import 'package:flutter/material.dart';

import '../modelos/respuesta_api.dart';
import '../tema/tema_atlas.dart';

/// Tarjeta con el resultado de una llamada a la API: código de estado, tiempo
/// medido en el cliente y las cabeceras de diagnóstico que devuelve el
/// backend.
///
/// Es la evidencia visible de que el dato viene de la API y no está quemado en
/// el cliente, y de paso deja ver el efecto de las optimizaciones del backend:
/// número de consultas SQL y acierto o fallo de la caché.
class BloqueResultado extends StatelessWidget {
  const BloqueResultado({
    super.key,
    required this.titulo,
    required this.detalle,
    this.respuesta,
    this.esError = false,
    this.sugerencia,
  });

  final String titulo;
  final String detalle;
  final RespuestaApi<Object?>? respuesta;
  final bool esError;
  final String? sugerencia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final acento = esError ? colores.error : TemaAtlas.acento;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: acento.withValues(alpha: 0.07),
        borderRadius: TemaAtlas.bordeGrande,
        border: Border.all(color: acento.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                esError ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
                color: acento,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            detalle,
            style: tema.textTheme.bodySmall?.copyWith(
              color: colores.onSurface,
              fontFamily: 'monospace',
              fontSize: 12.5,
            ),
          ),
          if (sugerencia != null) ...[
            const SizedBox(height: 8),
            SelectableText(sugerencia!, style: tema.textTheme.bodySmall),
          ],
          if (respuesta != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metrica(
                  icono: Icons.tag,
                  texto: 'HTTP ${respuesta!.codigoEstado}',
                  color: acento,
                ),
                _Metrica(
                  icono: Icons.smartphone,
                  texto: '${respuesta!.milisegundosCliente} ms',
                  color: acento,
                ),
                if (respuesta!.tiempoServidorMs != null)
                  _Metrica(
                    icono: Icons.dns_outlined,
                    texto: '${respuesta!.tiempoServidorMs} ms',
                    color: acento,
                  ),
                if (respuesta!.consultasSql != null)
                  _Metrica(
                    icono: Icons.storage_outlined,
                    texto: '${respuesta!.consultasSql} SQL',
                    color: acento,
                  ),
                if (respuesta!.cache != null)
                  _Metrica(
                    icono: Icons.bolt_outlined,
                    texto: 'caché ${respuesta!.cache}',
                    color: respuesta!.cache?.toUpperCase() == 'HIT'
                        ? const Color(0xFF10B981)
                        : TemaAtlas.realce,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({required this.icono, required this.texto, required this.color});

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
