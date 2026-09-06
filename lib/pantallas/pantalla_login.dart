import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../estado/ambito_atlas.dart';
import '../rutas/rutas.dart';
import '../utiles/validadores.dart';
import '../widgets/aviso_error.dart';
import '../widgets/campo_texto.dart';

/// Formulario de inicio de sesión (`POST /auth/login`).
///
/// Es la ruta inicial de la aplicación y la única puerta de entrada a las
/// pantallas protegidas. Valida en el cliente antes de gastar una llamada de
/// red y muestra en un aviso lo que responda el backend cuando las
/// credenciales no son correctas.
class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _mostrarPassword = false;
  // Hasta el primer envío no se marca nada en rojo; después, cada pulsación
  // revalida el campo para que el error desaparezca en cuanto se corrige.
  AutovalidateMode _autovalidar = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final sesion = AmbitoAtlas.sesionDe(context);
    sesion.limpiarError();
    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) {
      setState(() => _autovalidar = AutovalidateMode.onUserInteraction);
      return;
    }

    final entro = await sesion.iniciarSesion(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted || !entro) return;

    _password.clear();
    // Se reemplaza toda la pila: desde el área privada no se debe poder
    // "volver atrás" al formulario de login con el botón del sistema.
    Navigator.of(context).pushNamedAndRemoveUntil(Rutas.inicio, (_) => false);
  }

  void _usarCuentaDemo() {
    _email.text = AppConfig.demoEmail;
    _password.text = AppConfig.demoPassword;
  }

  @override
  Widget build(BuildContext context) {
    final sesion = AmbitoAtlas.sesionDe(context);
    final tema = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: sesion,
          builder: (context, _) {
            final ocupado = sesion.ocupado;

            return Form(
              key: _formulario,
              autovalidateMode: _autovalidar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                children: [
                  Icon(Icons.auto_awesome,
                      size: 56, color: tema.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Atlas',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Captura ideas, conviértelas en publicaciones y mide cómo rinden.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  if (sesion.error != null) ...[
                    AvisoError(
                      mensaje: sesion.error!,
                      alCerrar: sesion.limpiarError,
                    ),
                    const SizedBox(height: 16),
                  ],

                  CampoTexto(
                    controlador: _email,
                    etiqueta: 'Correo electrónico',
                    icono: Icons.alternate_email,
                    tipoTeclado: TextInputType.emailAddress,
                    accionTeclado: TextInputAction.next,
                    habilitado: !ocupado,
                    validador: Validadores.correo,
                  ),
                  const SizedBox(height: 16),
                  CampoTexto(
                    controlador: _password,
                    etiqueta: 'Contraseña',
                    icono: Icons.lock_outline,
                    oculto: !_mostrarPassword,
                    accionTeclado: TextInputAction.done,
                    habilitado: !ocupado,
                    validador: Validadores.contrasena,
                    alEnviar: (_) => _entrar(),
                    sufijo: IconButton(
                      onPressed: () =>
                          setState(() => _mostrarPassword = !_mostrarPassword),
                      icon: Icon(_mostrarPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      tooltip: _mostrarPassword
                          ? 'Ocultar contraseña'
                          : 'Mostrar contraseña',
                    ),
                  ),
                  const SizedBox(height: 24),

                  FilledButton.icon(
                    key: const Key('boton-entrar'),
                    onPressed: ocupado ? null : _entrar,
                    icon: ocupado
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(ocupado ? 'Verificando…' : 'Iniciar sesión'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: ocupado
                        ? null
                        : () => Navigator.of(context).pushNamed(Rutas.registro),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Crear una cuenta'),
                  ),

                  if (AppConfig.hayCredencialesDemo) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: ocupado ? null : _usarCuentaDemo,
                      child: const Text('Rellenar con la cuenta de demostración'),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Estas dos entradas existen para la demostración: la primera
                  // deja comprobar la conectividad sin sesión; la segunda
                  // intenta abrir un área privada a propósito, para evidenciar
                  // que la guardia de rutas la bloquea.
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(Rutas.diagnostico),
                    icon: const Icon(Icons.network_check),
                    label: const Text('Diagnóstico de conexión'),
                  ),
                  TextButton.icon(
                    key: const Key('boton-intento-protegido'),
                    onPressed: () =>
                        Navigator.of(context).pushNamed(Rutas.inicio),
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('Intentar entrar sin iniciar sesión'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
