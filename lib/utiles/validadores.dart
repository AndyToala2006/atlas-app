/// Validaciones reutilizables de los formularios.
///
/// Viven fuera de las pantallas por dos razones: se usan en más de un
/// formulario (el correo se valida en login y en registro) y así se pueden
/// probar sin levantar la interfaz. Cada función devuelve `null` cuando el
/// valor es aceptable y el mensaje de error cuando no lo es, que es
/// exactamente el contrato que espera `TextFormField.validator`.
///
/// Los límites replican los del backend (`app/schemas.py`) para que el
/// formulario rechace en el teléfono lo mismo que rechazaría el servidor.
class Validadores {
  const Validadores._();

  /// Formato de correo: algo@algo.dominio, sin espacios.
  static final RegExp _correo = RegExp(r'^[\w.!#$%&*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$');

  static String? correo(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'El correo es obligatorio';
    if (texto.length > 160) return 'El correo no puede superar 160 caracteres';
    if (!_correo.hasMatch(texto)) {
      return 'Formato de correo no válido (ejemplo: nombre@dominio.com)';
    }
    return null;
  }

  static String? contrasena(String? valor) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'La contraseña es obligatoria';
    if (texto.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
    // bcrypt trunca en 72 bytes y el esquema del backend lo declara así.
    if (texto.length > 72) return 'La contraseña no puede superar 72 caracteres';
    return null;
  }

  /// Igual que [contrasena] pero exigiendo además una letra y un número, que
  /// es la regla que aplica el registro para no crear cuentas triviales.
  static String? contrasenaNueva(String? valor) {
    final basico = contrasena(valor);
    if (basico != null) return basico;
    final texto = valor!;
    if (!texto.contains(RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]'))) {
      return 'La contraseña debe incluir al menos una letra';
    }
    if (!texto.contains(RegExp(r'[0-9]'))) {
      return 'La contraseña debe incluir al menos un número';
    }
    return null;
  }

  static String? confirmacion(String? valor, String original) {
    if ((valor ?? '').isEmpty) return 'Repite la contraseña';
    if (valor != original) return 'Las contraseñas no coinciden';
    return null;
  }

  static String? nombre(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'El nombre es obligatorio';
    if (texto.length < 2) return 'El nombre debe tener al menos 2 caracteres';
    if (texto.length > 120) return 'El nombre no puede superar 120 caracteres';
    return null;
  }

  static String? titulo(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'El título es obligatorio';
    if (texto.length < 2) return 'El título debe tener al menos 2 caracteres';
    if (texto.length > 160) return 'El título no puede superar 160 caracteres';
    return null;
  }

  static String? contenido(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Describe la idea antes de guardarla';
    if (texto.length < 10) return 'Escribe al menos 10 caracteres';
    return null;
  }

  /// Las etiquetas son opcionales, pero si se escriben deben ser palabras
  /// separadas por coma, sin elementos vacíos.
  static String? etiquetas(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return null;
    final partes = texto.split(',');
    if (partes.any((p) => p.trim().isEmpty)) {
      return 'Separa las etiquetas con coma, sin dejar ninguna vacía';
    }
    if (partes.length > 5) return 'Máximo 5 etiquetas';
    if (partes.any((p) => p.trim().length > 40)) {
      return 'Cada etiqueta debe tener 40 caracteres o menos';
    }
    return null;
  }

  /// Una métrica de rendimiento (likes, alcance...): entero, sin signo y con el
  /// mismo tope que el backend (`MetricaCreate`, `ge=0`, `le=1e9`).
  static String? metrica(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Obligatorio (0 si no hubo)';
    final numero = int.tryParse(texto);
    if (numero == null) return 'Solo números enteros';
    if (numero < 0) return 'No puede ser negativo';
    if (numero > 1000000000) return 'Valor demasiado grande';
    return null;
  }

  /// Convierte el texto del campo de etiquetas en la lista que espera la API.
  static List<String> partirEtiquetas(String valor) => valor
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList(growable: false);
}
