/// Usuario autenticado del proyecto Atlas.
///
/// Corresponde al esquema `UsuarioOut` del backend, que es lo que devuelve
/// `GET /auth/me` a partir de los claims del JWT (sin consultar la base).
class Usuario {
  const Usuario({
    required this.id,
    required this.email,
    required this.nombre,
  });

  factory Usuario.desdeJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        email: json['email'] as String,
        nombre: (json['nombre'] as String?) ?? '',
      );

  final int id;
  final String email;
  final String nombre;

  /// Iniciales del nombre, para el avatar de la barra superior y del perfil.
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (partes.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
