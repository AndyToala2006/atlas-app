import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../modelos/idea.dart';
import '../rutas/rutas.dart';
import '../tema/tema_atlas.dart';
import '../widgets/aviso_error.dart';
import '../widgets/tarjeta_idea.dart';

/// Detalle de una idea y punto de entrada a su edición y su borrado.
///
/// Se abre con `Navigator.pushNamed(..., arguments: idea)`, así que llega con
/// los datos que ya estaban en la lista y se pinta al instante. Pero esa copia
/// viene de `GET /ideas`, que NO incluye el campo `contenido`: el backend usa
/// un esquema ligero para el listado y otro completo para el detalle, de modo
/// que el texto largo no viaja en la petición que devuelve muchas filas. Por
/// eso la pantalla pide `GET /ideas/{id}` nada más abrirse cuando le falta el
/// contenido.
///
/// El botón "recargar" hace esa misma lectura de forma manual y explícita, para
/// comprobar en la defensa que la ruta exige el token y que lo que se ve es lo
/// que hay en la base de datos.
class PantallaDetalleIdea extends StatefulWidget {
  const PantallaDetalleIdea({super.key, required this.idea});

  final Idea idea;

  @override
  State<PantallaDetalleIdea> createState() => _PantallaDetalleIdeaState();
}

class _PantallaDetalleIdeaState extends State<PantallaDetalleIdea> {
  late Idea _idea = widget.idea;
  bool _recargando = false;
  bool _eliminando = false;

  /// Último fallo de una escritura o lectura lanzada desde esta pantalla. Se
  /// guarda aquí, y no se lee del controlador en el `build`, porque el
  /// controlador es compartido: un error dejado por otra pantalla no debe
  /// aparecer en este detalle, ni el de aquí sobrevivir a una recarga correcta.
  String? _mensajeError;

  @override
  void initState() {
    super.initState();
    if (_idea.contenido == null) {
      // Se marca ya el estado de carga para que el primer frame muestre el
      // marcador, y la petición se lanza en el frame siguiente porque leer el
      // ámbito y el ScaffoldMessenger exige un `context` montado en el árbol.
      _recargando = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recargar(avisar: false);
      });
    }
  }

  /// `GET /ideas/{id}`.
  ///
  /// [avisar] distingue las dos formas de llegar aquí: la carga automática de
  /// apertura es silenciosa, porque solo completa un dato que faltaba y el
  /// usuario no ha pedido nada; el botón manual sí confirma con un SnackBar,
  /// porque ahí la relectura es la acción en sí.
  Future<void> _recargar({required bool avisar}) async {
    final controlador = AmbitoAtlas.ideasDe(context);
    final mensajero = ScaffoldMessenger.of(context);

    setState(() {
      _recargando = true;
      _mensajeError = null;
    });

    final actualizada = await controlador.recargarIdea(_idea.id);
    if (!mounted) return;

    setState(() {
      if (actualizada != null) _idea = actualizada;
      // Si la recarga falla se enseña el motivo: hasta ahora el fallo no dejaba
      // ni rastro en la pantalla y parecía que el botón no hacía nada.
      _mensajeError = actualizada == null ? controlador.error : null;
      _recargando = false;
    });

    if (actualizada != null && avisar) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('Idea releída desde la base de datos.')),
      );
    }
  }

  /// Abre el formulario en modo edición y adopta la versión que devuelva.
  Future<void> _editar() async {
    final navegador = Navigator.of(context);
    final resultado = await navegador.pushNamed(
      Rutas.editarIdea,
      arguments: _idea,
    );
    if (!mounted) return;

    if (resultado is Idea) {
      setState(() => _idea = resultado);
      return;
    }

    // Se volvió sin guardar: aun así se relee del estado compartido, que es la
    // fuente única de verdad. `copiaCon` conserva el contenido ya leído si esa
    // copia viniera del listado ligero y por tanto lo trajera en null.
    final vigente = AmbitoAtlas.ideasDe(context).ideaPorId(_idea.id);
    if (vigente == null) return;
    setState(() {
      _idea = vigente.copiaCon(contenido: vigente.contenido ?? _idea.contenido);
    });
  }

  /// `DELETE /ideas/{id}`, siempre detrás de una confirmación.
  ///
  /// El borrado no tiene deshacer y arrastra publicaciones y métricas, así que
  /// no puede depender de un solo toque en la barra superior.
  Future<void> _eliminar() async {
    final controlador = AmbitoAtlas.ideasDe(context);
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('¿Eliminar esta idea?'),
        content: const Text(
          'La fila se borra de la base de datos junto con sus publicaciones y '
          'sus métricas. La acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contextoDialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('boton-confirmar-eliminar-idea'),
            onPressed: () => Navigator.of(contextoDialogo).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() {
      _eliminando = true;
      _mensajeError = null;
    });

    final eliminada = await controlador.eliminar(_idea.id);
    if (!mounted) return;

    if (eliminada) {
      // Primero se cierra el detalle: la idea que describe ya no existe. El
      // aviso se muestra sobre el listado, que es donde queda el usuario.
      navegador.pop();
      mensajero.showSnackBar(
        const SnackBar(content: Text('Idea eliminada de la base de datos.')),
      );
      return;
    }

    setState(() {
      _eliminando = false;
      _mensajeError = controlador.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sesion = AmbitoAtlas.sesionDe(context);
    final colorEstado = TemaAtlas.colorDeEstado(_idea.estado, tema.colorScheme);
    final ocupado = _recargando || _eliminando;

    return Scaffold(
      appBar: AppBar(
        title: Text('Idea #${_idea.id}'),
        actions: [
          IconButton(
            key: const Key('boton-editar-idea'),
            tooltip: 'Editar idea',
            icon: const Icon(Icons.edit_outlined),
            // Sin contenido no se puede editar: el formulario abriría el campo
            // vacío y el PATCH guardaría ese vacío encima del texto real.
            onPressed: ocupado || _idea.contenido == null ? null : _editar,
          ),
          IconButton(
            key: const Key('boton-eliminar-idea'),
            tooltip: 'Eliminar idea',
            icon: const Icon(Icons.delete_outline),
            onPressed: ocupado ? null : _eliminar,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_mensajeError != null) ...[
            AvisoError(
              mensaje: _mensajeError!,
              alCerrar: () => setState(() => _mensajeError = null),
            ),
            const SizedBox(height: 16),
          ],

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.09),
              borderRadius: TemaAtlas.bordeGrande,
              border: Border.all(color: colorEstado.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InsigniaEstado(estado: _idea.estado),
                const SizedBox(height: 14),
                Text(_idea.titulo, style: tema.textTheme.headlineSmall),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // IntrinsicHeight iguala la altura de las dos tarjetas aunque una
          // tenga el rótulo más largo que la otra.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Dato(
                    icono: Icons.article_outlined,
                    valor: '${_idea.numPublicaciones}',
                    rotulo: 'publicaciones',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Dato(
                    icono: _idea.origen == 'audio'
                        ? Icons.mic_none
                        : Icons.short_text,
                    valor: _idea.origen,
                    rotulo: 'origen',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // El texto que el usuario tecleó. Es el dato que justifica que exista
          // un endpoint de detalle separado del listado.
          Text('Contenido', style: tema.textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _contenido(tema),
            ),
          ),
          const SizedBox(height: 24),

          Text('Etiquetas', style: tema.textTheme.titleMedium),
          const SizedBox(height: 10),
          if (_idea.etiquetas.isEmpty)
            Text('Esta idea no tiene etiquetas.', style: tema.textTheme.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final etiqueta in _idea.etiquetas)
                  EtiquetaChip(texto: etiqueta),
              ],
            ),
          const SizedBox(height: 24),

          Text('Registro', style: tema.textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: tema.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Creada el ${_formatearFecha(_idea.creadoEn)}',
                        ),
                      ),
                    ],
                  ),
                  // Dato tomado del controlador de sesión: la identidad del
                  // usuario sigue disponible en una pantalla abierta con push,
                  // no solo en las pestañas del contenedor.
                  if (sesion.usuario != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 16, color: tema.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Pertenece a ${sesion.usuario!.nombre}'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          OutlinedButton.icon(
            onPressed: ocupado ? null : () => _recargar(avisar: true),
            icon: _recargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Recargar desde el backend'),
          ),
        ],
      ),
    );
  }

  /// El contenido tiene tres situaciones que distinguir, y confundirlas sería
  /// mentirle al usuario: ya está, se está pidiendo, o la petición falló y
  /// sigue sin estar.
  Widget _contenido(ThemeData tema) {
    final texto = _idea.contenido;
    if (texto != null) {
      return Text(texto, style: tema.textTheme.bodyMedium);
    }
    if (_recargando) return const _MarcadorContenido();
    return Text(
      'El contenido no se pudo leer desde el backend. Vuelve a intentarlo con '
      '"Recargar desde el backend".',
      style: tema.textTheme.bodySmall,
    );
  }

  static String _formatearFecha(DateTime fecha) {
    final local = fecha.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(local.day)}/${dos(local.month)}/${local.year} '
        '${dos(local.hour)}:${dos(local.minute)}';
  }
}

/// Marcador del contenido mientras `GET /ideas/{id}` está en vuelo.
///
/// Dibuja líneas del ancho aproximado del párrafo real: así el bloque no da un
/// salto de altura cuando llega la respuesta y la espera se lee como "esto se
/// está cargando" y no como "esto está vacío".
class _MarcadorContenido extends StatelessWidget {
  const _MarcadorContenido();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context)
        .colorScheme
        .onSurfaceVariant
        .withValues(alpha: 0.18);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ancho in const <double>[double.infinity, double.infinity, 170])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: ancho,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.valor, required this.rotulo});

  final IconData icono;
  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 18, color: tema.colorScheme.primary),
            const SizedBox(height: 10),
            Text(valor, style: tema.textTheme.titleLarge),
            Text(rotulo, style: tema.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
