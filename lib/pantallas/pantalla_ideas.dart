import 'package:flutter/material.dart';

import '../estado/ambito_atlas.dart';
import '../rutas/rutas.dart';
import '../widgets/aviso_error.dart';
import '../widgets/bloque_resultado.dart';
import '../widgets/tarjeta_idea.dart';

/// Listado de ideas del usuario autenticado (`GET /ideas`).
///
/// La pantalla no guarda las ideas: las pide al [ControladorIdeas] y se
/// redibuja cuando ese controlador avisa. Por eso al volver de otra pestaña o
/// del detalle de una idea la lista ya está cargada, sin repetir la llamada.
///
/// El interruptor "consulta optimizada" alterna el parámetro `optimized`, que
/// en el backend cambia entre eager loading y la versión con N+1; la
/// diferencia se lee en la cabecera `X-Query-Count` que se muestra en pantalla.
class PantallaIdeas extends StatefulWidget {
  const PantallaIdeas({super.key});

  @override
  State<PantallaIdeas> createState() => _PantallaIdeasState();
}

class _PantallaIdeasState extends State<PantallaIdeas> {
  @override
  void initState() {
    super.initState();
    // Primera carga automática al entrar al área privada, solo si aún no hay
    // datos en el estado compartido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ideas = AmbitoAtlas.leer(context).ideas;
      if (!ideas.hayDatos && !ideas.cargando && ideas.error == null) {
        ideas.cargar();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controlador = AmbitoAtlas.ideasDe(context);

    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).pushNamed(Rutas.nuevaIdea),
            icon: const Icon(Icons.add),
            label: Text(controlador.hayBorrador ? 'Seguir borrador' : 'Nueva idea'),
          ),
          body: RefreshIndicator(
            onRefresh: controlador.cargar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Consulta optimizada'),
                  subtitle: const Text('eager loading en el backend (sin N+1)'),
                  value: controlador.optimizado,
                  onChanged: controlador.cargando
                      ? null
                      : controlador.cambiarOptimizado,
                ),
                FilledButton.icon(
                  key: const Key('boton-cargar-ideas'),
                  onPressed: controlador.cargando ? null : controlador.cargar,
                  icon: controlador.cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                  label: const Text('Cargar ideas'),
                ),

                if (controlador.hayBorrador) ...[
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.edit_note),
                      title: const Text('Tienes un borrador sin guardar'),
                      subtitle: Text(
                        controlador.borradorTitulo.isEmpty
                            ? 'Sin título'
                            : controlador.borradorTitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context).pushNamed(Rutas.nuevaIdea),
                    ),
                  ),
                ],

                if (controlador.error != null) ...[
                  const SizedBox(height: 16),
                  AvisoError(mensaje: controlador.error!),
                ],

                if (controlador.ultimaRespuesta != null &&
                    controlador.error == null) ...[
                  const SizedBox(height: 16),
                  BloqueResultado(
                    titulo: '${controlador.ideas.length} ideas en tu cuenta',
                    detalle:
                        'GET /ideas?optimized=${controlador.optimizado}',
                    respuesta: controlador.ultimaRespuesta,
                  ),
                ],

                const SizedBox(height: 8),

                if (controlador.ideas.isEmpty && !controlador.cargando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Text(
                      'Todavía no hay ideas cargadas.\n'
                      'Pulsa "Cargar ideas" o crea la primera.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final idea in controlador.ideas)
                    TarjetaIdea(
                      idea: idea,
                      alPulsar: () => Navigator.of(context).pushNamed(
                        Rutas.detalleIdea,
                        arguments: idea,
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
