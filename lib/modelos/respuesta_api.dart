/// Resultado de una llamada a la API, con los datos de diagnostico que el
/// backend devuelve en cabeceras (`X-Process-Time-ms`, `X-Query-Count`,
/// `X-Cache`). Se muestran en pantalla para evidenciar que la respuesta viene
/// realmente del backend y no de un dato quemado en la aplicacion.
class RespuestaApi<T> {
  const RespuestaApi({
    required this.datos,
    required this.codigoEstado,
    required this.milisegundosCliente,
    required this.cabeceras,
  });

  final T datos;
  final int codigoEstado;
  final int milisegundosCliente;
  final Map<String, String> cabeceras;

  String? get tiempoServidorMs => cabeceras['x-process-time-ms'];
  String? get consultasSql => cabeceras['x-query-count'];
  String? get cache => cabeceras['x-cache'];
}

/// Error de comunicacion con la API, ya traducido a un mensaje entendible.
///
/// [codigoEstado] permite que la capa de estado distinga los casos que el
/// usuario debe entender de forma distinta: 401 credenciales invalidas o
/// sesion expirada, 409 correo ya registrado, 422 datos rechazados por la
/// validacion del servidor.
class ErrorApi implements Exception {
  ErrorApi(this.mensaje, {this.sugerencia, this.codigoEstado});

  final String mensaje;
  final String? sugerencia;
  final int? codigoEstado;

  bool get esNoAutorizado => codigoEstado == 401 || codigoEstado == 403;
  bool get esConflicto => codigoEstado == 409;
  bool get esValidacion => codigoEstado == 422;
  bool get esDeRed => codigoEstado == null;

  @override
  String toString() => mensaje;
}
