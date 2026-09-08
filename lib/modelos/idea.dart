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
    this.contenido,
  });

  factory Idea.desdeJson(Map<String, dynamic> json) => Idea(
        id: json['id'] as int,
        titulo: json['titulo'] as String,
        estado: json['estado'] as String,
        origen: json['origen'] as String,
        etiquetas: (json['etiquetas'] as List<dynamic>).cast<String>(),
        numPublicaciones: json['num_publicaciones'] as int,
        creadoEn: DateTime.parse(json['creado_en'] as String),
        contenido: json['contenido'] as String?,
      );

  final int id;
  final String titulo;
  final String estado;
  final String origen;
  final List<String> etiquetas;
  final int numPublicaciones;
  final DateTime creadoEn;

  /// Texto completo de la idea. Es NULLABLE a proposito: el backend expone dos
  /// esquemas distintos y el del listado (`IdeaOut`) omite este campo por ser el
  /// mas pesado, mientras que el del detalle (`IdeaDetalleOut`) si lo incluye.
  /// Asi se reduce la carga de datos innecesaria en la peticion que trae muchas
  /// filas; el contenido solo viaja cuando de verdad se va a leer.
  final String? contenido;

  /// Copia con campos sustituidos. La usa la capa de estado para reemplazar una
  /// idea del listado por su version con detalle sin perder el resto de datos.
  Idea copiaCon({
    String? titulo,
    String? estado,
    String? origen,
    List<String>? etiquetas,
    int? numPublicaciones,
    String? contenido,
  }) =>
      Idea(
        id: id,
        titulo: titulo ?? this.titulo,
        estado: estado ?? this.estado,
        origen: origen ?? this.origen,
        etiquetas: etiquetas ?? this.etiquetas,
        numPublicaciones: numPublicaciones ?? this.numPublicaciones,
        creadoEn: creadoEn,
        contenido: contenido ?? this.contenido,
      );
}
