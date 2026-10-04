import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../estado/ambito_atlas.dart';
import '../modelos/idea.dart';
import '../modelos/metrica.dart';
import '../modelos/publicacion.dart';
import '../modelos/respuesta_api.dart';
import '../tema/tema_atlas.dart';
import '../utiles/validadores.dart';
import 'aviso_error.dart';

/// Sección del detalle de una idea que la convierte en publicaciones con IA.
///
/// Es la función central de Atlas: el usuario captura una idea (escrita o
/// dictada) y el backend la redacta para la red elegida con el tono de su
/// perfil. La pantalla no sabe nada del modelo de lenguaje ni de la API key:
/// solo encola el trabajo y muestra el resultado, así que cambiar de modelo
/// en el servidor no exige publicar una versión nueva de la app.
class SeccionPublicaciones extends StatefulWidget {
  const SeccionPublicaciones({
    super.key,
    required this.idea,
    required this.alActualizarIdea,
  });

  final Idea idea;

  /// Se invoca al terminar una generación con la versión vigente de la idea
  /// (nuevo estado y contador de publicaciones), para que el detalle la pinte.
  final ValueChanged<Idea> alActualizarIdea;

  @override
  State<SeccionPublicaciones> createState() => _SeccionPublicacionesState();
}

class _SeccionPublicacionesState extends State<SeccionPublicaciones> {
  RedSocial _red = RedSocial.instagram;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controlador = AmbitoAtlas.leer(context).publicaciones;
      // Se piden una sola vez por idea: al volver al detalle ya están en el
      // estado compartido y no se repite la petición.
      if (controlador.publicacionesDe(widget.idea.id) == null) {
        controlador.cargar(widget.idea.id);
      }
    });
  }

  Future<void> _generar() async {
    final ambito = AmbitoAtlas.de(context);
    final mensajero = ScaffoldMessenger.of(context);
    final red = _red;

    final nueva = await ambito.publicaciones.generar(widget.idea, red);
    if (!mounted) return;

    final vigente = ambito.ideas.ideaPorId(widget.idea.id);
    if (vigente != null) widget.alActualizarIdea(vigente);

    if (nueva != null) {
      mensajero.showSnackBar(
        SnackBar(content: Text('Publicación para ${red.nombre} lista.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controlador = AmbitoAtlas.publicacionesDe(context);
    final tema = Theme.of(context);
    final id = widget.idea.id;

    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        final generando = controlador.generandoPara(id);
        final error = controlador.errorDe(id);
        final publicaciones = controlador.publicacionesDe(id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Publicaciones con IA', style: tema.textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Elige la red y la IA redactará la idea con el tono de '
                      'tu perfil.',
                      style: tema.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<RedSocial>(
                      key: const Key('selector-red-social'),
                      segments: [
                        for (final red in RedSocial.values)
                          ButtonSegment(
                            value: red,
                            label: Text(red.nombre),
                            icon: Icon(_iconoDeRed(red)),
                          ),
                      ],
                      selected: {_red},
                      showSelectedIcon: false,
                      onSelectionChanged: generando
                          ? null
                          : (valores) => setState(() => _red = valores.first),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('boton-generar-publicacion'),
                      onPressed: generando ? null : _generar,
                      icon: generando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(generando ? 'Redactando…' : 'Generar con IA'),
                    ),
                    if (generando) ...[
                      const SizedBox(height: 10),
                      Text(
                        _describirTrabajo(controlador.estadoTrabajoDe(id)),
                        key: const Key('estado-trabajo-ia'),
                        textAlign: TextAlign.center,
                        style: tema.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              AvisoError(
                mensaje: error,
                alCerrar: () => controlador.descartarError(id),
              ),
            ],
            const SizedBox(height: 12),
            if (publicaciones == null && controlador.cargandoDe(id))
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (publicaciones == null || publicaciones.isEmpty)
              Text(
                'Esta idea todavía no tiene publicaciones.',
                style: tema.textTheme.bodySmall,
              )
            else
              for (final publicacion in publicaciones)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TarjetaPublicacion(publicacion: publicacion),
                ),
          ],
        );
      },
    );
  }

  static String _describirTrabajo(String? estado) => switch (estado) {
    'processing' => 'La IA está escribiendo tu publicación…',
    _ => 'Trabajo en cola en el servidor…',
  };
}

IconData _iconoDeRed(RedSocial red) => switch (red) {
  RedSocial.instagram => Icons.camera_alt_outlined,
  RedSocial.linkedin => Icons.work_outline,
  RedSocial.x => Icons.alternate_email,
};

class _TarjetaPublicacion extends StatelessWidget {
  const _TarjetaPublicacion({required this.publicacion});

  final Publicacion publicacion;

  Future<void> _copiar(BuildContext context) async {
    final mensajero = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: publicacion.texto));
    mensajero.showSnackBar(
      SnackBar(
        content: Text(
          'Copiada. Pégala en '
          '${RedSocial.desdeValor(publicacion.redSocial).nombre}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final red = RedSocial.desdeValor(publicacion.redSocial);
    final tenue = tema.colorScheme.onSurfaceVariant;

    return Card(
      key: Key('publicacion-${publicacion.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconoDeRed(red),
                  size: 18,
                  color: tema.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(red.nombre, style: tema.textTheme.titleSmall),
                ),
                IconButton(
                  key: Key('copiar-publicacion-${publicacion.id}'),
                  tooltip: 'Copiar texto',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () => _copiar(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SelectableText(
                publicacion.texto,
                style: tema.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: tema.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.7,
                ),
                borderRadius: TemaAtlas.bordeGrande,
              ),
              child: Text(
                publicacion.esSimulada
                    ? 'Generador simulado · sin API key'
                    : '${publicacion.modeloIa} · tono ${publicacion.tono}',
                style: tema.textTheme.labelSmall?.copyWith(color: tenue),
              ),
            ),
            const Divider(height: 28),
            // Cierre del ciclo de creación: cuánto rindió lo que se publicó.
            _ResumenRendimiento(publicacion: publicacion),
          ],
        ),
      ),
    );
  }
}

/// Último rendimiento registrado y las dos acciones sobre él: registrar uno
/// nuevo y ver la evolución en el tiempo.
class _ResumenRendimiento extends StatelessWidget {
  const _ResumenRendimiento({required this.publicacion});

  final Publicacion publicacion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ultima = publicacion.ultimaMetrica;
    final registros = publicacion.numMetricas == 1
        ? '1 registro'
        : '${publicacion.numMetricas} registros';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rendimiento', style: tema.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (ultima == null)
            Text(
              'Aún no registras cómo le fue. Hazlo cuando la publiques.',
              style: tema.textTheme.bodySmall,
            )
          else ...[
            _FilaMetricas(metrica: ultima),
            const SizedBox(height: 6),
            Text(
              'Medido el ${_fecha(ultima.fecha)} · $registros',
              style: tema.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.tonalIcon(
                key: Key('registrar-metrica-${publicacion.id}'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) =>
                      _HojaRegistrarMetrica(publicacion: publicacion),
                ),
                icon: const Icon(Icons.add_chart, size: 18),
                label: const Text('Registrar rendimiento'),
              ),
              if (publicacion.numMetricas > 0)
                TextButton.icon(
                  key: Key('historial-metricas-${publicacion.id}'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => _HojaHistorial(publicacion: publicacion),
                  ),
                  icon: const Icon(Icons.timeline, size: 18),
                  label: const Text('Ver evolución'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaMetricas extends StatelessWidget {
  const _FilaMetricas({required this.metrica});

  final Metrica metrica;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    Widget dato(IconData icono, int valor, String rotulo) => Tooltip(
      message: rotulo,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: tema.colorScheme.primary),
          const SizedBox(width: 4),
          Text(_compacto(valor), style: tema.textTheme.labelLarge),
        ],
      ),
    );

    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        dato(Icons.favorite_border, metrica.likes, 'Me gusta'),
        dato(Icons.chat_bubble_outline, metrica.comentarios, 'Comentarios'),
        dato(Icons.repeat, metrica.compartidos, 'Compartidos'),
        dato(Icons.visibility_outlined, metrica.alcance, 'Alcance'),
      ],
    );
  }
}

/// Formulario para registrar el rendimiento actual de una publicación.
///
/// El registro es MANUAL: las APIs de métricas de Instagram, LinkedIn y X son
/// de acceso restringido, así que el usuario copia los números que ve en la
/// red. El modelo de datos ya distingue `fuente = manual | api` para cuando la
/// captura automática sea posible.
class _HojaRegistrarMetrica extends StatefulWidget {
  const _HojaRegistrarMetrica({required this.publicacion});

  final Publicacion publicacion;

  @override
  State<_HojaRegistrarMetrica> createState() => _HojaRegistrarMetricaState();
}

class _HojaRegistrarMetricaState extends State<_HojaRegistrarMetrica> {
  final _formulario = GlobalKey<FormState>();

  // Se proponen los últimos valores: una nueva medición casi siempre parte de
  // la anterior y el usuario solo corrige lo que subió.
  late final Map<String, TextEditingController> _campos = () {
    final previa = widget.publicacion.ultimaMetrica;
    String texto(int? valor) => valor == null ? '' : '$valor';
    return {
      'likes': TextEditingController(text: texto(previa?.likes)),
      'comentarios': TextEditingController(text: texto(previa?.comentarios)),
      'compartidos': TextEditingController(text: texto(previa?.compartidos)),
      'alcance': TextEditingController(text: texto(previa?.alcance)),
    };
  }();

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final campo in _campos.values) {
      campo.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    final controlador = AmbitoAtlas.leer(context).publicaciones;
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    int valor(String clave) => int.parse(_campos[clave]!.text.trim());

    setState(() {
      _guardando = true;
      _error = null;
    });
    final error = await controlador.registrarMetrica(
      ideaId: widget.publicacion.ideaId,
      publicacionId: widget.publicacion.id,
      likes: valor('likes'),
      comentarios: valor('comentarios'),
      compartidos: valor('compartidos'),
      alcance: valor('alcance'),
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _guardando = false;
        _error = error;
      });
      return;
    }
    navegador.pop();
    mensajero.showSnackBar(
      const SnackBar(content: Text('Rendimiento registrado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final red = RedSocial.desdeValor(widget.publicacion.redSocial).nombre;

    Widget campo(String clave, String etiqueta, IconData icono) =>
        TextFormField(
          key: Key('campo-metrica-$clave'),
          controller: _campos[clave],
          enabled: !_guardando,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: etiqueta,
            prefixIcon: Icon(icono),
          ),
          validator: Validadores.metrica,
        );

    return Padding(
      // Sube con el teclado para que el botón de guardar no quede tapado.
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formulario,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rendimiento en $red', style: tema.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Copia los números que ves hoy en la publicación. Cada '
                'registro se guarda aparte, para que veas cómo evoluciona.',
                style: tema.textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AvisoError(mensaje: _error!),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: campo('likes', 'Me gusta', Icons.favorite_border),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: campo(
                      'comentarios',
                      'Comentarios',
                      Icons.chat_bubble_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: campo('compartidos', 'Compartidos', Icons.repeat),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: campo(
                      'alcance',
                      'Alcance',
                      Icons.visibility_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('boton-guardar-metrica'),
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Guardar registro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Evolución de una publicación: todos sus registros, del primero al último,
/// con la variación de interacciones respecto al registro anterior.
class _HojaHistorial extends StatefulWidget {
  const _HojaHistorial({required this.publicacion});

  final Publicacion publicacion;

  @override
  State<_HojaHistorial> createState() => _HojaHistorialState();
}

class _HojaHistorialState extends State<_HojaHistorial> {
  late final Future<List<Metrica>> _historial = AmbitoAtlas.leer(
    context,
  ).publicaciones.historial(widget.publicacion.id);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final red = RedSocial.desdeValor(widget.publicacion.redSocial).nombre;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: FutureBuilder<List<Metrica>>(
          future: _historial,
          builder: (context, instantanea) {
            if (instantanea.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (instantanea.hasError) {
              final error = instantanea.error;
              return AvisoError(
                mensaje: error is ErrorApi
                    ? error.mensaje
                    : 'No se pudo leer el historial.',
              );
            }
            final registros = instantanea.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Evolución en $red', style: tema.textTheme.titleLarge),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: registros.length,
                    separatorBuilder: (_, _) => const Divider(height: 20),
                    itemBuilder: (context, i) {
                      final actual = registros[i];
                      final variacion = i == 0
                          ? null
                          : actual.interacciones -
                                registros[i - 1].interacciones;
                      final sube = (variacion ?? 0) >= 0;
                      return Column(
                        key: Key('registro-metrica-${actual.id}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _fecha(actual.fecha),
                                  style: tema.textTheme.labelLarge,
                                ),
                              ),
                              if (variacion != null)
                                Text(
                                  '${sube ? '+' : ''}$variacion interacciones',
                                  style: tema.textTheme.labelMedium?.copyWith(
                                    color: sube
                                        ? TemaAtlas.colorDeEstado(
                                            'publicada',
                                            tema.colorScheme,
                                          )
                                        : tema.colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _FilaMetricas(metrica: actual),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _fecha(DateTime fecha) {
  final local = fecha.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(local.day)}/${dos(local.month)}/${local.year} '
      '${dos(local.hour)}:${dos(local.minute)}';
}

/// 1520 -> "1,5 k", 2300000 -> "2,3 M": las cifras de alcance son largas y en
/// una fila de cuatro datos desbordarían la tarjeta.
String _compacto(int n) {
  String formato(double v) {
    final texto = v.toStringAsFixed(v < 10 ? 1 : 0).replaceAll('.', ',');
    return texto.endsWith(',0') ? texto.substring(0, texto.length - 2) : texto;
  }

  if (n >= 1000000) return '${formato(n / 1000000)} M';
  if (n >= 1000) return '${formato(n / 1000)} k';
  return '$n';
}
