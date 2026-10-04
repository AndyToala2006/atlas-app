// Pruebas del flujo de autenticacion, navegacion, estado, formularios y CRUD
// completo de ideas (Talleres Semana 12 y Semana 13).
//
// El backend se sustituye por un `MockClient` de package:http y el almacen
// cifrado por uno en memoria, de modo que las pruebas recorren el flujo
// completo -restauracion de sesion, validaciones, login correcto, login
// rechazado, navegacion entre pantallas, permanencia del estado, cierre de
// sesion, bloqueo de las rutas privadas y el ciclo de vida del dato: crear,
// consultar, editar y eliminar una idea- sin necesitar la API levantada ni
// el canal nativo del plugin de almacenamiento.

import 'dart:convert';

import 'package:atlas_app/config/app_config.dart';
import 'package:atlas_app/main.dart';
import 'package:atlas_app/modelos/estado_permiso.dart';
import 'package:atlas_app/modelos/idea.dart';
import 'package:atlas_app/rutas/rutas.dart';
import 'package:atlas_app/servicios/almacen_sesion.dart';
import 'package:atlas_app/servicios/atlas_api.dart';
import 'package:atlas_app/servicios/notificaciones_servicio.dart';
import 'package:atlas_app/servicios/preferencias_locales.dart';
import 'package:atlas_app/servicios/voz_servicio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _baseUrl = 'http://backend.prueba';
const _tokenValido = 'jwt-de-prueba-1234567890';
const _tokenCaducado = 'jwt-caducado';

/// Texto largo de la idea sembrada. Solo lo devuelve `GET /ideas/{id}`: el
/// listado usa el esquema ligero, asi que si aparece en pantalla es porque la
/// pantalla de detalle fue a buscarlo.
const _contenidoIdeaSembrada =
    'Guion de tres capitulos: indices, cache y el problema N+1.';

/// Contador de llamadas, para comprobar que el estado compartido evita repetir
/// peticiones al volver a una pantalla ya visitada y que cada operacion golpea
/// la ruta que le toca.
///
/// Se anota cada peticion con DOS claves: la ruta sola -que es la que usan las
/// pruebas de las semanas anteriores- y la ruta precedida de su metodo. Desde
/// la Semana 13 una misma ruta admite GET, PATCH y DELETE, y hay pruebas que
/// necesitan distinguirlos: comprobar que cancelar un borrado no lanza el
/// DELETE seria imposible si las tres llamadas cayeran en el mismo contador.
late Map<String, int> llamadas;

/// Tabla de ideas del backend simulado, indexada por id. Que las respuestas
/// salgan de aqui -y no de literales sueltos por ruta- es lo que hace que el
/// ciclo completo sea coherente: lo que crea el POST se ve luego en el GET, lo
/// que cambia el PATCH aparece en el listado y lo que borra el DELETE
/// desaparece de verdad.
late Map<int, Map<String, dynamic>> ideasDelBackend;

/// Publicaciones del backend simulado por id de idea, la mas reciente primero,
/// como las devuelve `GET /ideas/{id}/publicaciones`.
late Map<int, List<Map<String, dynamic>>> publicacionesDelBackend;

/// Registros de rendimiento por id de publicacion, en orden cronologico, como
/// los guarda `POST /publicaciones/{id}/metricas`.
late Map<int, List<Map<String, dynamic>>> metricasDelBackend;

/// Ultimo cuerpo recibido por `POST /auth/register`, para comprobar que el
/// tono elegido en el formulario viaja al backend.
Map<String, dynamic>? ultimoRegistro;

/// Almacen de la sesion de la prueba en curso, para inspeccionar el token.
late AlmacenSesionEnMemoria almacen;

/// Backend simulado. [passwordValida] es la unica clave que acepta el login;
/// [detalleFalla] hace que `GET /ideas/{id}` responda 404 para poder recorrer
/// el camino de error de la pantalla de detalle; [iaFalla] hace que el trabajo
/// de generacion termine en `error`, como cuando OpenRouter rechaza la key.
http.Client _backendFalso({
  String passwordValida = 'claveDePrueba1',
  bool detalleFalla = false,
  bool iaFalla = false,
  int ideasExtra = 0,
}) {
  llamadas = <String, int>{};
  metricasDelBackend = {};
  ultimoRegistro = null;
  ideasDelBackend = {
    7: {
      'id': 7,
      'titulo': 'Serie sobre optimizacion de APIs',
      'estado': 'borrador',
      'origen': 'texto',
      'etiquetas': ['backend', 'movil'],
      'num_publicaciones': 2,
      'creado_en': '2026-09-01T10:30:00Z',
      'contenido': _contenidoIdeaSembrada,
    },
  };
  // Ideas adicionales para ejercitar la paginacion. Llevan ids altos para que,
  // ordenadas como en el backend real (la mas reciente primero), queden antes
  // que la idea sembrada.
  for (var i = 0; i < ideasExtra; i++) {
    final id = 100 + i;
    ideasDelBackend[id] = {
      'id': id,
      'titulo': 'Idea de relleno $i',
      'estado': 'borrador',
      'origen': 'texto',
      'etiquetas': <String>[],
      'num_publicaciones': 0,
      'creado_en': '2026-09-05T10:00:00Z',
      'contenido': 'Contenido de relleno $i',
    };
  }
  var siguienteId = 8;
  var siguienteMetricaId = 1;
  publicacionesDelBackend = {
    7: [
      {
        'id': 2,
        'idea_id': 7,
        'red_social': 'linkedin',
        'contenido_generado': 'Tres lecciones sobre optimizar APIs. #backend',
        'tono': 'profesional',
        'estado': 'generada',
        'modelo_ia': 'anthropic/claude-haiku-4.5',
        'creado_en': '2026-09-02T10:00:00Z',
      },
      {
        'id': 1,
        'idea_id': 7,
        'red_social': 'instagram',
        'contenido_generado': 'Te cuento algo sobre indices. #atlas',
        'tono': 'profesional',
        'estado': 'generada',
        'modelo_ia': 'atlas-sim-1',
        'creado_en': '2026-09-01T11:00:00Z',
      },
    ],
  };
  var siguientePublicacionId = 3;

  // Trabajos de generacion: cada uno avanza un paso por consulta, igual que el
  // worker real: queued -> processing -> done (o error).
  final trabajos = <String, Map<String, dynamic>>{};

  return MockClient((peticion) async {
    final ruta = peticion.url.path;
    llamadas[ruta] = (llamadas[ruta] ?? 0) + 1;
    final conMetodo = '${peticion.method} $ruta';
    llamadas[conMetodo] = (llamadas[conMetodo] ?? 0) + 1;

    // Las rutas de una idea concreta llevan el id en el camino (`/ideas/12`),
    // asi que no se pueden comparar como literales. Se normalizan a
    // `/ideas/{id}` y el id se guarda aparte, que es exactamente lo que hace
    // el enrutador de FastAPI antes de entregar el parametro al endpoint.
    final segmentos = peticion.url.pathSegments;
    final esRutaDeIdea = segmentos.length >= 2 && segmentos.first == 'ideas';
    final idEnRuta = esRutaDeIdea ? int.tryParse(segmentos[1]) : null;
    final esRutaDeJob = segmentos.length == 2 && segmentos.first == 'jobs';
    final esRutaDeMetricas =
        segmentos.length == 3 && segmentos.first == 'publicaciones';
    final idPublicacion = esRutaDeMetricas ? int.tryParse(segmentos[1]) : null;
    final patron = esRutaDeIdea
        ? '/ideas/{id}${segmentos.length == 3 ? '/${segmentos[2]}' : ''}'
        : esRutaDeJob
        ? '/jobs/{id}'
        : esRutaDeMetricas
        ? '/publicaciones/{id}/metricas'
        : ruta;

    http.Response json(Object cuerpo, [int codigo = 200]) => http.Response(
          jsonEncode(cuerpo),
          codigo,
          headers: {
            'content-type': 'application/json',
            'x-process-time-ms': '4.2',
            'x-query-count': '3',
          },
        );

    // El backend real expone dos esquemas: `IdeaOut` para el listado, sin el
    // campo pesado, e `IdeaDetalleOut` para el resto. El simulador respeta esa
    // diferencia porque de ella depende que el detalle tenga que ir a pedir el
    // contenido: si el mock lo devolviera en el listado, la prueba pasaria sin
    // ejercitar nada.
    Map<String, dynamic> ligera(Map<String, dynamic> idea) =>
        {...idea}..remove('contenido');

    http.Response noEncontrada() => json({'detail': 'Idea no encontrada'}, 404);

    switch ('${peticion.method} $patron') {
      case 'POST /auth/login':
        final cuerpo = jsonDecode(peticion.body) as Map<String, dynamic>;
        if (cuerpo['password'] != passwordValida) {
          return json({'detail': 'Credenciales inválidas'}, 401);
        }
        return json({'access_token': _tokenValido, 'token_type': 'bearer'});

      case 'POST /auth/register':
        final cuerpo = jsonDecode(peticion.body) as Map<String, dynamic>;
        ultimoRegistro = cuerpo;
        if (cuerpo['email'] == 'repetido@atlas.app') {
          return json({'detail': 'El email ya está registrado'}, 409);
        }
        return json({'access_token': _tokenValido, 'token_type': 'bearer'}, 201);

      case 'GET /auth/me':
        // El backend real valida la firma del JWT; aqui basta con rechazar el
        // token marcado como caducado para poder probar ese camino.
        final autorizacion = peticion.headers['Authorization'] ??
            peticion.headers['authorization'];
        if (autorizacion == null || autorizacion.endsWith(_tokenCaducado)) {
          return json({'detail': 'Token inválido o expirado'}, 401);
        }
        return json({'id': 1, 'email': 'demo@atlas.app', 'nombre': 'Andy Toala'});

      case 'GET /ideas':
        // Igual que el backend: filtro `q` sobre titulo y contenido, la mas
        // reciente primero, `limit`/`offset` y el total en `X-Total-Count`.
        final parametros = peticion.url.queryParameters;
        final q = (parametros['q'] ?? '').toLowerCase();
        final coincidentes =
            ideasDelBackend.values
                .where(
                  (idea) =>
                      q.isEmpty ||
                      '${idea['titulo']} ${idea['contenido']}'
                          .toLowerCase()
                          .contains(q),
                )
                .toList()
              ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
        final desde = int.tryParse(parametros['offset'] ?? '') ?? 0;
        final limite = int.tryParse(parametros['limit'] ?? '') ?? 20;
        return http.Response(
          jsonEncode([
            for (final idea in coincidentes.skip(desde).take(limite))
              ligera(idea),
          ]),
          200,
          headers: {
            'content-type': 'application/json',
            'x-process-time-ms': '4.2',
            'x-query-count': '3',
            'x-total-count': '${coincidentes.length}',
          },
        );

      case 'POST /ideas':
        final datos = jsonDecode(peticion.body) as Map<String, dynamic>;
        final id = siguienteId++;
        // El backend devuelve la fila tal como quedo persistida, con el id que
        // asigno Postgres y los valores por defecto de las columnas que el
        // formulario no envia (estado y contador de publicaciones).
        final creada = <String, dynamic>{
          'id': id,
          'titulo': datos['titulo'],
          'estado': 'borrador',
          'origen': datos['origen'] ?? 'texto',
          'etiquetas': datos['etiquetas'] ?? <String>[],
          'num_publicaciones': 0,
          'creado_en': '2026-09-07T09:00:00Z',
          'contenido': datos['contenido'],
        };
        ideasDelBackend[id] = creada;
        return json(creada, 201);

      case 'GET /ideas/{id}':
        if (detalleFalla) return noEncontrada();
        final ideaBuscada = ideasDelBackend[idEnRuta];
        if (ideaBuscada == null) return noEncontrada();
        return json(ideaBuscada);

      case 'PATCH /ideas/{id}':
        final idea = ideasDelBackend[idEnRuta];
        if (idea == null) return noEncontrada();
        // El PATCH aplica solo las claves presentes; el cliente ya se encarga
        // de no mandar las nulas, asi que aqui basta con fusionar el cuerpo
        // sobre la fila y responder el esquema de detalle completo.
        idea.addAll(jsonDecode(peticion.body) as Map<String, dynamic>);
        return json(idea);

      case 'DELETE /ideas/{id}':
        if (ideasDelBackend.remove(idEnRuta) == null) return noEncontrada();
        // 204 sin cuerpo, igual que FastAPI con `response_class=Response`.
        return http.Response('', 204, headers: {'x-process-time-ms': '1.1'});

      case 'POST /ideas/{id}/publicar':
        final idea = ideasDelBackend[idEnRuta];
        if (idea == null) return noEncontrada();
        final red = (jsonDecode(peticion.body) as Map<String, dynamic>)['red_social'];
        final jobId = 'job-${trabajos.length + 1}';
        trabajos[jobId] = {
          'id': jobId,
          'idea_id': idea['id'],
          'estado': 'queued',
          'red_social': red,
          'resultado_publicacion_id': null,
          'error': null,
        };
        idea['estado'] = 'procesando';
        return json(
          {'job_id': jobId, 'estado': 'queued', 'modo': 'asincrono'},
          202,
        );

      case 'GET /jobs/{id}':
        final trabajo = trabajos[segmentos[1]];
        if (trabajo == null) return json({'detail': 'Job no encontrado'}, 404);
        final idea = ideasDelBackend[trabajo['idea_id']]!;
        switch (trabajo['estado']) {
          case 'queued':
            trabajo['estado'] = 'processing';
          case 'processing' when iaFalla:
            trabajo['estado'] = 'error';
            trabajo['error'] =
                'La API key de OpenRouter no es válida (revisa OPENROUTER_API_KEY).';
            idea['estado'] = 'borrador';
          case 'processing':
            final nueva = {
              'id': siguientePublicacionId++,
              'idea_id': idea['id'],
              'red_social': trabajo['red_social'],
              'contenido_generado':
                  'Post para ${trabajo['red_social']}: ${idea['titulo']}',
              'tono': 'profesional',
              'estado': 'generada',
              'modelo_ia': 'anthropic/claude-haiku-4.5',
              'creado_en': '2026-09-08T12:00:00Z',
            };
            (publicacionesDelBackend[idea['id']] ??= []).insert(0, nueva);
            idea['num_publicaciones'] = (idea['num_publicaciones'] as int) + 1;
            idea['estado'] = 'publicada';
            trabajo['estado'] = 'done';
            trabajo['resultado_publicacion_id'] = nueva['id'];
        }
        return json({...trabajo}..remove('red_social'));

      case 'GET /ideas/{id}/publicaciones':
        if (!ideasDelBackend.containsKey(idEnRuta)) return noEncontrada();
        return json([
          for (final pub in publicacionesDelBackend[idEnRuta] ?? const [])
            {
              ...pub,
              'ultima_metrica': metricasDelBackend[pub['id']]?.last,
              'num_metricas': metricasDelBackend[pub['id']]?.length ?? 0,
            },
        ]);

      case 'POST /publicaciones/{id}/metricas':
        final cuerpo = jsonDecode(peticion.body) as Map<String, dynamic>;
        final registro = <String, dynamic>{
          'id': siguienteMetricaId++,
          'fuente': cuerpo['fuente'],
          'likes': cuerpo['likes'],
          'comentarios': cuerpo['comentarios'],
          'compartidos': cuerpo['compartidos'],
          'alcance': cuerpo['alcance'],
          'fecha': '2026-09-10T18:0$siguienteMetricaId:00Z',
        };
        (metricasDelBackend[idPublicacion!] ??= []).add(registro);
        return json({'ok': true, 'cache': 'invalidado', 'id': registro['id']}, 201);

      case 'GET /publicaciones/{id}/metricas':
        return json(metricasDelBackend[idPublicacion] ?? const []);

      case 'GET /dashboard/metricas':
        return json({
          'usuario_id': 1,
          'total_ideas': 1,
          'total_publicaciones': 2,
          'engagement': {
            'likes': 40,
            'comentarios': 5,
            'compartidos': 3,
            'alcance': 900,
          },
          'top_etiquetas': [
            {'nombre': 'backend', 'usos': 1},
          ],
          'generado_en': '2026-09-01T11:00:00Z',
        });

      default:
        return json({'detail': 'Ruta no simulada: $ruta'}, 404);
    }
  });
}

Widget _app({
  String passwordValida = 'claveDePrueba1',
  String? tokenGuardado,
  bool detalleFalla = false,
  bool iaFalla = false,
  int ideasExtra = 0,
  VozServicio? voz,
  NotificacionesServicio? notificaciones,
  PreferenciasLocales? preferencias,
}) {
  almacen = AlmacenSesionEnMemoria(tokenInicial: tokenGuardado);
  return AtlasApp(
    api: AtlasApi(
      cliente: _backendFalso(
        passwordValida: passwordValida,
        detalleFalla: detalleFalla,
        iaFalla: iaFalla,
        ideasExtra: ideasExtra,
      ),
      baseUrl: _baseUrl,
    ),
    almacen: almacen,
    // Los tres servicios nativos de la Semana 14 se sustituyen por dobles en
    // memoria: no hay canal nativo de `speech_to_text`,
    // `flutter_local_notifications` ni `shared_preferences` en el entorno de
    // `flutter test`.
    voz: voz ?? VozServicioFalso(),
    notificaciones: notificaciones ?? NotificacionesServicioFalso(),
    preferencias: preferencias ?? PreferenciasLocalesEnMemoria(),
    intervaloConsultaIa: const Duration(milliseconds: 50),
  );
}

/// Arranca la aplicacion y espera a que termine la comprobacion de sesion.
///
/// La ventana por defecto de las pruebas es 800x600, que es mas ancha y mas
/// corta que un telefono. Se fija un tamano realista (390x900 logicos) para
/// que las pantallas se dispongan como en el dispositivo.
Future<void> _arrancar(
  WidgetTester tester, {
  String? tokenGuardado,
  bool detalleFalla = false,
  bool iaFalla = false,
  int ideasExtra = 0,
  VozServicio? voz,
  NotificacionesServicio? notificaciones,
  PreferenciasLocales? preferencias,
}) async {
  tester.view.physicalSize = const Size(1170, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _app(
      tokenGuardado: tokenGuardado,
      detalleFalla: detalleFalla,
      iaFalla: iaFalla,
      ideasExtra: ideasExtra,
      voz: voz,
      notificaciones: notificaciones,
      preferencias: preferencias,
    ),
  );
  await tester.pumpAndSettle();
}

/// Trae el widget a la vista y lo pulsa.
Future<void> _tocar(WidgetTester tester, Finder objetivo) async {
  await tester.ensureVisible(objetivo);
  await tester.pumpAndSettle();
  await tester.tap(objetivo);
  await tester.pumpAndSettle();
}

/// Igual que [_tocar], pero para un widget que aun no esta construido porque
/// queda por debajo del area visible de una lista perezosa.
Future<void> _tocarEnLista(
  WidgetTester tester,
  Finder objetivo,
  Key lista,
) async {
  await tester.dragUntilVisible(
    objetivo,
    find.byKey(lista),
    const Offset(0, -220),
  );
  await tester.pumpAndSettle();
  await tester.tap(objetivo);
  await tester.pumpAndSettle();
}

/// Rellena el formulario de login y pulsa el boton de entrar.
Future<void> _entrar(
  WidgetTester tester, {
  String email = 'demo@atlas.app',
  String password = 'claveDePrueba1',
}) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'), email);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'), password);
  await tester.tap(find.byKey(const Key('boton-entrar')));
  await tester.pumpAndSettle();
}

/// Abre el detalle de la idea sembrada pulsando su tarjeta en el listado.
///
/// Al asentar los frames se completa tambien la lectura automatica de
/// `GET /ideas/{id}` que la pantalla lanza al construirse.
Future<void> _abrirDetalleDeLaIdeaSembrada(WidgetTester tester) async {
  await tester.tap(find.text('Serie sobre optimizacion de APIs'));
  await tester.pumpAndSettle();
}

/// El desplazable del detalle de una idea. Se busca DENTRO del `ListView`
/// porque cada `SelectableText` de las publicaciones trae su propio
/// `Scrollable` interno, y ese no es el que hay que mover.
Finder _scrollDelDetalle() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

/// Idea de mentira para empujar a mano la ruta de edicion.
///
/// Esa ruta exige un argumento de tipo [Idea] antes incluso de evaluar la
/// guardia, asi que sin este objeto el intento acabaria en la pantalla de ruta
/// invalida y la prueba no demostraria nada sobre la proteccion.
Idea _ideaDePrueba() => Idea(
      id: 7,
      titulo: 'Serie sobre optimizacion de APIs',
      estado: 'borrador',
      origen: 'texto',
      etiquetas: const ['backend', 'movil'],
      numPublicaciones: 2,
      creadoEn: DateTime.utc(2026, 9, 1, 10, 30),
      contenido: _contenidoIdeaSembrada,
    );

void main() {
  // -------------------------------------------------------- arranque y login

  testWidgets('Sin sesion guardada, la aplicacion arranca en el login',
      (tester) async {
    await _arrancar(tester);

    expect(find.byKey(const Key('boton-entrar')), findsOneWidget);
    expect(find.text('Crear una cuenta'), findsOneWidget);
    expect(llamadas['/auth/me'], isNull);
  });

  testWidgets('El login exige los campos obligatorios', (tester) async {
    await _arrancar(tester);

    await tester.tap(find.byKey(const Key('boton-entrar')));
    await tester.pumpAndSettle();

    expect(find.text('El correo es obligatorio'), findsOneWidget);
    expect(find.text('La contraseña es obligatoria'), findsOneWidget);
    // Un formulario invalido no debe llegar a llamar a la API.
    expect(llamadas['/auth/login'], isNull);
  });

  testWidgets('El login valida el formato del correo y el largo de la clave',
      (tester) async {
    await _arrancar(tester);

    await _entrar(tester, email: 'correo-sin-arroba', password: '123');

    expect(
      find.text('Formato de correo no válido (ejemplo: nombre@dominio.com)'),
      findsOneWidget,
    );
    expect(
      find.text('La contraseña debe tener al menos 6 caracteres'),
      findsOneWidget,
    );
    expect(llamadas['/auth/login'], isNull);
  });

  testWidgets('Credenciales incorrectas muestran el mensaje del backend',
      (tester) async {
    await _arrancar(tester);

    await _entrar(tester, password: 'claveErronea1');

    expect(llamadas['/auth/login'], 1);
    expect(
      find.textContaining('Correo o contraseña incorrectos'),
      findsOneWidget,
    );
    // Sigue en el login y no se guardo ningun token.
    expect(find.byKey(const Key('boton-entrar')), findsOneWidget);
    expect(await almacen.leerToken(), isNull);
  });

  testWidgets('Una autenticacion correcta abre el area privada y guarda el token',
      (tester) async {
    await _arrancar(tester);

    await _entrar(tester);

    expect(llamadas['/auth/login'], 1);
    expect(llamadas['/auth/me'], 1);
    expect(find.text('Mis ideas'), findsOneWidget);
    expect(find.text('Andy Toala'), findsOneWidget);
    expect(find.text('Serie sobre optimizacion de APIs'), findsOneWidget);
    expect(await almacen.leerToken(), _tokenValido);
  });

  // ------------------------------------------------------ sesion persistente

  testWidgets('Una sesion guardada se restaura al arrancar', (tester) async {
    await _arrancar(tester, tokenGuardado: _tokenValido);

    // Entra directo al area privada sin pasar por el formulario.
    expect(find.byKey(const Key('boton-entrar')), findsNothing);
    expect(find.text('Mis ideas'), findsOneWidget);
    expect(find.text('Andy Toala'), findsOneWidget);
    expect(llamadas['/auth/login'], isNull);
    expect(llamadas['/auth/me'], 1);
  });

  testWidgets('Un token caducado se descarta y deja al usuario en el login',
      (tester) async {
    await _arrancar(tester, tokenGuardado: _tokenCaducado);

    expect(find.byKey(const Key('boton-entrar')), findsOneWidget);
    expect(find.text('Mis ideas'), findsNothing);
    // El token invalido no se conserva en el almacen.
    expect(await almacen.leerToken(), isNull);
  });

  // --------------------------------------------- navegacion y estado

  testWidgets('El estado del usuario se mantiene al navegar entre pantallas',
      (tester) async {
    await _arrancar(tester);
    await _entrar(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Panel'));
    await tester.pumpAndSettle();
    expect(find.text('Panel de métricas'), findsOneWidget);
    expect(find.text('Andy Toala'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('demo@atlas.app'), findsOneWidget);
    expect(find.text('Andy Toala'), findsWidgets);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Ideas'));
    await tester.pumpAndSettle();
    // La lista sigue cargada y no se repitio la peticion: el dato vive en el
    // controlador, no en la pantalla.
    expect(find.text('Serie sobre optimizacion de APIs'), findsOneWidget);
    expect(llamadas['/ideas'], 1);
  });

  testWidgets('El detalle de una idea conserva la identidad del usuario',
      (tester) async {
    await _arrancar(tester);
    await _entrar(tester);

    await tester.tap(find.text('Serie sobre optimizacion de APIs'));
    await tester.pumpAndSettle();

    expect(find.text('Idea #7'), findsOneWidget);
    // El dato queda debajo de la seccion de publicaciones: el ListView es
    // perezoso y no lo construye hasta que se desplaza hasta el.
    await tester.scrollUntilVisible(
      find.text('Pertenece a Andy Toala'),
      300,
      scrollable: _scrollDelDetalle(),
    );
    expect(find.text('Pertenece a Andy Toala'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Mis ideas'), findsOneWidget);
  });

  testWidgets('El borrador de una idea sobrevive al cambio de pantalla',
      (tester) async {
    await _arrancar(tester);
    await _entrar(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva idea'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título'),
      'Idea a medio escribir',
    );
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Tienes un borrador sin guardar'), findsOneWidget);

    await tester
        .tap(find.widgetWithText(FloatingActionButton, 'Seguir borrador'));
    await tester.pumpAndSettle();
    expect(find.text('Idea a medio escribir'), findsOneWidget);
  });

  // -------------------------------------------------- CRUD completo de ideas

  testWidgets('Crear una idea desde el formulario la guarda y la muestra en '
      'el listado', (tester) async {
    await _arrancar(tester);
    await _entrar(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva idea'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título'),
      'Idea nacida en la prueba',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contenido'),
      'Texto suficientemente largo como para pasar la validacion del campo.',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Etiquetas (opcional)'),
      'pruebas, flutter',
    );
    await _tocar(tester, find.byKey(const Key('boton-guardar-idea')));

    // Una escritura y solo una: el formulario no debe reintentar por su cuenta.
    expect(llamadas['POST /ideas'], 1);
    // El formulario se cierra solo y la fila nueva ya esta arriba del listado.
    expect(find.text('Mis ideas'), findsOneWidget);
    expect(find.text('Idea nacida en la prueba'), findsOneWidget);
    // Sin releer el listado: el controlador inserta la idea que devolvio el
    // POST, que es la fila tal como quedo en la base de datos.
    expect(llamadas['GET /ideas'], 1);
  });

  testWidgets('El detalle pide al backend el contenido que el listado no trae',
      (tester) async {
    await _arrancar(tester);
    await _entrar(tester);

    // `GET /ideas` responde el esquema ligero: el texto largo todavia no ha
    // viajado, y esa es justamente la optimizacion que se quiere evidenciar.
    expect(find.text(_contenidoIdeaSembrada), findsNothing);

    await _abrirDetalleDeLaIdeaSembrada(tester);

    expect(llamadas['GET /ideas/7'], 1);
    expect(find.text('Contenido'), findsOneWidget);
    expect(find.text(_contenidoIdeaSembrada), findsOneWidget);
  });

  testWidgets('Editar una idea actualiza el titulo en el detalle y en el '
      'listado', (tester) async {
    await _arrancar(tester);
    await _entrar(tester);
    await _abrirDetalleDeLaIdeaSembrada(tester);

    await tester.tap(find.byKey(const Key('boton-editar-idea')));
    await tester.pumpAndSettle();
    expect(find.text('Editar idea'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título'),
      'Serie sobre optimizacion, revisada',
    );
    await _tocar(tester, find.byKey(const Key('boton-actualizar-idea')));

    expect(llamadas['PATCH /ideas/7'], 1);
    // El detalle adopta la version que devolvio el PATCH, sin volver a pedirla.
    expect(find.text('Serie sobre optimizacion, revisada'), findsOneWidget);
    expect(llamadas['GET /ideas/7'], 1);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Y el listado tambien la ve cambiada, porque la fila vive en el
    // controlador compartido y no en cada pantalla.
    expect(find.text('Serie sobre optimizacion, revisada'), findsOneWidget);
    expect(find.text('Serie sobre optimizacion de APIs'), findsNothing);
  });

  testWidgets('Eliminar una idea pide confirmacion y la quita del listado',
      (tester) async {
    await _arrancar(tester);
    await _entrar(tester);
    await _abrirDetalleDeLaIdeaSembrada(tester);

    await tester.tap(find.byKey(const Key('boton-eliminar-idea')));
    await tester.pumpAndSettle();

    // Primero el dialogo: el borrado no tiene deshacer y no puede dispararse
    // con un solo toque en la barra superior.
    expect(find.text('¿Eliminar esta idea?'), findsOneWidget);
    expect(llamadas['DELETE /ideas/7'], isNull);

    await tester.tap(find.byKey(const Key('boton-confirmar-eliminar-idea')));
    await tester.pumpAndSettle();

    expect(llamadas['DELETE /ideas/7'], 1);
    // El detalle se cierra solo -describia una fila que ya no existe- y el
    // listado queda vacio.
    expect(find.text('Mis ideas'), findsOneWidget);
    expect(find.text('Serie sobre optimizacion de APIs'), findsNothing);
    expect(find.text('Todavía no hay ideas'), findsOneWidget);
  });

  testWidgets('Cancelar la confirmacion no lanza el borrado', (tester) async {
    await _arrancar(tester);
    await _entrar(tester);
    await _abrirDetalleDeLaIdeaSembrada(tester);

    await tester.tap(find.byKey(const Key('boton-eliminar-idea')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    // Lo que hay que demostrar no es que el texto siga en pantalla, sino que la
    // peticion destructiva nunca llego a salir del telefono.
    expect(llamadas['DELETE /ideas/7'], isNull);
    expect(ideasDelBackend.containsKey(7), isTrue);
    expect(find.text('Idea #7'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Serie sobre optimizacion de APIs'), findsOneWidget);
  });

  testWidgets('Si falla la lectura del detalle, la pantalla lo explica',
      (tester) async {
    await _arrancar(tester, detalleFalla: true);
    await _entrar(tester);
    await _abrirDetalleDeLaIdeaSembrada(tester);

    expect(llamadas['GET /ideas/7'], 1);
    // El camino de error tiene que verse: antes el fallo no dejaba rastro.
    expect(find.text('Idea no encontrada'), findsOneWidget);
    // Y sin contenido leido no se habilita la edicion, porque el PATCH
    // guardaria un campo vacio encima del texto real.
    final botonEditar = tester.widget<IconButton>(
      find.byKey(const Key('boton-editar-idea')),
    );
    expect(botonEditar.onPressed, isNull);
  });

  // ------------------------------------------------------------- registro

  testWidgets('El registro valida que las contrasenas coincidan',
      (tester) async {
    await _arrancar(tester);

    await _tocar(tester, find.text('Crear una cuenta'));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo'), 'Andy Toala');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'nuevo@atlas.app');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'claveDePrueba1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Repetir contraseña'), 'otraClave9');
    await tester.tap(find.byKey(const Key('boton-registrar')));
    await tester.pumpAndSettle();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(llamadas['/auth/register'], isNull);
  });

  testWidgets('El registro exige una clave con letra y numero', (tester) async {
    await _arrancar(tester);

    await _tocar(tester, find.text('Crear una cuenta'));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'solotexto');
    await tester.tap(find.byKey(const Key('boton-registrar')));
    await tester.pumpAndSettle();

    expect(find.text('La contraseña debe incluir al menos un número'),
        findsOneWidget);
  });

  testWidgets('Un registro correcto deja la sesion iniciada', (tester) async {
    await _arrancar(tester);

    await _tocar(tester, find.text('Crear una cuenta'));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo'), 'Andy Toala');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'nuevo@atlas.app');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'claveDePrueba1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Repetir contraseña'),
        'claveDePrueba1');
    await tester.tap(find.byKey(const Key('boton-registrar')));
    await tester.pumpAndSettle();

    expect(llamadas['/auth/register'], 1);
    expect(find.text('Mis ideas'), findsOneWidget);
    expect(await almacen.leerToken(), _tokenValido);
  });

  testWidgets(
      'El registro envia al backend el tono elegido, que es con el que la IA '
      'redactara las publicaciones', (tester) async {
    await _arrancar(tester);
    await _tocar(tester, find.text('Crear una cuenta'));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo'), 'Andy Toala');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'creador@atlas.app');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'claveDePrueba1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Repetir contraseña'),
        'claveDePrueba1');

    // Se cambia el tono por defecto ("cercano") por otro: si el formulario
    // ignorara la eleccion, la prueba lo delataria.
    await _tocar(tester, find.text('Cercano'));
    await tester.tap(find.text('Profesional').last);
    await tester.pumpAndSettle();
    await _tocar(tester, find.byKey(const Key('boton-registrar')));

    expect(ultimoRegistro?['tono'], 'profesional');
    expect(ultimoRegistro?['email'], 'creador@atlas.app');
    expect(find.text('Mis ideas'), findsOneWidget);
  });

  // --------------------------------------------------- proteccion de rutas

  testWidgets(
      'Sin sesion, una ruta privada muestra el aviso de acceso restringido',
      (tester) async {
    await _arrancar(tester);

    await _tocar(tester, find.byKey(const Key('boton-intento-protegido')));

    expect(find.text('Esta sección es privada'), findsOneWidget);
    expect(find.text('Mis ideas'), findsNothing);
    // No se pidio ningun dato del usuario.
    expect(llamadas['/ideas'], isNull);

    await tester.tap(find.byKey(const Key('boton-ir-a-login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton-entrar')), findsOneWidget);
  });

  testWidgets('Sin sesion, la ruta de edicion de una idea queda bloqueada',
      (tester) async {
    await _arrancar(tester);

    // Desde el login no hay boton hacia la edicion -es una ruta interna-, asi
    // que se empuja a mano por su nombre: ese es exactamente el intento que la
    // guardia debe frenar, venga de donde venga.
    final navegador =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    navegador.pushNamed(Rutas.editarIdea, arguments: _ideaDePrueba());
    await tester.pumpAndSettle();

    expect(find.text('Esta sección es privada'), findsOneWidget);
    expect(find.text('Editar idea'), findsNothing);
    expect(find.byKey(const Key('boton-actualizar-idea')), findsNothing);
    // La guardia corta antes de construir el formulario, asi que no hubo forma
    // de tocar la API.
    expect(llamadas['PATCH /ideas/7'], isNull);
  });

  testWidgets('Tras cerrar sesion no se puede volver al area privada',
      (tester) async {
    await _arrancar(tester);
    await _entrar(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pumpAndSettle();
    await _tocarEnLista(
      tester,
      find.byKey(const Key('boton-cerrar-sesion')),
      const Key('lista-perfil'),
    );
    await tester.tap(find.byKey(const Key('boton-confirmar-salir')));
    await tester.pumpAndSettle();

    // Vuelve al login y el token deja de estar guardado.
    expect(find.byKey(const Key('boton-entrar')), findsOneWidget);
    expect(find.text('Andy Toala'), findsNothing);
    expect(await almacen.leerToken(), isNull);

    // El intento de reabrir el area privada queda bloqueado.
    await _tocar(tester, find.byKey(const Key('boton-intento-protegido')));
    expect(find.text('Esta sección es privada'), findsOneWidget);
    expect(find.text('Serie sobre optimizacion de APIs'), findsNothing);
  });

  // ------------------------------------------- Semana 14: funcionalidades nativas

  testWidgets(
      'El dictado por voz completa el contenido y marca el origen como audio',
      (tester) async {
    await _arrancar(tester, voz: VozServicioFalso());
    await _entrar(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva idea'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título'),
      'Idea capturada por voz',
    );

    await _tocar(tester, find.byKey(const Key('boton-dictar-idea')));
    // El motor de reconocimiento (simulado) entrega el texto de inmediato.
    expect(find.text('Idea dictada de prueba'), findsOneWidget);

    await _tocar(tester, find.byKey(const Key('boton-guardar-idea')));

    expect(llamadas['POST /ideas'], 1);
    // El origen viaja como 'audio': el contenido se completo dictando, no
    // escribiendo, y el backend lo distingue del resto de ideas.
    expect(ideasDelBackend.values.last['origen'], 'audio');
  });

  testWidgets(
      'El microfono denegado explica antes de pedir el permiso; si se '
      'cancela, no llega a escuchar', (tester) async {
    await _arrancar(
      tester,
      voz: VozServicioFalso(estadoInicial: EstadoPermiso.denegado),
    );
    await _entrar(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva idea'));
    await tester.pumpAndSettle();

    await _tocar(tester, find.byKey(const Key('boton-dictar-idea')));
    // La explicacion aparece ANTES del permiso: el dialogo de la aplicacion,
    // no el del sistema operativo.
    expect(find.text('Usar el micrófono'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Ahora no'));
    await tester.pumpAndSettle();

    expect(find.text('Idea dictada de prueba'), findsNothing);
  });

  testWidgets(
      'Tras explicar y conceder el permiso, el dictado por voz empieza a '
      'escuchar', (tester) async {
    await _arrancar(
      tester,
      voz: VozServicioFalso(
        estadoInicial: EstadoPermiso.denegado,
        estadoTrasSolicitar: EstadoPermiso.concedido,
      ),
    );
    await _entrar(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva idea'));
    await tester.pumpAndSettle();

    await _tocar(tester, find.byKey(const Key('boton-dictar-idea')));
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Idea dictada de prueba'), findsOneWidget);
  });

  testWidgets('El microfono en denegacion permanente ofrece abrir los ajustes',
      (tester) async {
    final voz = VozServicioFalso(estadoInicial: EstadoPermiso.denegadoPermanente);
    await _arrancar(tester, voz: voz);
    await _entrar(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva idea'));
    await tester.pumpAndSettle();

    await _tocar(tester, find.byKey(const Key('boton-dictar-idea')));
    // Sin explicacion previa: pedir nuevamente el permiso no haria nada, asi
    // que se salta directo a la salida a ajustes.
    expect(find.text('Usar el micrófono'), findsNothing);
    expect(find.text('Micrófono bloqueado'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Abrir ajustes'));
    await tester.pumpAndSettle();

    expect(voz.ajustesAbiertos, isTrue);
  });

  testWidgets(
      'El microfono restringido por politica del sistema no ofrece '
      'reintentar ni ajustes', (tester) async {
    await _arrancar(
      tester,
      voz: VozServicioFalso(estadoInicial: EstadoPermiso.restringido),
    );
    await _entrar(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva idea'));
    await tester.pumpAndSettle();

    await _tocar(tester, find.byKey(const Key('boton-dictar-idea')));

    expect(find.textContaining('restringido en este dispositivo'),
        findsOneWidget);
    expect(find.text('Micrófono bloqueado'), findsNothing);
  });

  testWidgets(
      'Si el reconocedor no esta disponible, se avisa sin bloquear la '
      'escritura manual', (tester) async {
    await _arrancar(tester, voz: VozServicioFalso(disponible: false));
    await _entrar(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva idea'));
    await tester.pumpAndSettle();

    await _tocar(tester, find.byKey(const Key('boton-dictar-idea')));

    // Esta es la condicion de INDISPONIBILIDAD del servicio, distinta del
    // permiso: el permiso esta concedido por defecto en el doble de prueba.
    expect(find.textContaining('no está disponible en este dispositivo'),
        findsOneWidget);

    const texto = 'Escrita a mano porque el dictado no esta disponible.';
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contenido'),
      texto,
    );
    expect(find.text(texto), findsOneWidget);
  });

  testWidgets(
      'Activar el aviso de notificaciones explica, pide el permiso y '
      'enciende el interruptor', (tester) async {
    await _arrancar(tester);
    await _entrar(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pumpAndSettle();

    var interruptor = tester.widget<SwitchListTile>(
      find.byKey(const Key('interruptor-notificaciones')),
    );
    expect(interruptor.value, isFalse);

    await _tocarEnLista(
      tester,
      find.byKey(const Key('interruptor-notificaciones')),
      const Key('lista-perfil'),
    );
    expect(find.text('Avisar cuando una idea se publique'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    interruptor = tester.widget<SwitchListTile>(
      find.byKey(const Key('interruptor-notificaciones')),
    );
    expect(interruptor.value, isTrue);
  });

  testWidgets(
      'Notificaciones en denegacion permanente ofrece ajustes y deja el '
      'interruptor apagado', (tester) async {
    final notificaciones =
        NotificacionesServicioFalso(estadoInicial: EstadoPermiso.denegadoPermanente);
    await _arrancar(tester, notificaciones: notificaciones);
    await _entrar(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pumpAndSettle();

    await _tocarEnLista(
      tester,
      find.byKey(const Key('interruptor-notificaciones')),
      const Key('lista-perfil'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Notificaciones bloqueadas'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Abrir ajustes'));
    await tester.pumpAndSettle();

    expect(notificaciones.ajustesAbiertos, isTrue);
    final interruptor = tester.widget<SwitchListTile>(
      find.byKey(const Key('interruptor-notificaciones')),
    );
    expect(interruptor.value, isFalse);
  });

  testWidgets(
      'Notificaciones restringidas por politica del sistema avisan sin '
      'ofrecer ajustes', (tester) async {
    final notificaciones =
        NotificacionesServicioFalso(estadoInicial: EstadoPermiso.restringido);
    await _arrancar(tester, notificaciones: notificaciones);
    await _entrar(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pumpAndSettle();

    await _tocarEnLista(
      tester,
      find.byKey(const Key('interruptor-notificaciones')),
      const Key('lista-perfil'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    // Una restriccion de politica no se revierte desde los ajustes de la
    // aplicacion: no se ofrece ese atajo, a diferencia de la denegacion
    // permanente.
    expect(find.text('Notificaciones bloqueadas'), findsNothing);
    expect(find.textContaining('restringidas en este dispositivo'),
        findsOneWidget);
    expect(notificaciones.ajustesAbiertos, isFalse);
  });

  testWidgets(
      'Una idea que pasa de "procesando" a "publicada" dispara un aviso '
      'local, y solo entonces', (tester) async {
    final notificaciones = NotificacionesServicioFalso();
    await _arrancar(
      tester,
      notificaciones: notificaciones,
      preferencias: PreferenciasLocalesEnMemoria(notificacionesActivadas: true),
    );
    await _entrar(tester);

    // Primera lectura: la idea sembrada esta en "borrador". Se registra el
    // estado, pero no hay transicion que avisar todavia.
    expect(notificaciones.mostradas, isEmpty);

    ideasDelBackend[7]!['estado'] = 'procesando';
    await _tocar(tester, find.byKey(const Key('boton-cargar-ideas')));
    // "borrador" -> "procesando" tampoco es la transicion que interesa.
    expect(notificaciones.mostradas, isEmpty);

    ideasDelBackend[7]!['estado'] = 'publicada';
    await _tocar(tester, find.byKey(const Key('boton-cargar-ideas')));

    expect(notificaciones.mostradas, hasLength(1));
    expect(notificaciones.mostradas.single.id, 7);
    expect(notificaciones.mostradas.single.cuerpo, contains('publicación'));
  });

  // ------------------------------------------ publicaciones con IA (Sem. 15)

  testWidgets(
      'Generar con IA encola el trabajo, espera al worker y muestra la '
      'publicacion para la red elegida', (tester) async {
    final notificaciones = NotificacionesServicioFalso();
    await _arrancar(
      tester,
      notificaciones: notificaciones,
      preferencias: PreferenciasLocalesEnMemoria(notificacionesActivadas: true),
    );
    await _entrar(tester);
    await _abrirDetalleDeLaIdeaSembrada(tester);

    // Las dos publicaciones que ya existian llegan por su propio endpoint.
    expect(llamadas['GET /ideas/7/publicaciones'], 1);
    await tester.scrollUntilVisible(
      find.byKey(const Key('boton-generar-publicacion')),
      300,
      scrollable: _scrollDelDetalle(),
    );
    expect(find.byKey(const Key('publicacion-2')), findsOneWidget);

    await _tocar(tester, find.text('X'));
    await _tocar(tester, find.byKey(const Key('boton-generar-publicacion')));

    // Un solo POST y varias consultas del job: queued -> processing -> done.
    expect(llamadas['POST /ideas/7/publicar'], 1);
    expect(llamadas['GET /jobs/job-1'], greaterThanOrEqualTo(2));
    expect(
      find.text('Post para x: Serie sobre optimizacion de APIs'),
      findsOneWidget,
    );
    expect(find.text('Publicación para X lista.'), findsOneWidget);
    expect(find.text('Redactando…'), findsNothing);

    // La idea se relee: ya no es un borrador y cuenta la publicacion nueva.
    await tester.scrollUntilVisible(
      find.text('publicaciones'),
      -300,
      scrollable: _scrollDelDetalle(),
    );
    expect(find.text('3'), findsOneWidget);
    expect(ideasDelBackend[7]!['estado'], 'publicada');

    // Y llega el aviso local de la Semana 14.
    expect(notificaciones.mostradas.single.titulo, 'Tu publicación está lista');
  });

  testWidgets(
      'Si la IA falla, la pantalla explica el motivo y la idea no queda '
      'procesando', (tester) async {
    await _arrancar(tester, iaFalla: true);
    await _entrar(tester);
    await _abrirDetalleDeLaIdeaSembrada(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('boton-generar-publicacion')),
      300,
      scrollable: _scrollDelDetalle(),
    );
    await _tocar(tester, find.byKey(const Key('boton-generar-publicacion')));

    expect(find.textContaining('OPENROUTER_API_KEY'), findsOneWidget);
    // El boton vuelve a estar disponible para reintentar.
    final boton = tester.widget<FilledButton>(
      find.byKey(const Key('boton-generar-publicacion')),
    );
    expect(boton.onPressed, isNotNull);
    // No se creo ninguna publicacion nueva y la idea volvio a su estado.
    expect(publicacionesDelBackend[7], hasLength(2));
    expect(find.text('procesando'), findsNothing);
  });

  // ------------------------------------- paginacion y busqueda (Semana 15)

  testWidgets(
      'El listado llega de 20 en 20 y "Cargar mas" trae la pagina siguiente',
      (tester) async {
    await _arrancar(tester, ideasExtra: 25);
    await _entrar(tester);

    // 26 ideas en el servidor (25 de relleno + la sembrada), 20 en pantalla.
    expect(find.text('26 ideas'), findsOneWidget);
    final cargarMas = find.byKey(const Key('boton-cargar-mas'));
    await tester.scrollUntilVisible(cargarMas, 400,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Cargar más (20 de 26)'), findsOneWidget);
    expect(find.text('Serie sobre optimizacion de APIs'), findsNothing);

    await _tocar(tester, cargarMas);

    expect(llamadas['GET /ideas'], 2);
    await tester.scrollUntilVisible(
      find.text('Serie sobre optimizacion de APIs'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Serie sobre optimizacion de APIs'), findsOneWidget);
    // Ya esta todo: el boton desaparece.
    expect(cargarMas, findsNothing);
  });

  testWidgets(
      'La busqueda filtra en el servidor y, sin coincidencias, lo explica',
      (tester) async {
    await _arrancar(tester, ideasExtra: 25);
    await _entrar(tester);

    await tester.enterText(
        find.byKey(const Key('campo-buscar-ideas')), 'optimizacion');
    // Espera a que el usuario deje de escribir antes de consultar.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('1 idea'), findsOneWidget);
    expect(find.text('Serie sobre optimizacion de APIs'), findsOneWidget);
    expect(find.text('Idea de relleno 0'), findsNothing);

    await tester.enterText(
        find.byKey(const Key('campo-buscar-ideas')), 'no existe');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Sin resultados'), findsOneWidget);

    await _tocar(tester, find.text('Ver todas mis ideas'));
    expect(find.text('26 ideas'), findsOneWidget);
  });

  // ------------------------------------ rendimiento de publicaciones (S15)

  testWidgets(
      'Registrar el rendimiento de una publicacion lo guarda y lo muestra '
      'en la tarjeta', (tester) async {
    await _arrancar(tester);
    await _entrar(tester);
    await _abrirDetalleDeLaIdeaSembrada(tester);

    final registrar = find.byKey(const Key('registrar-metrica-2'));
    await tester.scrollUntilVisible(registrar, 300,
        scrollable: _scrollDelDetalle());
    expect(find.textContaining('Aún no registras'), findsWidgets);
    await _tocar(tester, registrar);

    // Un campo vacio no se envia.
    await _tocar(tester, find.byKey(const Key('boton-guardar-metrica')));
    expect(find.text('Obligatorio (0 si no hubo)'), findsWidgets);
    expect(llamadas['POST /publicaciones/2/metricas'], isNull);

    await tester.enterText(find.byKey(const Key('campo-metrica-likes')), '1520');
    await tester.enterText(
        find.byKey(const Key('campo-metrica-comentarios')), '40');
    await tester.enterText(
        find.byKey(const Key('campo-metrica-compartidos')), '12');
    await tester.enterText(
        find.byKey(const Key('campo-metrica-alcance')), '9800');
    await _tocar(tester, find.byKey(const Key('boton-guardar-metrica')));

    expect(llamadas['POST /publicaciones/2/metricas'], 1);
    expect(metricasDelBackend[2]!.single['likes'], 1520);
    expect(find.text('Rendimiento registrado.'), findsOneWidget);
    // La tarjeta muestra la medicion, en formato compacto.
    expect(find.text('1,5 k'), findsOneWidget);
    expect(find.text('9,8 k'), findsOneWidget);

    // Y la evolucion lista el registro.
    await _tocar(tester, find.byKey(const Key('historial-metricas-2')));
    expect(find.text('Evolución en LinkedIn'), findsOneWidget);
    expect(find.byKey(const Key('registro-metrica-1')), findsOneWidget);
  });

  // ---------------------------------------------------------- diagnostico

  testWidgets('El diagnostico de conexion es accesible sin sesion',
      (tester) async {
    await _arrancar(tester);

    await _tocar(tester, find.text('Diagnóstico de conexión'));

    expect(find.text('Configuración del entorno'), findsOneWidget);
    expect(find.text(AppConfig.apiBaseUrl), findsOneWidget);
  });

  testWidgets('La configuracion por defecto es valida', (tester) async {
    expect(AppConfig.validar(), isNull);
  });
}
