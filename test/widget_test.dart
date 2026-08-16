// Pruebas de humo del proyecto base de Atlas.
//
// Verifican que la aplicacion arranca, que muestra la URL base inyectada por
// --dart-define y que la navegacion entre las tres pantallas funciona.

import 'package:atlas_app/config/app_config.dart';
import 'package:atlas_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('La aplicacion arranca en la pantalla de conexion',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AtlasApp());

    expect(find.text('Atlas'), findsOneWidget);
    expect(find.text('Configuración del entorno'), findsOneWidget);
    expect(find.text('Probar conexión con la API'), findsOneWidget);
  });

  testWidgets('Muestra la URL base inyectada por --dart-define',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AtlasApp());

    expect(find.text(AppConfig.apiBaseUrl), findsOneWidget);
  });

  testWidgets('La barra inferior navega entre las tres pantallas',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AtlasApp());

    await tester.tap(find.widgetWithText(NavigationDestination, 'Sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Ideas'));
    await tester.pumpAndSettle();
    expect(find.text('Cargar ideas'), findsOneWidget);
  });
}
