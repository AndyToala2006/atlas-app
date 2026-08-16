import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Resultado de una llamada a la API, con los datos de diagnóstico que el
/// backend devuelve en cabeceras (`X-Process-Time-ms`, `X-Query-Count`,
/// `X-Cache`). Se muestran en pantalla para evidenciar que la respuesta viene
/// realmente del backend y no de un dato quemado en la app.
class RespuestaApi<T> {
  RespuestaApi({
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

/// Error de comunicación con la API, ya traducido a un mensaje entendible.
class ErrorApi implements Exception {
  ErrorApi(this.mensaje, {this.sugerencia, this.codigoEstado});

  final String mensaje;
  final String? sugerencia;
  final int? codigoEstado;

  @override
  String toString() => mensaje;
}

/// Modelo de una idea tal como la devuelve `GET /ideas`.
class Idea {
  Idea({
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

/// Cliente de la API de Atlas (proyecto atlas-backend, FastAPI).
///
/// Concentra en un solo lugar la URL base, la cabecera Authorization y la
/// traducción de errores de red, para que las pantallas no repitan esa lógica.
class AtlasApi {
  AtlasApi({http.Client? cliente, String? baseUrl})
      : _cliente = cliente ?? http.Client(),
        baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _cliente;
  final String baseUrl;

  String? _token;

  bool get haySesion => _token != null;

  void cerrarSesion() => _token = null;

  Map<String, String> get _cabeceras => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// GET /health — endpoint público, es la primera prueba de conectividad.
  Future<RespuestaApi<Map<String, dynamic>>> verificarSalud() async {
    return _ejecutar(
      () => _cliente.get(Uri.parse('$baseUrl/health'), headers: _cabeceras),
      (cuerpo) => jsonDecode(cuerpo) as Map<String, dynamic>,
    );
  }

  /// POST /auth/login — obtiene el JWT y lo guarda en memoria.
  Future<RespuestaApi<String>> iniciarSesion(String email, String password) async {
    final respuesta = await _ejecutar(
      () => _cliente.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _cabeceras,
        body: jsonEncode({'email': email, 'password': password}),
      ),
      (cuerpo) => (jsonDecode(cuerpo) as Map<String, dynamic>)['access_token'] as String,
    );
    _token = respuesta.datos;
    return respuesta;
  }

  /// GET /auth/me — identidad del usuario tomada del JWT (0 consultas SQL).
  Future<RespuestaApi<Map<String, dynamic>>> perfil() async {
    return _ejecutar(
      () => _cliente.get(Uri.parse('$baseUrl/auth/me'), headers: _cabeceras),
      (cuerpo) => jsonDecode(cuerpo) as Map<String, dynamic>,
    );
  }

  /// GET /ideas — listado del usuario autenticado.
  ///
  /// [optimizado] alterna entre la consulta con eager loading y la versión
  /// ingenua con N+1; la diferencia se lee en la cabecera `X-Query-Count`.
  Future<RespuestaApi<List<Idea>>> listarIdeas({bool optimizado = true}) async {
    return _ejecutar(
      () => _cliente.get(
        Uri.parse('$baseUrl/ideas?optimized=$optimizado'),
        headers: _cabeceras,
      ),
      (cuerpo) => (jsonDecode(cuerpo) as List<dynamic>)
          .map((e) => Idea.desdeJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// POST /ideas — crea una idea y devuelve la fila persistida en Postgres.
  Future<RespuestaApi<Idea>> crearIdea({
    required String titulo,
    required String contenido,
    List<String> etiquetas = const [],
  }) async {
    return _ejecutar(
      () => _cliente.post(
        Uri.parse('$baseUrl/ideas'),
        headers: _cabeceras,
        body: jsonEncode({
          'titulo': titulo,
          'contenido': contenido,
          'origen': 'texto',
          'etiquetas': etiquetas,
        }),
      ),
      (cuerpo) => Idea.desdeJson(jsonDecode(cuerpo) as Map<String, dynamic>),
    );
  }

  /// Envuelve la llamada HTTP: mide el tiempo, valida el código de estado y
  /// convierte las excepciones de red en mensajes accionables.
  Future<RespuestaApi<T>> _ejecutar<T>(
    Future<http.Response> Function() peticion,
    T Function(String cuerpo) convertir,
  ) async {
    final cronometro = Stopwatch()..start();
    try {
      final respuesta = await peticion().timeout(AppConfig.timeout);
      cronometro.stop();

      if (respuesta.statusCode >= 400) {
        throw ErrorApi(
          _mensajeDeError(respuesta),
          codigoEstado: respuesta.statusCode,
        );
      }

      return RespuestaApi<T>(
        datos: convertir(utf8.decode(respuesta.bodyBytes)),
        codigoEstado: respuesta.statusCode,
        milisegundosCliente: cronometro.elapsedMilliseconds,
        cabeceras: respuesta.headers,
      );
    } on TimeoutException {
      throw ErrorApi(
        'El backend no respondio en ${AppConfig.timeout.inSeconds} segundos.',
        sugerencia:
            'Verifica que el telefono y el computador esten en la misma red Wi-Fi '
            'y que la regla del firewall para el puerto 8000 este activa.',
      );
    } on SocketException catch (e) {
      throw ErrorApi(
        'No se pudo establecer conexion con $baseUrl',
        sugerencia:
            'Revisa que el backend este levantado (docker compose up), que la IP '
            'configurada sea la actual del computador y que el firewall permita '
            'el puerto 8000. Detalle: ${e.osError?.message ?? e.message}',
      );
    } on http.ClientException catch (e) {
      throw ErrorApi(
        'La solicitud fue rechazada por la plataforma.',
        sugerencia:
            'Si el mensaje menciona "cleartext", falta autorizar el host en '
            'network_security_config.xml. Detalle: ${e.message}',
      );
    }
  }

  String _mensajeDeError(http.Response respuesta) {
    try {
      final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (cuerpo is Map<String, dynamic> && cuerpo['detail'] != null) {
        return '${respuesta.statusCode}: ${cuerpo['detail']}';
      }
    } catch (_) {
      // Cuerpo no JSON: se usa el mensaje genérico de abajo.
    }
    return 'La API respondio con el codigo ${respuesta.statusCode}.';
  }
}
