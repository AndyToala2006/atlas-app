import 'package:flutter/material.dart';

import '../tema/tema_atlas.dart';

/// Aviso de error de formulario o de API.
///
/// Se usa para los mensajes que no pertenecen a un campo concreto —
/// credenciales incorrectas, correo ya registrado, backend inalcanzable — y
/// que por lo tanto no caben en el `errorText` de un `TextFormField`.
///
/// Entra con una animación breve: un bloque rojo que aparece de golpe se lee
/// como un fallo de la aplicación; uno que se despliega se lee como una
/// respuesta a lo que el usuario acaba de hacer.
class AvisoError extends StatelessWidget {
  const AvisoError({
    super.key,
    required this.mensaje,
    this.alCerrar,
    this.icono = Icons.error_outline,
  });

  final String mensaje;
  final VoidCallback? alCerrar;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      key: const Key('aviso-error'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, valor, hijo) => Opacity(
        opacity: valor,
        child: Transform.translate(offset: Offset(0, 8 * (1 - valor)), child: hijo),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 14, alCerrar == null ? 14 : 4, 14),
        decoration: BoxDecoration(
          color: colores.errorContainer.withValues(alpha: 0.65),
          borderRadius: TemaAtlas.bordeMedio,
          border: Border.all(color: colores.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: colores.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: TextStyle(
                  color: colores.onErrorContainer,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
            if (alCerrar != null)
              IconButton(
                onPressed: alCerrar,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 18, color: colores.onErrorContainer),
                tooltip: 'Descartar',
              ),
          ],
        ),
      ),
    );
  }
}
