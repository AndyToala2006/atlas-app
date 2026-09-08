import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../modelos/idea.dart';
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

  AutovalidateMode _autovalidar = AutovalidateMode.disabled;

  bool get _esEdicion => widget.ideaAEditar != null;

  @override
  void initState() {
    super.initState();
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
    _titulo.dispose();
    _contenido.dispose();
    _etiquetas.dispose();
    super.dispose();
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
                  ayuda:
                      'Es el texto que usará la IA para generar la publicación.',
                  lineas: 5,
                  habilitado: !ocupado,
                  validador: Validadores.contenido,
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
