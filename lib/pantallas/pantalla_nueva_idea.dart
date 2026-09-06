import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../utiles/validadores.dart';
import '../widgets/aviso_error.dart';
import '../widgets/campo_texto.dart';

/// Formulario de creación de una idea (`POST /ideas`).
///
/// Es una ruta protegida más: sin sesión no se llega a ella, y sin sesión el
/// backend tampoco aceptaría el `POST`, porque la cabecera `Authorization`
/// viaja vacía.
///
/// Lo que se escribe se copia al controlador en cada pulsación. Así, si el
/// usuario sale de esta pantalla a mitad de la redacción, el texto sigue ahí
/// cuando vuelve: el borrador vive en el estado de la aplicación, no en el
/// widget.
class PantallaNuevaIdea extends StatefulWidget {
  const PantallaNuevaIdea({super.key});

  @override
  State<PantallaNuevaIdea> createState() => _PantallaNuevaIdeaState();
}

class _PantallaNuevaIdeaState extends State<PantallaNuevaIdea> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _contenido;
  late final TextEditingController _etiquetas;

  AutovalidateMode _autovalidar = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    // Los campos arrancan con el borrador guardado en el estado compartido.
    final ideas = AmbitoAtlas.leer(context).ideas;
    _titulo = TextEditingController(text: ideas.borradorTitulo);
    _contenido = TextEditingController(text: ideas.borradorContenido);
    _etiquetas = TextEditingController(text: ideas.borradorEtiquetas);
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

    final idea = await controlador.crear(
      titulo: _titulo.text,
      contenido: _contenido.text,
      etiquetas: Validadores.partirEtiquetas(_etiquetas.text),
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
        title: const Text('Nueva idea'),
        actions: [
          if (controlador.hayBorrador)
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
                  alCambiar: (v) => controlador.guardarBorrador(titulo: v),
                ),
                const SizedBox(height: 8),
                CampoTexto(
                  controlador: _contenido,
                  etiqueta: 'Contenido',
                  ayuda: 'Es el texto que usará la IA para generar la publicación.',
                  lineas: 5,
                  habilitado: !ocupado,
                  validador: Validadores.contenido,
                  alCambiar: (v) => controlador.guardarBorrador(contenido: v),
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
                  alCambiar: (v) => controlador.guardarBorrador(etiquetas: v),
                  alEnviar: (_) => _guardar(),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('boton-guardar-idea'),
                  onPressed: ocupado ? null : _guardar,
                  icon: ocupado
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(ocupado ? 'Guardando…' : 'Guardar idea'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
