import 'package:flutter/material.dart';

import '../modelos/respuesta_api.dart';

/// Tarjeta que muestra el resultado de una llamada a la API: código de estado,
/// tiempo medido en el cliente y las cabeceras de diagnóstico del backend.
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
    final colores = Theme.of(context).colorScheme;
    final fondo = esError ? colores.errorContainer : colores.secondaryContainer;
    final texto = esError ? colores.onErrorContainer : colores.onSecondaryContainer;

    return Card(
      color: fondo,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(esError ? Icons.error_outline : Icons.check_circle_outline,
                    color: texto),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: texto, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(detalle, style: TextStyle(color: texto)),
            if (sugerencia != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                sugerencia!,
                style: TextStyle(color: texto, fontSize: 12),
              ),
            ],
            if (respuesta != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Etiqueta('HTTP ${respuesta!.codigoEstado}', texto),
                  _Etiqueta('cliente ${respuesta!.milisegundosCliente} ms', texto),
                  if (respuesta!.tiempoServidorMs != null)
                    _Etiqueta('servidor ${respuesta!.tiempoServidorMs} ms', texto),
                  if (respuesta!.consultasSql != null)
                    _Etiqueta('${respuesta!.consultasSql} consultas SQL', texto),
                  if (respuesta!.cache != null)
                    _Etiqueta('caché ${respuesta!.cache}', texto),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, this.color);

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(texto, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
