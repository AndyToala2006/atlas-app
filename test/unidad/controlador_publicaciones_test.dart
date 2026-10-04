// Pruebas UNITARIAS de `ControladorPublicaciones`: la logica del flujo
// asincrono (publicar -> consultar el job -> leer el resultado), sin interfaz.
//
// Es el punto mas fragil de la app: depende del worker de Celery, de la red y
// de un servicio externo (OpenRouter). Aqui se prueban los bordes que en el
// telefono son dificiles de provocar a proposito: un worker que nunca
// termina, un doble toque, y un cierre de sesion a mitad de la espera.

import 'dart:convert';

import 'package:atlas_app/estado/controlador_ideas.dart';
import 'package:atlas_app/estado/controlador_publicaciones.dart';
import 'package:atlas_app/estado/controlador_sesion.dart';
import 'package:atlas_app/modelos/idea.dart';
import 'package:atlas_app/modelos/publicacion.dart';
import 'package:atlas_app/servicios/almacen_sesion.dart';
import 'package:atlas_app/servicios/atlas_api.dart';
import 'package:atlas_app/servicios/notificaciones_servicio.dart';
import 'package:atlas_app/servicios/preferencias_locales.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _idea = Idea(
  id: 7,
  titulo: 'Indices en Postgres',
  estado: 'borrador',
  origen: 'texto',
  etiquetas: const [],
  numPublicaciones: 0,
  creadoEn: DateTime.utc(2026, 9, 1),
  contenido: 'Un indice bien puesto.',
);

/// Backend minimo: [consultasHastaTerminar] es cuantas veces responde
/// `processing` el job antes de pasar a `done` (null = nunca termina).
({ControladorPublicaciones controlador, Map<String, int> llamadas}) _preparar({
  int? consultasHastaTerminar = 2,
  Duration esperaMaxima = const Duration(seconds: 5),
}) {
  final llamadas = <String, int>{};
  var consultas = 0;

  final cliente = MockClient((peticion) async {
    final clave = '${peticion.method} ${peticion.url.path}';
    llamadas[clave] = (llamadas[clave] ?? 0) + 1;
    http.Response json(Object cuerpo, [int codigo = 200]) =>
        http.Response(jsonEncode(cuerpo), codigo);

    switch (clave) {
      case 'POST /ideas/7/publicar':
        return json({'job_id': 'j1', 'estado': 'queued', 'modo': 'asincrono'}, 202);
      case 'GET /jobs/j1':
        consultas++;
        final listo = consultasHastaTerminar != null &&
            consultas > consultasHastaTerminar;
        return json({
          'id': 'j1',
          'idea_id': 7,
          'estado': listo ? 'done' : 'processing',
          'resultado_publicacion_id': listo ? 11 : null,
          'error': null,
        });
      case 'GET /ideas/7/publicaciones':
        return json([
          {
            'id': 11,
            'idea_id': 7,
            'red_social': 'x',
            'contenido_generado': 'Post generado',
            'tono': 'cercano',
            'estado': 'generada',
            'modelo_ia': 'anthropic/claude-haiku-4.5',
            'creado_en': '2026-09-08T12:00:00Z',
          },
        ]);
      case 'GET /ideas/7':
        return json({
          'id': 7,
          'titulo': 'Indices en Postgres',
          'estado': 'publicada',
          'origen': 'texto',
          'etiquetas': [],
          'num_publicaciones': 1,
          'creado_en': '2026-09-01T00:00:00Z',
          'contenido': 'Un indice bien puesto.',
        });
    }
    return json({'detail': 'no simulada'}, 404);
  });

  final api = AtlasApi(cliente: cliente, baseUrl: 'http://prueba')..token = 't';
  final sesion = ControladorSesion(api: api, almacen: AlmacenSesionEnMemoria());
  final ideas = ControladorIdeas(
    api: api,
    sesion: sesion,
    notificaciones: NotificacionesServicioFalso(),
    preferencias: PreferenciasLocalesEnMemoria(),
  );
  final controlador = ControladorPublicaciones(
    api: api,
    sesion: sesion,
    ideas: ideas,
    intervaloConsulta: const Duration(milliseconds: 1),
    esperaMaxima: esperaMaxima,
  );
  return (controlador: controlador, llamadas: llamadas);
}

void main() {
  test('consulta el job hasta "done" y devuelve la publicacion resultante',
      () async {
    final (:controlador, :llamadas) = _preparar(consultasHastaTerminar: 2);

    final publicacion = await controlador.generar(_idea, RedSocial.x);

    expect(publicacion?.id, 11);
    expect(llamadas['POST /ideas/7/publicar'], 1);
    expect(llamadas['GET /jobs/j1'], 3);
    expect(controlador.publicacionesDe(7), hasLength(1));
    expect(controlador.generandoPara(7), isFalse);
    expect(controlador.errorDe(7), isNull);
  });

  test('si el worker nunca termina, deja de consultar y lo explica', () async {
    final (:controlador, :llamadas) = _preparar(
      consultasHastaTerminar: null,
      esperaMaxima: const Duration(milliseconds: 20),
    );

    final publicacion = await controlador.generar(_idea, RedSocial.instagram);

    expect(publicacion, isNull);
    // Tope = esperaMaxima / intervalo = 20 consultas, ni una mas.
    expect(llamadas['GET /jobs/j1'], 20);
    expect(controlador.errorDe(7), contains('worker'));
    expect(controlador.generandoPara(7), isFalse);
  });

  test('un doble toque no encola dos trabajos', () async {
    final (:controlador, :llamadas) = _preparar();

    final primero = controlador.generar(_idea, RedSocial.x);
    final segundo = await controlador.generar(_idea, RedSocial.x);
    await primero;

    expect(segundo, isNull);
    expect(llamadas['POST /ideas/7/publicar'], 1);
  });

  test('cerrar sesion durante la espera descarta el resultado', () async {
    final (:controlador, :llamadas) = _preparar(consultasHastaTerminar: 5);

    final enCurso = controlador.generar(_idea, RedSocial.x);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    controlador.limpiar();

    expect(await enCurso, isNull);
    expect(controlador.publicacionesDe(7), isNull);
    expect(llamadas['GET /ideas/7/publicaciones'], isNull);
  });
}
