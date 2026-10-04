// Pruebas UNITARIAS del cliente HTTP (`AtlasApi`) y de los modelos que
// decodifica.
//
// Nivel unitario: el `http.Client` es un `MockClient`, asi que no hay red ni
// interfaz. Lo que se comprueba es el CONTRATO con el backend: que ruta,
// metodo, cabeceras y cuerpo salen como FastAPI los espera, y que cada
// respuesta (incluidos los errores) se traduce al modelo correcto. Si el
// backend cambia un nombre de campo, estas pruebas lo delatan antes que el
// usuario.

import 'dart:convert';

import 'package:atlas_app/modelos/publicacion.dart';
import 'package:atlas_app/modelos/respuesta_api.dart';
import 'package:atlas_app/modelos/trabajo_ia.dart';
import 'package:atlas_app/servicios/atlas_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _base = 'http://backend.prueba';

AtlasApi _api(Future<http.Response> Function(http.Request) manejador) =>
    AtlasApi(cliente: MockClient(manejador), baseUrl: _base)..token = 'jwt-1';

http.Response _json(Object cuerpo, [int codigo = 200]) => http.Response(
      jsonEncode(cuerpo),
      codigo,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('Publicar con IA', () {
    test('POST /ideas/{id}/publicar lleva el JWT y la red elegida, y devuelve '
        'el id del trabajo', () async {
      late http.Request enviada;
      final api = _api((peticion) async {
        enviada = peticion;
        return _json(
          {'job_id': 'abc-123', 'estado': 'queued', 'modo': 'asincrono'},
          202,
        );
      });

      final respuesta = await api.publicarIdea(7, RedSocial.linkedin);

      expect(enviada.method, 'POST');
      expect(enviada.url.toString(), '$_base/ideas/7/publicar');
      expect(enviada.headers['Authorization'], 'Bearer jwt-1');
      expect(jsonDecode(enviada.body), {'red_social': 'linkedin'});
      expect(respuesta.codigoEstado, 202);
      expect(respuesta.datos, 'abc-123');
    });

    test('GET /jobs/{id} distingue en curso, terminado y fallido', () async {
      final estados = ['processing', 'done', 'error'];
      final api = _api((_) async => _json({
            'id': 'abc-123',
            'idea_id': 7,
            'estado': estados.removeAt(0),
            'resultado_publicacion_id': null,
            'error': null,
          }));

      final enCurso = (await api.consultarTrabajo('abc-123')).datos;
      final terminado = (await api.consultarTrabajo('abc-123')).datos;
      final fallido = (await api.consultarTrabajo('abc-123')).datos;

      expect([enCurso.enCurso, enCurso.terminado], [true, false]);
      expect([terminado.enCurso, terminado.terminado], [false, true]);
      expect([fallido.enCurso, fallido.fallido], [false, true]);
    });

    test('GET /ideas/{id}/publicaciones decodifica texto, red y modelo, con '
        'tildes y emojis intactos', () async {
      final api = _api((_) async => _json([
            {
              'id': 3,
              'idea_id': 7,
              'red_social': 'x',
              'contenido_generado': 'Índices: de 800 ms a 12 ms 🚀',
              'tono': 'profesional',
              'estado': 'generada',
              'modelo_ia': 'anthropic/claude-haiku-4.5',
              'creado_en': '2026-09-08T12:00:00Z',
            },
          ]));

      final publicacion = (await api.listarPublicaciones(7)).datos.single;

      expect(publicacion.texto, 'Índices: de 800 ms a 12 ms 🚀');
      expect(RedSocial.desdeValor(publicacion.redSocial), RedSocial.x);
      expect(publicacion.esSimulada, isFalse);
    });
  });

  group('Errores', () {
    test('un 422 de Pydantic se traduce a los mensajes de cada campo', () async {
      final api = _api((_) async => _json({
            'detail': [
              {'loc': ['body', 'red_social'], 'msg': 'String should match pattern'},
            ],
          }, 422));

      await expectLater(
        api.publicarIdea(7, RedSocial.x),
        throwsA(
          isA<ErrorApi>()
              .having((e) => e.esValidacion, 'esValidacion', isTrue)
              .having((e) => e.mensaje, 'mensaje', 'String should match pattern'),
        ),
      );
    });

    test('un 401 se marca como sesion no autorizada', () async {
      final api = _api((_) async =>
          _json({'detail': 'Token inválido o expirado'}, 401));

      await expectLater(
        api.listarPublicaciones(7),
        throwsA(isA<ErrorApi>()
            .having((e) => e.esNoAutorizado, 'esNoAutorizado', isTrue)),
      );
    });
  });

  group('Paginacion y metricas', () {
    test('GET /ideas envia pagina y busqueda, y lee el total de X-Total-Count',
        () async {
      late http.Request enviada;
      final api = _api((peticion) async {
        enviada = peticion;
        return http.Response('[]', 200, headers: {'x-total-count': '57'});
      });

      final respuesta =
          await api.listarIdeas(desde: 40, busqueda: '  marca personal ');

      expect(enviada.url.queryParameters, {
        'optimized': 'true',
        'limit': '20',
        'offset': '40',
        'q': 'marca personal',
      });
      expect(respuesta.totalElementos, 57);
    });

    test('POST /publicaciones/{id}/metricas envia el registro manual completo',
        () async {
      late http.Request enviada;
      final api = _api((peticion) async {
        enviada = peticion;
        return _json({'ok': true, 'cache': 'invalidado', 'id': 1}, 201);
      });

      await api.registrarMetrica(
        9,
        likes: 120,
        comentarios: 8,
        compartidos: 3,
        alcance: 2400,
      );

      expect(enviada.url.path, '/publicaciones/9/metricas');
      expect(jsonDecode(enviada.body), {
        'fuente': 'manual',
        'likes': 120,
        'comentarios': 8,
        'compartidos': 3,
        'alcance': 2400,
      });
    });
  });

  test('TrabajoIa lee el id de la publicacion resultante', () {
    final trabajo = TrabajoIa.desdeJson({
      'id': 'abc',
      'idea_id': 7,
      'estado': 'done',
      'resultado_publicacion_id': 9,
      'error': null,
    });
    expect(trabajo.publicacionId, 9);
  });
}
