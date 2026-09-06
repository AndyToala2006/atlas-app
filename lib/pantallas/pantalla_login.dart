import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../estado/ambito_atlas.dart';
import '../rutas/rutas.dart';
import '../tema/tema_atlas.dart';
import '../utiles/validadores.dart';
import '../widgets/aviso_error.dart';
import '../widgets/campo_texto.dart';

/// Formulario de inicio de sesión (`POST /auth/login`).
///
/// Es la ruta inicial de la aplicación cuando no hay sesión guardada y la
/// única puerta de entrada a las pantallas protegidas. Valida en el cliente
/// antes de gastar una llamada de red y muestra en un aviso lo que responda el
/// backend cuando las credenciales no son correctas.
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
      // El fondo es el de la tarjeta del formulario, para que la pantalla se
      // lea como una sola pieza: degradado arriba, superficie clara abajo.
      backgroundColor: tema.colorScheme.surface,
      body: ListenableBuilder(
        listenable: sesion,
        builder: (context, _) {
          final ocupado = sesion.ocupado;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Cabecera con el degradado de marca.
                const _CabeceraMarca(),

                Container(
                  // Sube sobre el degradado: la esquina redondeada monta unos
                  // píxeles encima de la cabecera.
                  transform: Matrix4.translationValues(0, -22, 0),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
                  child: Form(
                    key: _formulario,
                    autovalidateMode: _autovalidar,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Inicia sesión', style: tema.textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Entra con tu cuenta para ver tus ideas y tus métricas.',
                          style: tema.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),

                        if (sesion.error != null) ...[
                          AvisoError(
                            mensaje: sesion.error!,
                            alCerrar: sesion.limpiarError,
                          ),
                          const SizedBox(height: 18),
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
                            onPressed: () => setState(
                                () => _mostrarPassword = !_mostrarPassword),
                            icon: Icon(_mostrarPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            tooltip: _mostrarPassword
                                ? 'Ocultar contraseña'
                                : 'Mostrar contraseña',
                          ),
                        ),

                        if (AppConfig.hayCredencialesDemo)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: ocupado ? null : _usarCuentaDemo,
                              child: const Text('Usar cuenta de demostración'),
                            ),
                          )
                        else
                          const SizedBox(height: 24),

                        FilledButton.icon(
                          key: const Key('boton-entrar'),
                          onPressed: ocupado ? null : _entrar,
                          icon: ocupado
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(ocupado ? 'Verificando…' : 'Iniciar sesión'),
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('¿es tu primera vez?',
                                  style: tema.textTheme.bodySmall),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        OutlinedButton.icon(
                          onPressed: ocupado
                              ? null
                              : () =>
                                  Navigator.of(context).pushNamed(Rutas.registro),
                          icon: const Icon(Icons.person_add_alt),
                          label: const Text('Crear una cuenta'),
                        ),

                        const SizedBox(height: 20),

                        // Estas dos entradas existen para la demostración: la
                        // primera comprueba la conectividad sin sesión; la
                        // segunda intenta abrir un área privada a propósito,
                        // para evidenciar que la guardia de rutas la bloquea.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: TextButton.icon(
                                onPressed: () => Navigator.of(context)
                                    .pushNamed(Rutas.diagnostico),
                                icon: const Icon(Icons.network_check, size: 18),
                                label: const Text('Diagnóstico de conexión'),
                              ),
                            ),
                            Flexible(
                              child: TextButton.icon(
                                key: const Key('boton-intento-protegido'),
                                onPressed: () =>
                                    Navigator.of(context).pushNamed(Rutas.inicio),
                                icon: const Icon(Icons.shield_outlined, size: 18),
                                label: const Text('Probar acceso directo'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Cabecera degradada con el logotipo y el eslogan del proyecto.
class _CabeceraMarca extends StatelessWidget {
  const _CabeceraMarca();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: TemaAtlas.degradado),
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 36,
        24,
        48,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 18),
          const Text(
            'Atlas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Captura ideas, conviértelas en publicaciones\ny mide cómo rinden.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
