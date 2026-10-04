// Pruebas UNITARIAS de las validaciones de formulario.
//
// Nivel unitario: funciones puras, sin interfaz ni red. Cubren el riesgo de que
// el telefono acepte algo que el backend rechaza con un 422 (o al reves), ya
// que los limites replican los de `app/schemas.py` del backend.

import 'package:atlas_app/utiles/validadores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validadores', () {
    test('las etiquetas respetan el maximo de 5 que impone el backend', () {
      expect(Validadores.etiquetas('a, b, c, d, e'), isNull);
      expect(Validadores.etiquetas('a, b, c, d, e, f'), 'Máximo 5 etiquetas');
      expect(Validadores.etiquetas('a,,b'), isNotNull);
    });

    test('partirEtiquetas normaliza igual que el backend: minusculas y sin '
        'repetidos', () {
      expect(
        Validadores.partirEtiquetas(' IA, ia ,Backend, '),
        ['ia', 'backend'],
      );
    });

    test('la contrasena nueva exige letra y numero y no pasa de 72', () {
      expect(Validadores.contrasenaNueva('abcdef'), contains('número'));
      expect(Validadores.contrasenaNueva('123456'), contains('letra'));
      expect(Validadores.contrasenaNueva('clave123'), isNull);
      expect(Validadores.contrasena('a' * 73), contains('72'));
    });

    test('el correo exige dominio con punto', () {
      expect(Validadores.correo('demo@atlas.app'), isNull);
      expect(Validadores.correo('demo@atlas'), isNotNull);
      expect(Validadores.correo('  '), 'El correo es obligatorio');
    });
  });
}
