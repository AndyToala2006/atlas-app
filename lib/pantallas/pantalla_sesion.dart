import 'package:flutter/material.dart';

import '../api/atlas_api.dart';
import '../widgets/bloque_resultado.dart';

/// Autenticación contra `POST /auth/login`.
///
/// El backend devuelve un JWT que queda en memoria dentro de [AtlasApi] y se
/// envía en la cabecera `Authorization: Bearer` de las siguientes solicitudes.
class PantallaSesion extends StatefulWidget {
  const PantallaSesion({
    super.key,
    required this.api,
    required this.alCambiarSesion,
  });

  final AtlasApi api;
  final VoidCallback alCambiarSesion;

  @override
  State<PantallaSesion> createState() => _PantallaSesionState();
}

class _PantallaSesionState extends State<PantallaSesion> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'demo@atlas.app');
  final _password = TextEditingController(text: 'atlas123');

  bool _cargando = false;
  Widget? _resultado;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _resultado = null;
    });
    try {
      final login = await widget.api.iniciarSesion(_email.text.trim(), _password.text);
      final perfil = await widget.api.perfil();
      setState(() {
        _resultado = BloqueResultado(
          titulo: 'Sesión iniciada',
          detalle: 'Usuario ${perfil.datos['nombre']} (id ${perfil.datos['id']}).\n'
              'Token JWT recibido: ${_recortar(login.datos)}',
          respuesta: perfil,
        );
      });
      widget.alCambiarSesion();
    } on ErrorApi catch (e) {
      setState(() {
        _resultado = BloqueResultado(
          titulo: 'No se pudo iniciar sesión',
          detalle: e.mensaje,
          sugerencia: e.sugerencia,
          esError: true,
        );
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _salir() {
    widget.api.cerrarSesion();
    setState(() => _resultado = null);
    widget.alCambiarSesion();
  }

  static String _recortar(String token) =>
      token.length <= 24 ? token : '${token.substring(0, 24)}...';

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formulario,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
              if (!v.contains('@')) return 'El correo no tiene un formato válido';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _cargando ? null : _entrar,
            icon: _cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('Iniciar sesión'),
          ),
          if (widget.api.haySesion) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _salir,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
          const SizedBox(height: 16),
          ?_resultado,
        ],
      ),
    );
  }
}
