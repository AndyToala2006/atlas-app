// Prueba de INTEGRACION de punta a punta (vertice de la piramide).
//
// A diferencia de las pruebas de `test/`, aqui no hay nada simulado entre la
// app y los datos: corre en el telefono (o emulador), habla por HTTP con el
// FastAPI real, que escribe en Postgres, encola en Redis y cuyo worker de
// Celery llama al modelo de lenguaje por OpenRouter. Verifica en un solo
// recorrido lo que pide la guia en sus actividades 13 a 15: que un dato
// ingresado desde la app se guarda, se consulta, se procesa y se elimina.
//
// Es lenta (decenas de segundos) y depende de la red, por eso hay UNA sola.
// Requisitos: `docker compose up -d` en atlas-backend y el telefono en la misma
// red. Ejecutar:
//
//   flutter test integration_test/flujo_completo_test.dart \
//     --dart-define=API_BASE_URL=http://IP_DEL_PC:8000

import 'package:atlas_app/main.dart';
import 'package:atlas_app/servicios/almacen_sesion.dart';
import 'package:atlas_app/servicios/atlas_api.dart';
import 'package:atlas_app/servicios/preferencias_locales.dart';
import 'package:atlas_app/widgets/tarjeta_idea.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Bombea frames hasta que [objetivo] aparece o se agota [limite]. Con red real
/// no sirve `pumpAndSettle`: entre una respuesta y la siguiente puede no haber
/// ningun frame pendiente y la prueba seguiria antes de tiempo.
Future<void> _esperar(
  WidgetTester tester,
  Finder objetivo, {
  Duration limite = const Duration(seconds: 20),
}) async {
  final fin = DateTime.now().add(limite);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (objetivo.evaluate().isNotEmpty) return;
  }
  throw TestFailure('No aparecio $objetivo en ${limite.inSeconds} s');
}

Finder _scrollDelDetalle() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Registro, login, crear idea, generar publicacion con IA y eliminar, '
      'contra el backend y la base de datos reales', (tester) async {
    // Cuenta nueva en cada ejecucion: la prueba no depende de los datos de
    // semilla ni deja rastros en la cuenta de demostracion.
    final marca = DateTime.now().millisecondsSinceEpoch;
    final email = 'e2e-$marca@atlas.app';
    const password = 'claveE2E2026';
    final titulo = 'Idea E2E $marca';

    final apiDePreparacion = AtlasApi();
    await apiDePreparacion.registrar(
      email: email,
      nombre: 'Prueba E2E',
      password: password,
      tono: 'profesional',
    );

    // Almacenes en memoria: la app arranca SIN la sesion que el usuario real
    // pudiera tener guardada en el Keystore del telefono.
    await tester.pumpWidget(AtlasApp(
      almacen: AlmacenSesionEnMemoria(),
      preferencias: PreferenciasLocalesEnMemoria(),
    ));
    await _esperar(tester, find.byKey(const Key('boton-entrar')));

    // 1. Login por la interfaz.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'), email);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), password);
    await tester.tap(find.byKey(const Key('boton-entrar')));
    await _esperar(tester, find.text('Mis ideas'));

    // 2. Crear la idea (POST /ideas -> fila en Postgres).
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Nueva idea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), titulo);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contenido'),
      'Un indice compuesto bajo una consulta de 800 ms a 12 ms en produccion.',
    );
    await tester.ensureVisible(find.byKey(const Key('boton-guardar-idea')));
    await tester.tap(find.byKey(const Key('boton-guardar-idea')));
    // Se busca el titulo DENTRO de la tarjeta del listado: durante la animacion
    // de cierre el campo del formulario sigue montado con el mismo texto, y
    // `find.text` lo encontraria a el primero.
    final tarjeta = find.descendant(
      of: find.byType(TarjetaIdea),
      matching: find.text(titulo),
    );
    await _esperar(tester, tarjeta);
    await tester.pumpAndSettle();

    // 3. Abrir el detalle (GET /ideas/{id} y GET /ideas/{id}/publicaciones).
    await tester.tap(tarjeta);
    await _esperar(tester, find.text('Publicaciones con IA'));

    // 4. Generar con IA: 202, consultas a /jobs/{id} y lectura del resultado.
    final generar = find.byKey(const Key('boton-generar-publicacion'));
    await tester.scrollUntilVisible(generar, 300,
        scrollable: _scrollDelDetalle());
    await tester.tap(find.text('LinkedIn'));
    await tester.pump();
    await tester.tap(generar);
    await _esperar(
      tester,
      find.textContaining('Publicación para LinkedIn lista'),
      limite: const Duration(seconds: 90),
    );
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);

    // 5. Eliminar desde la interfaz (DELETE /ideas/{id}).
    await tester.tap(find.byKey(const Key('boton-eliminar-idea')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boton-confirmar-eliminar-idea')));
    await _esperar(tester, find.text('Idea eliminada de la base de datos.'));
    await tester.pumpAndSettle();
    expect(tarjeta, findsNothing);

    // 6. Comprobacion independiente de la interfaz: la base ya no la tiene.
    final login = await apiDePreparacion.iniciarSesion(
      email: email,
      password: password,
    );
    apiDePreparacion.token = login.datos;
    final ideas = (await apiDePreparacion.listarIdeas()).datos;
    expect(ideas.where((i) => i.titulo == titulo), isEmpty);
  });
}
