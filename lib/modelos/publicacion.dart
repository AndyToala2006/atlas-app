import 'metrica.dart';

/// Publicación generada con IA a partir de una idea, tal como la devuelve
/// `GET /ideas/{id}/publicaciones`.
class Publicacion {
  const Publicacion({
    required this.id,
    required this.ideaId,
    required this.redSocial,
    required this.texto,
    required this.tono,
    required this.modeloIa,
    required this.creadoEn,
    this.ultimaMetrica,
    this.numMetricas = 0,
  });

  factory Publicacion.desdeJson(Map<String, dynamic> json) => Publicacion(
    id: json['id'] as int,
    ideaId: json['idea_id'] as int,
    redSocial: json['red_social'] as String,
    texto: json['contenido_generado'] as String,
    tono: json['tono'] as String,
    modeloIa: json['modelo_ia'] as String,
    creadoEn: DateTime.parse(json['creado_en'] as String),
    ultimaMetrica: json['ultima_metrica'] == null
        ? null
        : Metrica.desdeJson(json['ultima_metrica'] as Map<String, dynamic>),
    numMetricas: json['num_metricas'] as int? ?? 0,
  );

  final int id;
  final int ideaId;
  final String redSocial;
  final String texto;
  final String tono;

  /// Modelo que la redactó (por ejemplo `anthropic/claude-haiku-4.5`), o
  /// `atlas-sim-1` si el backend no tiene API key y usó el generador simulado.
  final String modeloIa;
  final DateTime creadoEn;

  /// Rendimiento más reciente registrado, o `null` si aún no se midió.
  final Metrica? ultimaMetrica;

  /// Cuántos registros de rendimiento tiene (su historial).
  final int numMetricas;

  bool get esSimulada => modeloIa == modeloSimulado;

  static const String modeloSimulado = 'atlas-sim-1';
}

/// Redes sociales para las que el backend sabe redactar. El valor viaja tal
/// cual en el cuerpo de `POST /ideas/{id}/publicar`.
enum RedSocial {
  instagram('instagram', 'Instagram'),
  linkedin('linkedin', 'LinkedIn'),
  x('x', 'X');

  const RedSocial(this.valor, this.nombre);

  final String valor;
  final String nombre;

  static RedSocial desdeValor(String valor) => RedSocial.values.firstWhere(
    (r) => r.valor == valor,
    orElse: () => RedSocial.instagram,
  );
}
