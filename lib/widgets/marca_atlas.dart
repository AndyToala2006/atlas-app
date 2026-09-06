import 'package:flutter/material.dart';

import '../tema/tema_atlas.dart';

/// Logotipo de Atlas: un cuadrado con el degradado de marca y el icono.
///
/// Se usa en el arranque, en el login y en el registro. Al ser un solo widget,
/// la marca se ve idéntica en las tres pantallas.
class MarcaAtlas extends StatelessWidget {
  const MarcaAtlas({super.key, this.tamano = 72});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        gradient: TemaAtlas.degradado,
        borderRadius: BorderRadius.circular(tamano * 0.3),
        boxShadow: [
          BoxShadow(
            color: TemaAtlas.marca.withValues(alpha: 0.35),
            blurRadius: tamano * 0.32,
            offset: Offset(0, tamano * 0.14),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: tamano * 0.48,
      ),
    );
  }
}

/// Avatar circular con las iniciales del usuario sobre el degradado de marca.
class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({super.key, required this.iniciales, this.radio = 20});

  final String iniciales;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radio * 2,
      height: radio * 2,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: TemaAtlas.degradadoCorto,
        shape: BoxShape.circle,
      ),
      child: Text(
        iniciales,
        style: TextStyle(
          color: Colors.white,
          fontSize: radio * 0.72,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
