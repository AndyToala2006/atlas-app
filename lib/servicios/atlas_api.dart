import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../modelos/idea.dart';
import '../modelos/metricas_panel.dart';
import '../modelos/respuesta_api.dart';
import '../modelos/usuario.dart';

/// Cliente de la API de Atlas (proyecto atlas-backend, FastAPI).
///
/// Es la capa de SERVICIO: solo sabe hablar HTTP. No decide si hay sesión ni
/// guarda al usuario; de eso se encarga `estado/controlador_sesion.dart`. Lo
/// único que retiene es el [token] vigente, porque debe adjuntarlo en la
/// cabecera `Authorization` de cada petición protegida.
class AtlasApi {
  AtlasApi({http.Client? cliente, String? baseUrl})
      : _cliente = cliente ?? http.Client(),
        baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _cliente;
  final String baseUrl;

  /// JWT emitido por el backend. Lo escribe el controlador de sesión al
  /// autenticar y lo borra al cerrar sesión.
  String? token;

  bool get tieneToken => token != null;

  Map<String, String> get _cabeceras => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ----------------------------------------------------------------- público

  /// GET /health — endpoint público, es la primera prueba de conectividad.
  Future<RespuestaApi<Map<String, dynamic>>> verificarSalud() {
    return _ejecutar(
      () => _cliente.get(Uri.parse('$baseUrl/health'), headers: _cabeceras),
      (cuerpo) => jsonDecode(cuerpo) as Map<String, dynamic>,
    );
  }

  /// POST /auth/register — crea la cuenta y devuelve el JWT del nuevo usuario.
  Future<RespuestaApi<String>> registrar({
    required String email,
    required String nombre,
    required String password,
    required String tono,
  }) {
    return _ejecutar(
      () => _cliente.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _cabeceras,
        body: jsonEncode({
          'email': email,
          'nombre': nombre,
          'password': password,
          'tono': tono,
        }),
      ),
      _leerToken,
    );
  }

  /// POST /auth/login — valida las credenciales y devuelve el JWT.
  Future<RespuestaApi<String>> iniciarSesion({
    required String email,
    required String password,
  }) {
    return _ejecutar(
      () => _cliente.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _cabeceras,
        body: jsonEncode({'email': email, 'password': password}),
      ),
      _leerToken,
    );
  }

  // --------------------------------------------------------------- protegido

  /// GET /auth/me — identidad del usuario tomada del JWT (0 consultas SQL).
  Future<RespuestaApi<Usuario>> perfil() {
    return _ejecutar(
      () => _cliente.get(Uri.parse('$baseUrl/auth/me'), headers: _cabeceras),
      (cuerpo) => Usuario.desdeJson(jsonDecode(cuerpo) as Map<String, dynamic>),
    );
  }

  /// GET /ideas — listado del usuario autenticado.
  ///
  /// [optimizado] alterna entre la consulta con eager loading y la versión
  /// ingenua con N+1; la diferencia se lee en la cabecera `X-Query-Count`.
  Future<RespuestaApi<List<Idea>>> listarIdeas({bool optimizado = true}) {
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

  /// GET /ideas/{id} — recarga una idea concreta desde la base de datos.
  Future<RespuestaApi<Idea>> obtenerIdea(int id) {
    return _ejecutar(
      () => _cliente.get(Uri.parse('$baseUrl/ideas/$id'), headers: _cabeceras),
      (cuerpo) => Idea.desdeJson(jsonDecode(cuerpo) as Map<String, dynamic>),
    );
  }

  /// POST /ideas — crea una idea y devuelve la fila persistida en Postgres.
  Future<RespuestaApi<Idea>> crearIdea({
    required String titulo,
    required String contenido,
    List<String> etiquetas = const [],
  }) {
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

  /// GET /dashboard/metricas — reporte agregado del usuario (caché-aside).
  Future<RespuestaApi<MetricasPanel>> metricas() {
    return _ejecutar(
      () => _cliente.get(
        Uri.parse('$baseUrl/dashboard/metricas'),
        headers: _cabeceras,
      ),
      (cuerpo) =>
          MetricasPanel.desdeJson(jsonDecode(cuerpo) as Map<String, dynamic>),
    );
  }

  // ----------------------------------------------------------------- interno

  static String _leerToken(String cuerpo) =>
      (jsonDecode(cuerpo) as Map<String, dynamic>)['access_token'] as String;

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

  /// Traduce el cuerpo de error de FastAPI a una sola línea legible.
  ///
  /// `detail` llega como texto en los errores de negocio (401, 404, 409) y
  /// como lista de objetos en los errores de validación de Pydantic (422).
  String _mensajeDeError(http.Response respuesta) {
    try {
      final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (cuerpo is Map<String, dynamic>) {
        final detalle = cuerpo['detail'];
        if (detalle is String && detalle.isNotEmpty) return detalle;
        if (detalle is List && detalle.isNotEmpty) {
          final mensajes = detalle
              .whereType<Map<String, dynamic>>()
              .map((e) => (e['msg'] ?? '').toString())
              .where((m) => m.isNotEmpty);
          if (mensajes.isNotEmpty) return mensajes.join('\n');
        }
      }
    } catch (_) {
      // Cuerpo no JSON: se usa el mensaje genérico de abajo.
    }
    return 'La API respondio con el codigo ${respuesta.statusCode}.';
  }
}
