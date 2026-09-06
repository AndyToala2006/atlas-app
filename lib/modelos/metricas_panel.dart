/// Reporte analitico del usuario, devuelto por `GET /dashboard/metricas`.
///
/// En el backend es la operacion mas costosa y esta protegida con cache-aside:
/// la cabecera `X-Cache` indica si la respuesta vino de Redis (HIT) o si hubo
/// que recalcularla (MISS).
class MetricasPanel {
  const MetricasPanel({
    required this.totalIdeas,
    required this.totalPublicaciones,
    required this.likes,
    required this.comentarios,
    required this.compartidos,
    required this.alcance,
    required this.topEtiquetas,
    required this.generadoEn,
  });

  factory MetricasPanel.desdeJson(Map<String, dynamic> json) {
    final engagement = (json['engagement'] as Map<String, dynamic>?) ?? const {};
    final top = (json['top_etiquetas'] as List<dynamic>?) ?? const [];
    return MetricasPanel(
      totalIdeas: json['total_ideas'] as int? ?? 0,
      totalPublicaciones: json['total_publicaciones'] as int? ?? 0,
      likes: engagement['likes'] as int? ?? 0,
      comentarios: engagement['comentarios'] as int? ?? 0,
      compartidos: engagement['compartidos'] as int? ?? 0,
      alcance: engagement['alcance'] as int? ?? 0,
      topEtiquetas: top
          .map((e) => EtiquetaUso.desdeJson(e as Map<String, dynamic>))
          .toList(growable: false),
      generadoEn: DateTime.parse(json['generado_en'] as String),
    );
  }

  final int totalIdeas;
  final int totalPublicaciones;
  final int likes;
  final int comentarios;
  final int compartidos;
  final int alcance;
  final List<EtiquetaUso> topEtiquetas;
  final DateTime generadoEn;
}

/// Etiqueta mas usada por el usuario y su numero de apariciones.
class EtiquetaUso {
  const EtiquetaUso({required this.nombre, required this.usos});

  factory EtiquetaUso.desdeJson(Map<String, dynamic> json) => EtiquetaUso(
        nombre: json['nombre'] as String,
        usos: json['usos'] as int,
      );

  final String nombre;
  final int usos;
}
