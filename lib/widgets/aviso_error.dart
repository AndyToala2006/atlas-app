import 'package:flutter/material.dart';

/// Aviso de error de formulario o de API.
///
/// Se usa para los mensajes que no pertenecen a un campo concreto —
/// credenciales incorrectas, correo ya registrado, backend inalcanzable — y
/// que por lo tanto no caben en el `errorText` de un `TextFormField`.
class AvisoError extends StatelessWidget {
  const AvisoError({super.key, required this.mensaje, this.alCerrar});

  final String mensaje;
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      key: const Key('aviso-error'),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: colores.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colores.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(color: colores.onErrorContainer),
            ),
          ),
          if (alCerrar != null)
            IconButton(
              onPressed: alCerrar,
              icon: Icon(Icons.close, size: 18, color: colores.onErrorContainer),
              tooltip: 'Descartar',
            ),
        ],
      ),
    );
  }
}
