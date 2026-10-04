import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../modelos/estado_permiso.dart';
import '../modelos/idea.dart';
import '../servicios/voz_servicio.dart';
import '../utiles/validadores.dart';
import '../widgets/aviso_error.dart';
import '../widgets/campo_texto.dart';

/// Formulario de una idea: la crea (`POST /ideas`) o la edita (`PATCH
/// /ideas/{id}`).
///
/// Es una sola pantalla para las dos operaciones porque los campos, las
/// validaciones y los mensajes de error son exactamente los mismos; duplicarla
/// obligaría a corregir cada regla dos veces y a que las dos copias se
/// separaran a la primera. Lo único que cambia es a dónde va la escritura, y
/// eso lo decide [ideaAEditar].
///
/// Es una ruta protegida más: sin sesión no se llega a ella, y sin sesión el
/// backend tampoco aceptaría la escritura, porque la cabecera `Authorization`
/// viajaría vacía.
///
/// Al CREAR, lo que se escribe se copia al controlador en cada pulsación. Así,
/// si el usuario sale de esta pantalla a mitad de la redacción, el texto sigue
/// ahí cuando vuelve: el borrador vive en el estado de la aplicación, no en el
/// widget. Al EDITAR el borrador no se toca en ningún momento: es el buzón de
/// una idea nueva a medio escribir y no puede perderse porque alguien haya
/// entrado a corregir una coma en otra idea ya guardada.
class PantallaNuevaIdea extends StatefulWidget {
  const PantallaNuevaIdea({super.key, this.ideaAEditar});

  /// Idea que se está editando, o `null` cuando la pantalla se abre para crear.
  final Idea? ideaAEditar;

  @override
  State<PantallaNuevaIdea> createState() => _PantallaNuevaIdeaState();
}

class _PantallaNuevaIdeaState extends State<PantallaNuevaIdea> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _contenido;
  late final TextEditingController _etiquetas;
  late final VozServicio _voz;

  AutovalidateMode _autovalidar = AutovalidateMode.disabled;

  // --------------------------------------------------- dictado por voz (S14)

  /// `true` mientras el micrófono está escuchando. Controla el icono, el
  /// texto de ayuda del campo y si se puede volver a pulsar "Guardar".
  bool _escuchando = false;

  /// `true` si el contenido final incluyó, en todo o en parte, texto dictado.
  /// Decide el `origen` (`'texto'` o `'audio'`) que se envía al crear la idea;
  /// en edición no se usa, porque `PATCH /ideas/{id}` no cambia el origen.
  bool _origenAudio = false;

  /// Lo que había en el campo "Contenido" antes de tocar el micrófono. El
  /// motor de reconocimiento entrega, en cada `onResult`, el texto COMPLETO
  /// de la sesión de escucha en curso, no solo lo nuevo; hay que recomponerlo
  /// sobre lo que ya estaba escrito, o cada palabra reconocida borraría la
  /// anterior.
  String _contenidoAntesDeEscuchar = '';

  bool get _esEdicion => widget.ideaAEditar != null;

  @override
  void initState() {
    super.initState();
    _voz = AmbitoAtlas.leer(context).voz;
    final idea = widget.ideaAEditar;
    if (idea != null) {
      // Edición: los campos arrancan con lo que hay hoy en la base de datos.
      // `contenido` es nullable porque el listado no lo trae, pero el detalle
      // no habilita el botón de editar hasta haberlo leído, así que aquí ya
      // tiene valor; el `?? ''` es la red por si se llegara de otra forma.
      _titulo = TextEditingController(text: idea.titulo);
      _contenido = TextEditingController(text: idea.contenido ?? '');
      _etiquetas = TextEditingController(text: idea.etiquetas.join(', '));
    } else {
      // Creación: los campos arrancan con el borrador del estado compartido.
      final ideas = AmbitoAtlas.leer(context).ideas;
      _titulo = TextEditingController(text: ideas.borradorTitulo);
      _contenido = TextEditingController(text: ideas.borradorContenido);
      _etiquetas = TextEditingController(text: ideas.borradorEtiquetas);
    }
  }

  @override
  void dispose() {
    // La escucha no debe seguir corriendo -ni el motor nativo ocupado- una
    // vez que la pantalla que la pidió ya no existe.
    if (_escuchando) _voz.cancelar();
    _titulo.dispose();
    _contenido.dispose();
    _etiquetas.dispose();
    super.dispose();
  }

  // --------------------------------------------------- dictado por voz (S14)

  /// Alterna entre escuchar y detener. Antes de la primera escucha resuelve,
  /// en orden, los tres bloqueos posibles: permiso denegado (con explicación
  /// previa, tal como exige el taller), permiso en denegación permanente o
  /// restringido (con salida a ajustes) y, ya con permiso, la disponibilidad
  /// real del reconocedor del dispositivo.
  Future<void> _alternarDictado() async {
    if (_escuchando) {
      await _voz.detener();
      if (mounted) setState(() => _escuchando = false);
      return;
    }

    var estado = await _voz.estadoPermiso();
    if (!mounted) return;

    if (!estado.concedidoOk) {
      if (estado.requiereAjustes) {
        await _ofrecerAbrirAjustes(estado);
        return;
      }

      final continuar = await _confirmarUsoDeMicrofono();
      if (!mounted || continuar != true) return;

      estado = await _voz.solicitarPermiso();
      if (!mounted) return;

      if (!estado.concedidoOk) {
        if (estado.requiereAjustes) {
          await _ofrecerAbrirAjustes(estado);
        } else {
          _mostrarAviso(
            'Sin permiso de micrófono no se puede dictar. Puedes escribir '
            'tu idea a mano.',
          );
        }
        return;
      }
    }

    final disponible = await _voz.hayReconocimientoDisponible();
    if (!mounted) return;
    if (!disponible) {
      // El permiso está concedido pero el SERVICIO de reconocimiento no
      // responde (por ejemplo, sin Google app en un Android sin Play
      // Services): es la condición de indisponibilidad distinta del permiso
      // que la guía del taller pide distinguir.
      _mostrarAviso(
        'El reconocimiento de voz no está disponible en este dispositivo. '
        'Puedes escribir tu idea a mano.',
      );
      return;
    }

    _contenidoAntesDeEscuchar = _contenido.text;
    setState(() => _escuchando = true);

    await _voz.escuchar(
      alReconocerParcial: _incorporarTextoDictado,
      alFinalizar: (texto) {
        _incorporarTextoDictado(texto);
        if (mounted) setState(() => _escuchando = false);
      },
      alFallar: () {
        if (!mounted) return;
        setState(() => _escuchando = false);
        _mostrarAviso(
          'No se pudo escuchar el micrófono. Intenta de nuevo o escribe tu '
          'idea a mano.',
        );
      },
    );
  }

  void _incorporarTextoDictado(String texto) {
    if (texto.isEmpty) return;
    final combinado = [
      if (_contenidoAntesDeEscuchar.isNotEmpty) _contenidoAntesDeEscuchar,
      texto,
    ].join(' ');
    _contenido.value = TextEditingValue(
      text: combinado,
      selection: TextSelection.collapsed(offset: combinado.length),
    );
    _origenAudio = true;
    if (!_esEdicion) {
      AmbitoAtlas.ideasDe(context).guardarBorrador(contenido: combinado);
    }
  }

  /// Explica, ANTES de pedir el permiso, para qué se va a usar el micrófono.
  /// Es la explicación previa que exige el taller: el diálogo del sistema
  /// operativo no da espacio para justificarlo, así que este va primero.
  Future<bool?> _confirmarUsoDeMicrofono() {
    return showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.mic_none),
        title: const Text('Usar el micrófono'),
        content: const Text(
          'Atlas va a pedir permiso de micrófono para dictar el contenido de '
          'esta idea. Solo se activa mientras hablas y se puede detener en '
          'cualquier momento tocando el mismo botón.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  /// Denegación permanente o restricción del sistema: pedir el permiso de
  /// nuevo no haría nada, así que la única salida es ir a los ajustes.
  Future<void> _ofrecerAbrirAjustes(EstadoPermiso estado) async {
    if (estado == EstadoPermiso.restringido) {
      _mostrarAviso(
        'El micrófono está restringido en este dispositivo por una política '
        'del sistema. Puedes escribir tu idea a mano.',
      );
      return;
    }

    final abrir = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: Icon(Icons.mic_off, color: Theme.of(dialogo).colorScheme.error),
        title: const Text('Micrófono bloqueado'),
        content: const Text(
          'Bloqueaste el permiso de micrófono y el sistema ya no vuelve a '
          'preguntar. Para dictar tu idea, actívalo desde los ajustes de la '
          'aplicación. Mientras tanto puedes escribirla a mano.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );

    if (abrir == true) await _voz.abrirAjustesDeLaApp();
  }

  void _mostrarAviso(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _guardar() async {
    final controlador = AmbitoAtlas.ideasDe(context);
    FocusScope.of(context).unfocus();

    if (!_formulario.currentState!.validate()) {
      setState(() => _autovalidar = AutovalidateMode.onUserInteraction);
      return;
    }

    final etiquetas = Validadores.partirEtiquetas(_etiquetas.text);
    final ideaEnEdicion = widget.ideaAEditar;

    if (ideaEnEdicion != null) {
      final actualizada = await controlador.editar(
        id: ideaEnEdicion.id,
        titulo: _titulo.text,
        contenido: _contenido.text,
        etiquetas: etiquetas,
      );
      if (!mounted || actualizada == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Idea actualizada en la base de datos.')),
      );
      // Se devuelve la idea ya persistida para que el detalle pinte la versión
      // nueva sin tener que volver a pedirla al backend.
      Navigator.of(context).pop(actualizada);
      return;
    }

    final idea = await controlador.crear(
      titulo: _titulo.text,
      contenido: _contenido.text,
      etiquetas: etiquetas,
      origen: _origenAudio ? 'audio' : 'texto',
    );
    if (!mounted || idea == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Idea guardada en la base de datos con id ${idea.id}.'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controlador = AmbitoAtlas.ideasDe(context);
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar idea' : 'Nueva idea'),
        actions: [
          // "Descartar" borra el borrador, que solo existe en la creación: en
          // edición no habría nada que descartar y el botón daría a entender
          // que se puede deshacer una fila ya guardada.
          if (!_esEdicion && controlador.hayBorrador)
            TextButton(
              onPressed: () {
                controlador.descartarBorrador();
                _titulo.clear();
                _contenido.clear();
                _etiquetas.clear();
              },
              child: const Text('Descartar'),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controlador,
        builder: (context, _) {
          final ocupado = controlador.cargando;

          return Form(
            key: _formulario,
            autovalidateMode: _autovalidar,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (controlador.error != null) ...[
                  AvisoError(mensaje: controlador.error!),
                  const SizedBox(height: 16),
                ],
                CampoTexto(
                  controlador: _titulo,
                  etiqueta: 'Título',
                  icono: Icons.title,
                  accionTeclado: TextInputAction.next,
                  maxCaracteres: 160,
                  habilitado: !ocupado,
                  validador: Validadores.titulo,
                  alCambiar: _esEdicion
                      ? null
                      : (v) => controlador.guardarBorrador(titulo: v),
                ),
                const SizedBox(height: 8),
                CampoTexto(
                  controlador: _contenido,
                  etiqueta: 'Contenido',
                  ayuda: _escuchando
                      ? 'Escuchando… toca el micrófono para detener.'
                      : 'Es el texto que usará la IA para generar la '
                          'publicación. Puedes escribirlo o dictarlo.',
                  lineas: 5,
                  habilitado: !ocupado,
                  validador: Validadores.contenido,
                  sufijo: IconButton(
                    key: const Key('boton-dictar-idea'),
                    tooltip: _escuchando ? 'Detener dictado' : 'Dictar por voz',
                    isSelected: _escuchando,
                    icon: Icon(_escuchando ? Icons.mic : Icons.mic_none),
                    color: _escuchando ? tema.colorScheme.error : null,
                    onPressed: ocupado ? null : _alternarDictado,
                  ),
                  alCambiar: _esEdicion
                      ? null
                      : (v) => controlador.guardarBorrador(contenido: v),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controlador: _etiquetas,
                  etiqueta: 'Etiquetas (opcional)',
                  icono: Icons.sell_outlined,
                  ayuda: 'Separadas por coma. Máximo 5.',
                  accionTeclado: TextInputAction.done,
                  habilitado: !ocupado,
                  validador: Validadores.etiquetas,
                  alCambiar: _esEdicion
                      ? null
                      : (v) => controlador.guardarBorrador(etiquetas: v),
                  alEnviar: (_) => _guardar(),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  // Cada operación tiene su propia clave para que una prueba de
                  // widget pueda distinguir el alta de la edición.
                  key: _esEdicion
                      ? const Key('boton-actualizar-idea')
                      : const Key('boton-guardar-idea'),
                  onPressed: ocupado ? null : _guardar,
                  icon: ocupado
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_esEdicion ? Icons.check : Icons.save_outlined),
                  label: Text(
                    ocupado
                        ? 'Guardando…'
                        : _esEdicion
                            ? 'Guardar cambios'
                            : 'Guardar idea',
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
