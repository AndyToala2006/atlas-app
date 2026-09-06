/// Idea capturada por el usuario, tal como la devuelve `GET /ideas`.
class Idea {
  const Idea({
    required this.id,
    required this.titulo,
    required this.estado,
    required this.origen,
    required this.etiquetas,
    required this.numPublicaciones,
    required this.creadoEn,
  });

  factory Idea.desdeJson(Map<String, dynamic> json) => Idea(
        id: json['id'] as int,
        titulo: json['titulo'] as String,
        estado: json['estado'] as String,
        origen: json['origen'] as String,
        etiquetas: (json['etiquetas'] as List<dynamic>).cast<String>(),
        numPublicaciones: json['num_publicaciones'] as int,
        creadoEn: DateTime.parse(json['creado_en'] as String),
      );

  final int id;
  final String titulo;
  final String estado;
  final String origen;
  final List<String> etiquetas;
  final int numPublicaciones;
  final DateTime creadoEn;
}
