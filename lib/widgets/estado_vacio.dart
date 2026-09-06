import 'package:flutter/material.dart';

import '../tema/tema_atlas.dart';

/// Estado vacío: lo que se ve cuando todavía no hay datos que mostrar.
///
/// Una lista vacía sin explicación parece un error. Este widget dice qué
/// falta y ofrece la acción que lo resuelve, que es la diferencia entre una
/// pantalla rota y una pantalla que todavía no se ha usado.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.textoAccion,
    this.alPulsarAccion,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final String? textoAccion;
  final VoidCallback? alPulsarAccion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: tema.colorScheme.primary.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 40, color: tema.colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            titulo,
            style: tema.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            mensaje,
            style: tema.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (textoAccion != null && alPulsarAccion != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              child: FilledButton.tonal(
                onPressed: alPulsarAccion,
                child: Text(textoAccion!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Marcadores de carga con forma de tarjeta.
///
/// Se muestran mientras llega la respuesta de la API. Frente a un círculo
/// girando en medio de la pantalla, anticipan la forma del contenido y hacen
/// que la espera se perciba más corta.
class EsqueletoLista extends StatefulWidget {
  const EsqueletoLista({super.key, this.filas = 3});

  final int filas;

  @override
  State<EsqueletoLista> createState() => _EsqueletoListaState();
}

class _EsqueletoListaState extends State<EsqueletoLista>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controlador,
      builder: (context, _) {
        final opacidad = 0.35 + (_controlador.value * 0.35);
        final color = colores.onSurfaceVariant.withValues(alpha: opacidad * 0.25);

        return Column(
          children: [
            for (var i = 0; i < widget.filas; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colores.surface,
                    borderRadius: TemaAtlas.bordeGrande,
                    border: Border.all(color: colores.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Barra(ancho: double.infinity, color: color),
                            const SizedBox(height: 8),
                            _Barra(ancho: 160, color: color),
                            const SizedBox(height: 8),
                            _Barra(ancho: 96, color: color),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.ancho, required this.color});

  final double ancho;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
