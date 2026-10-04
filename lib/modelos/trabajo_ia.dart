/// Trabajo de generación encolado en el backend (`GET /jobs/{id}`).
///
/// Generar una publicación tarda varios segundos (es una llamada a un modelo de
/// lenguaje), así que el backend no la hace dentro del request: responde 202
/// con el id del trabajo y el worker de Celery lo procesa aparte. La app
/// consulta este recurso hasta que llega a un estado final.
class TrabajoIa {
  const TrabajoIa({
    required this.id,
    required this.ideaId,
    required this.estado,
    this.publicacionId,
    this.error,
  });

  factory TrabajoIa.desdeJson(Map<String, dynamic> json) => TrabajoIa(
    id: json['id'] as String,
    ideaId: json['idea_id'] as int,
    estado: json['estado'] as String,
    publicacionId: json['resultado_publicacion_id'] as int?,
    error: json['error'] as String?,
  );

  final String id;
  final int ideaId;

  /// `queued` | `processing` | `done` | `error`.
  final String estado;
  final int? publicacionId;
  final String? error;

  bool get terminado => estado == 'done';
  bool get fallido => estado == 'error';
  bool get enCurso => !terminado && !fallido;
}
