/// Registro de rendimiento de una publicación en un momento dado
/// (`GET /publicaciones/{id}/metricas`).
///
/// Es una FOTO, no un incremento: si el lunes la publicación tenía 100 likes y
/// el viernes 250, hay dos registros y el rendimiento vigente es el último.
/// Así el usuario puede seguir la evolución de un contenido en el tiempo.
class Metrica {
  const Metrica({
    required this.id,
    required this.fuente,
    required this.likes,
    required this.comentarios,
    required this.compartidos,
    required this.alcance,
    required this.fecha,
  });

  factory Metrica.desdeJson(Map<String, dynamic> json) => Metrica(
    id: json['id'] as int,
    fuente: json['fuente'] as String,
    likes: json['likes'] as int,
    comentarios: json['comentarios'] as int,
    compartidos: json['compartidos'] as int,
    alcance: json['alcance'] as int,
    fecha: DateTime.parse(json['fecha'] as String),
  );

  final int id;

  /// `manual` (lo escribió el usuario) o `api` (captura automática desde la
  /// red social, cuando su API lo permita).
  final String fuente;
  final int likes;
  final int comentarios;
  final int compartidos;
  final int alcance;
  final DateTime fecha;

  /// Interacciones totales: lo que el usuario compara entre publicaciones.
  int get interacciones => likes + comentarios + compartidos;
}
