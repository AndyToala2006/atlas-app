import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../estado/ambito_atlas.dart';
import '../rutas/rutas.dart';
import '../tema/tema_atlas.dart';
import '../utiles/validadores.dart';
import '../widgets/aviso_error.dart';
import '../widgets/campo_texto.dart';

/// Autorregistro de usuarios (`POST /auth/register`).
///
/// El backend admite el alta directa, así que la aplicación la ofrece. Además
/// de las reglas de formato, el formulario replica los límites del esquema del
/// servidor (nombre 2–120, contraseña 6–72) y pide confirmar la contraseña,
/// que es una validación que solo existe en el cliente.
class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();

  String _tono = AppConfig.tonos.first;
  bool _mostrarPassword = false;
  AutovalidateMode _autovalidar = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    // La fuerza de la contraseña se recalcula mientras se escribe.
    _password.addListener(_alEscribirPassword);
  }

  void _alEscribirPassword() {
    setState(() {});
    if (_autovalidar != AutovalidateMode.disabled) {
      _formulario.currentState?.validate();
    }
  }

  @override
  void dispose() {
    _password.removeListener(_alEscribirPassword);
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final sesion = AmbitoAtlas.sesionDe(context);
    sesion.limpiarError();
    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) {
      setState(() => _autovalidar = AutovalidateMode.onUserInteraction);
      return;
    }

    final creada = await sesion.registrar(
      nombre: _nombre.text,
      email: _email.text,
      password: _password.text,
      tono: _tono,
    );
    if (!mounted || !creada) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cuenta creada. Bienvenido, ${sesion.usuario!.nombre}.'),
      ),
    );
    Navigator.of(context).pushNamedAndRemoveUntil(Rutas.inicio, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final sesion = AmbitoAtlas.sesionDe(context);
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: ListenableBuilder(
        listenable: sesion,
        builder: (context, _) {
          final ocupado = sesion.ocupado;

          return Form(
            key: _formulario,
            autovalidateMode: _autovalidar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text(
                  'Tu espacio de ideas',
                  style: tema.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'La cuenta se crea en el backend de Atlas y queda lista para usar.',
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
                  controlador: _nombre,
                  etiqueta: 'Nombre completo',
                  icono: Icons.badge_outlined,
                  tipoTeclado: TextInputType.name,
                  accionTeclado: TextInputAction.next,
                  maxCaracteres: 120,
                  habilitado: !ocupado,
                  validador: Validadores.nombre,
                ),
                const SizedBox(height: 8),
                CampoTexto(
                  controlador: _email,
                  etiqueta: 'Correo electrónico',
                  icono: Icons.alternate_email,
                  tipoTeclado: TextInputType.emailAddress,
                  accionTeclado: TextInputAction.next,
                  ayuda: 'Será tu usuario para iniciar sesión.',
                  habilitado: !ocupado,
                  validador: Validadores.correo,
                ),
                const SizedBox(height: 20),
                CampoTexto(
                  controlador: _password,
                  etiqueta: 'Contraseña',
                  icono: Icons.lock_outline,
                  oculto: !_mostrarPassword,
                  accionTeclado: TextInputAction.next,
                  habilitado: !ocupado,
                  validador: Validadores.contrasenaNueva,
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
                const SizedBox(height: 10),
                _MedidorClave(clave: _password.text),
                const SizedBox(height: 16),
                CampoTexto(
                  controlador: _confirmacion,
                  etiqueta: 'Repetir contraseña',
                  icono: Icons.lock_reset_outlined,
                  oculto: !_mostrarPassword,
                  accionTeclado: TextInputAction.done,
                  habilitado: !ocupado,
                  validador: (v) => Validadores.confirmacion(v, _password.text),
                  alEnviar: (_) => _registrar(),
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  initialValue: _tono,
                  decoration: const InputDecoration(
                    labelText: 'Tono de redacción',
                    helperText: 'Con este tono generará la IA tus publicaciones.',
                    prefixIcon: Icon(Icons.record_voice_over_outlined),
                  ),
                  items: [
                    for (final tono in AppConfig.tonos)
                      DropdownMenuItem(
                        value: tono,
                        child: Text(tono[0].toUpperCase() + tono.substring(1)),
                      ),
                  ],
                  onChanged: ocupado
                      ? null
                      : (valor) => setState(() => _tono = valor ?? _tono),
                ),
                const SizedBox(height: 28),

                FilledButton.icon(
                  key: const Key('boton-registrar'),
                  onPressed: ocupado ? null : _registrar,
                  icon: ocupado
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(ocupado ? 'Creando cuenta…' : 'Registrarme'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: ocupado ? null : () => Navigator.of(context).pop(),
                  child: const Text('Ya tengo cuenta, iniciar sesión'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Medidor visual de la fuerza de la contraseña.
///
/// No sustituye a la validación —esa la hace [Validadores.contrasenaNueva]—,
/// sino que la anticipa: el usuario ve si va bien antes de pulsar el botón.
class _MedidorClave extends StatelessWidget {
  const _MedidorClave({required this.clave});

  final String clave;

  int get _nivel {
    if (clave.isEmpty) return 0;
    var puntos = 0;
    if (clave.length >= 6) puntos++;
    if (clave.length >= 10) puntos++;
    if (clave.contains(RegExp(r'[0-9]'))) puntos++;
    if (clave.contains(RegExp(r'[^A-Za-z0-9]'))) puntos++;
    return puntos.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nivel = _nivel;

    const rotulos = ['', 'Débil', 'Aceptable', 'Buena', 'Fuerte'];
    final colores = [
      tema.colorScheme.outlineVariant,
      tema.colorScheme.error,
      TemaAtlas.realce,
      TemaAtlas.acento,
      const Color(0xFF10B981),
    ];

    return Row(
      children: [
        for (var i = 1; i <= 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: i <= nivel ? colores[nivel] : tema.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (i < 4) const SizedBox(width: 5),
        ],
        const SizedBox(width: 10),
        SizedBox(
          width: 78,
          child: Text(
            rotulos[nivel],
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tema.textTheme.bodySmall?.copyWith(
              color: nivel == 0 ? null : colores[nivel],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
