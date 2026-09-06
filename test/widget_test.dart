// Pruebas del flujo de autenticacion, navegacion, estado y formularios
// (Taller Semana 10).
//
// El backend se sustituye por un `MockClient` de package:http, de modo que
// las pruebas recorren el flujo completo -validaciones, login correcto, login
// rechazado, navegacion entre pantallas, permanencia del estado, cierre de
// sesion y bloqueo de las rutas privadas- sin necesitar la API levantada.

import 'dart:convert';

import 'package:atlas_app/config/app_config.dart';
import 'package:atlas_app/main.dart';
import 'package:atlas_app/servicios/atlas_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _baseUrl = 'http://backend.prueba';

/// Contador de llamadas por ruta, para comprobar que el estado compartido
/// evita repetir peticiones al volver a una pantalla ya visitada.
late Map<String, int> llamadas;

/// Backend simulado. [passwordValida] es la unica clave que acepta el login.
http.Client _backendFalso({String passwordValida = 'claveDePrueba1'}) {
  llamadas = <String, int>{};

  return MockClient((peticion) async {
    final ruta = peticion.url.path;
    llamadas[ruta] = (llamadas[ruta] ?? 0) + 1;

    http.Response json(Object cuerpo, [int codigo = 200]) => http.Response(
          jsonEncode(cuerpo),
          codigo,
          headers: {
            'content-type': 'application/json',
            'x-process-time-ms': '4.2',
            'x-query-count': '3',
          },
        );

    switch ('${peticion.method} $ruta') {
      case 'POST /auth/login':
        final cuerpo = jsonDecode(peticion.body) as Map<String, dynamic>;
        if (cuerpo['password'] != passwordValida) {
          return json({'detail': 'Credenciales inválidas'}, 401);
        }
        return json({'access_token': 'jwt-de-prueba-1234567890', 'token_type': 'bearer'});

      case 'POST /auth/register':
        final cuerpo = jsonDecode(peticion.body) as Map<String, dynamic>;
        if (cuerpo['email'] == 'repetido@atlas.app') {
          return json({'detail': 'El email ya está registrado'}, 409);
        }
        return json({'access_token': 'jwt-nuevo-0987654321', 'token_type': 'bearer'}, 201);

      case 'GET /auth/me':
        return json({'id': 1, 'email': 'demo@atlas.app', 'nombre': 'Andy Toala'});

      case 'GET /ideas':
        return json([
          {
            'id': 7,
            'titulo': 'Serie sobre optimizacion de APIs',
            'estado': 'nueva',
            'origen': 'texto',
            'etiquetas': ['backend', 'movil'],
            'num_publicaciones': 2,
            'creado_en': '2026-09-01T10:30:00Z',
          },
        ]);

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

Widget _app({String passwordValida = 'claveDePrueba1'}) => AtlasApp(
      api: AtlasApi(
        cliente: _backendFalso(passwordValida: passwordValida),
        baseUrl: _baseUrl,
      ),
    );

/// Rellena el formulario de login y pulsa el boton de entrar.
Future<void> _entrar(
  WidgetTester tester, {
  String email = 'demo@atlas.app',
  String password = 'claveDePrueba1',
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), password);
  await tester.tap(find.byKey(const Key('boton-entrar')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('La aplicacion arranca en el formulario de inicio de sesion',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Atlas'), findsOneWidget);
    expect(find.byKey(const Key('boton-entrar')), findsOneWidget);
    expect(find.text('Crear una cuenta'), findsOneWidget);
  });

  testWidgets('El login exige los campos obligatorios', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton-entrar')));
    await tester.pumpAndSettle();

    expect(find.text('El correo es obligatorio'), findsOneWidget);
    expect(find.text('La contraseña es obligatoria'), findsOneWidget);
    // Un formulario invalido no debe llegar a llamar a la API.
    expect(llamadas['/auth/login'], isNull);
  });

  testWidgets('El login valida el formato del correo y el largo de la clave',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _entrar(tester, password: 'claveErronea1');

    expect(llamadas['/auth/login'], 1);
    expect(
      find.textContaining('Correo o contraseña incorrectos'),
      findsOneWidget,
    );
    // Sigue en el login: no se abrio ninguna pantalla privada.
    expect(find.byKey(const Key('boton-entrar')), findsOneWidget);
  });

  testWidgets('Una autenticacion correcta abre el area privada',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _entrar(tester);

    expect(llamadas['/auth/login'], 1);
    expect(llamadas['/auth/me'], 1);
    expect(find.text('Mis ideas'), findsOneWidget);
    expect(find.text('Andy Toala'), findsOneWidget);
    expect(find.text('Serie sobre optimizacion de APIs'), findsOneWidget);
  });

  testWidgets('El estado del usuario se mantiene al navegar entre pantallas',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
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
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _entrar(tester);

    await tester.tap(find.text('Serie sobre optimizacion de APIs'));
    await tester.pumpAndSettle();

    expect(find.text('Idea #7'), findsOneWidget);
    expect(find.text('Pertenece a Andy Toala'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Mis ideas'), findsOneWidget);
  });

  testWidgets('El borrador de una idea sobrevive al cambio de pantalla',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
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

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Seguir borrador'));
    await tester.pumpAndSettle();
    expect(find.text('Idea a medio escribir'), findsOneWidget);
  });

  testWidgets('El registro valida que las contrasenas coincidan',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo'), 'Andy Toala');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'), 'nuevo@atlas.app');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'claveDePrueba1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Repetir contraseña'), 'otraClave9');
    await tester.tap(find.byKey(const Key('boton-registrar')));
    await tester.pumpAndSettle();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(llamadas['/auth/register'], isNull);
  });

  testWidgets('El registro exige una clave con letra y numero',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'solotexto');
    await tester.tap(find.byKey(const Key('boton-registrar')));
    await tester.pumpAndSettle();

    expect(find.text('La contraseña debe incluir al menos un número'),
        findsOneWidget);
  });

  testWidgets('Un registro correcto deja la sesion iniciada', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo'), 'Andy Toala');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'), 'nuevo@atlas.app');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'claveDePrueba1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Repetir contraseña'), 'claveDePrueba1');
    await tester.tap(find.byKey(const Key('boton-registrar')));
    await tester.pumpAndSettle();

    expect(llamadas['/auth/register'], 1);
    expect(find.text('Mis ideas'), findsOneWidget);
  });

  testWidgets('Sin sesion, una ruta privada muestra el aviso de acceso restringido',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton-intento-protegido')));
    await tester.pumpAndSettle();

    expect(find.text('Esta sección es privada'), findsOneWidget);
    expect(find.text('Mis ideas'), findsNothing);
    // No se pidio ningun dato del usuario.
    expect(llamadas['/ideas'], isNull);

    await tester.tap(find.byKey(const Key('boton-ir-a-login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boton-entrar')), findsOneWidget);
  });

  testWidgets('Tras cerrar sesion no se puede volver al area privada',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _entrar(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('boton-cerrar-sesion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton-cerrar-sesion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton-confirmar-salir')));
    await tester.pumpAndSettle();

    // Vuelve al login.
    expect(find.byKey(const Key('boton-entrar')), findsOneWidget);
    expect(find.text('Andy Toala'), findsNothing);

    // El intento de reabrir el area privada queda bloqueado.
    await tester.tap(find.byKey(const Key('boton-intento-protegido')));
    await tester.pumpAndSettle();
    expect(find.text('Esta sección es privada'), findsOneWidget);
    expect(find.text('Serie sobre optimizacion de APIs'), findsNothing);
  });

  testWidgets('El diagnostico de conexion es accesible sin sesion',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Diagnóstico de conexión'));
    await tester.pumpAndSettle();

    expect(find.text('Configuración del entorno'), findsOneWidget);
    expect(find.text(AppConfig.apiBaseUrl), findsOneWidget);
  });
}
