import 'package:flutter/material.dart';

/// Campo de texto validado, reutilizado por los formularios de login, registro
/// y nueva idea.
///
/// Centralizarlo evita repetir la decoración en cada pantalla y garantiza que
/// todos los formularios se comporten igual: el error aparece bajo el campo,
/// el icono identifica el dato y el teclado corresponde al tipo de entrada.
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.controlador,
    required this.etiqueta,
    this.icono,
    this.ayuda,
    this.validador,
    this.tipoTeclado,
    this.oculto = false,
    this.lineas = 1,
    this.maxCaracteres,
    this.habilitado = true,
    this.accionTeclado,
    this.alEnviar,
    this.alCambiar,
    this.sufijo,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final IconData? icono;
  final String? ayuda;
  final String? Function(String?)? validador;
  final TextInputType? tipoTeclado;
  final bool oculto;
  final int lineas;
  final int? maxCaracteres;
  final bool habilitado;
  final TextInputAction? accionTeclado;
  final void Function(String)? alEnviar;
  final void Function(String)? alCambiar;
  final Widget? sufijo;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      validator: validador,
      keyboardType: tipoTeclado,
      obscureText: oculto,
      maxLines: oculto ? 1 : lineas,
      maxLength: maxCaracteres,
      enabled: habilitado,
      textInputAction: accionTeclado,
      onFieldSubmitted: alEnviar,
      onChanged: alCambiar,
      autocorrect: !oculto,
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        helperMaxLines: 2,
        errorMaxLines: 3,
        prefixIcon: icono == null ? null : Icon(icono),
        suffixIcon: sufijo,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
