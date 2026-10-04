import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../modelos/estado_permiso.dart';

/// Dictado por voz: convierte el micrófono en el texto del campo "Contenido"
/// de una idea. Es la funcionalidad ESENCIAL del taller: el proyecto Atlas se
/// presenta desde la Semana 9 como una aplicación que "captura ideas por
/// texto o por audio", y hasta la Semana 13 solo existía la mitad de esa
/// frase.
///
/// Se define como interfaz por la misma razón que [AlmacenSesion]
/// (`servicios/almacen_sesion.dart`): las pruebas de widget la sustituyen por
/// [VozServicioFalso], sin depender del canal nativo de `speech_to_text` ni
/// de `permission_handler`, que no existen en el entorno de `flutter test`.
abstract class VozServicio {
  /// Comprueba que el RECONOCEDOR de voz del dispositivo responde. Es una
  /// condición DISTINTA del permiso: un teléfono puede tener el micrófono
  /// autorizado y aun así no tener el servicio de reconocimiento (por
  /// ejemplo, sin Google app en un Android sin Play Services). Confundir las
  /// dos cosas es el error que la guía del taller pide evitar explícitamente.
  Future<bool> hayReconocimientoDisponible();

  Future<EstadoPermiso> estadoPermiso();

  /// Muestra el diálogo nativo. En Android, si el usuario ya marcó "no volver
  /// a preguntar", el sistema no vuelve a mostrarlo y esta llamada resuelve
  /// de inmediato en [EstadoPermiso.denegadoPermanente].
  Future<EstadoPermiso> solicitarPermiso();

  /// Empieza a escuchar. [alReconocerParcial] se invoca en cada tramo
  /// reconocido mientras el usuario sigue hablando (para que el campo de
  /// texto se vea crecer en vivo) y [alFinalizar] cuando el motor da el
  /// resultado por definitivo. [alFallar] se invoca si el reconocedor no está
  /// disponible o el motor nativo devuelve un error a media escucha.
  Future<void> escuchar({
    required void Function(String texto) alReconocerParcial,
    required void Function(String texto) alFinalizar,
    void Function()? alFallar,
  });

  Future<void> detener();
  Future<void> cancelar();
  bool get escuchando;

  /// Abre la pantalla de ajustes de la aplicación en el sistema operativo.
  /// Es el único camino quando el permiso quedó en denegación permanente.
  Future<void> abrirAjustesDeLaApp();
}

/// Implementación real, sobre `speech_to_text` + `permission_handler`.
///
/// El permiso se pide con `permission_handler` en lugar de dejárselo al
/// `initialize()` propio de `speech_to_text` porque este último solo informa
/// "concedido o no": no distingue la denegación permanente de la simple, así
/// que no alcanzaría para implementar los cuatro estados que exige el taller.
class VozServicioDispositivo implements VozServicio {
  VozServicioDispositivo({stt.SpeechToText? motor})
    : _motor = motor ?? stt.SpeechToText();

  final stt.SpeechToText _motor;
  bool _inicializado = false;

  @override
  Future<bool> hayReconocimientoDisponible() async {
    if (_inicializado) return _motor.isAvailable;
    _inicializado = await _motor.initialize(onError: (_) {}, onStatus: (_) {});
    return _inicializado;
  }

  @override
  Future<EstadoPermiso> estadoPermiso() async {
    // `Permission.speech` solo pesa en iOS (autorización del reconocedor de
    // Apple, separada del micrófono); en Android `permission_handler` la
    // trata como concedida siempre, así que combinar ambas no penaliza a
    // Android y sí cubre el caso de iOS.
    final estados = await Future.wait([
      Permission.microphone.status,
      Permission.speech.status,
    ]);
    return _combinar(estados);
  }

  @override
  Future<EstadoPermiso> solicitarPermiso() async {
    final resultado = await [
      Permission.microphone,
      Permission.speech,
    ].request();
    return _combinar(resultado.values.toList());
  }

  @override
  Future<void> escuchar({
    required void Function(String texto) alReconocerParcial,
    required void Function(String texto) alFinalizar,
    void Function()? alFallar,
  }) async {
    final disponible = await hayReconocimientoDisponible();
    if (!disponible) {
      alFallar?.call();
      return;
    }
    await _motor.listen(
      onResult: (resultado) {
        if (resultado.finalResult) {
          alFinalizar(resultado.recognizedWords);
        } else {
          alReconocerParcial(resultado.recognizedWords);
        }
      },
      listenOptions: stt.SpeechListenOptions(cancelOnError: true),
    );
  }

  @override
  Future<void> detener() => _motor.stop();

  @override
  Future<void> cancelar() => _motor.cancel();

  @override
  bool get escuchando => _motor.isListening;

  @override
  Future<void> abrirAjustesDeLaApp() async {
    await openAppSettings();
  }

  static EstadoPermiso _combinar(List<PermissionStatus> estados) {
    if (estados.any((e) => e.isPermanentlyDenied)) {
      return EstadoPermiso.denegadoPermanente;
    }
    if (estados.any((e) => e.isRestricted)) {
      return EstadoPermiso.restringido;
    }
    if (estados.every((e) => e.isGranted || e.isLimited)) {
      return EstadoPermiso.concedido;
    }
    return EstadoPermiso.denegado;
  }
}

/// Implementación en memoria, para las pruebas de widget.
///
/// Los cuatro estados se simulan a mano: [estadoInicial] es lo que devuelve
/// [estadoPermiso] antes de pedirlo, y [estadoTrasSolicitar] lo que devuelve
/// [solicitarPermiso], que puede ser distinto (por ejemplo, para probar el
/// camino en el que el usuario deniega en el diálogo del sistema).
class VozServicioFalso implements VozServicio {
  VozServicioFalso({
    this.disponible = true,
    this.estadoInicial = EstadoPermiso.concedido,
    EstadoPermiso? estadoTrasSolicitar,
    this.textoReconocido = 'Idea dictada de prueba',
  }) : _estado = estadoInicial,
       _estadoTrasSolicitar = estadoTrasSolicitar ?? estadoInicial;

  final bool disponible;
  final EstadoPermiso estadoInicial;
  final EstadoPermiso _estadoTrasSolicitar;
  final String textoReconocido;

  EstadoPermiso _estado;
  bool _escuchando = false;
  bool ajustesAbiertos = false;

  @override
  Future<bool> hayReconocimientoDisponible() async => disponible;

  @override
  Future<EstadoPermiso> estadoPermiso() async => _estado;

  @override
  Future<EstadoPermiso> solicitarPermiso() async {
    _estado = _estadoTrasSolicitar;
    return _estado;
  }

  @override
  Future<void> escuchar({
    required void Function(String texto) alReconocerParcial,
    required void Function(String texto) alFinalizar,
    void Function()? alFallar,
  }) async {
    if (!disponible) {
      alFallar?.call();
      return;
    }
    _escuchando = true;
    alFinalizar(textoReconocido);
    _escuchando = false;
  }

  @override
  Future<void> detener() async => _escuchando = false;

  @override
  Future<void> cancelar() async => _escuchando = false;

  @override
  bool get escuchando => _escuchando;

  @override
  Future<void> abrirAjustesDeLaApp() async => ajustesAbiertos = true;
}
