import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../modelos/estado_permiso.dart';

/// Aviso local de que una idea pasó a "publicada" en el backend.
///
/// No es notificación PUSH: no depende de un servidor de mensajería (FCM/APNs)
/// ni de que el backend sepa nada del dispositivo. Es una notificación LOCAL
/// que la propia aplicación programa cuando, al refrescar `GET /ideas`, ve que
/// el estado de una fila cambió de `procesando` a `publicada`. Es la
/// funcionalidad OPCIONAL del taller: sin permiso, o con el interruptor
/// apagado, la aplicación sigue funcionando exactamente igual, solo que el
/// usuario tiene que entrar a revisar el estado a mano.
///
/// Se define como interfaz por la misma razón que las demás en `servicios/`:
/// las pruebas de widget la sustituyen por [NotificacionesServicioFalso].
abstract class NotificacionesServicio {
  /// Crea el canal de notificaciones en Android. Idempotente: se puede llamar
  /// en cada arranque sin duplicar nada.
  Future<void> inicializar();

  Future<EstadoPermiso> estadoPermiso();

  /// En Android 13 (API 33) en adelante `POST_NOTIFICATIONS` es un permiso en
  /// tiempo de ejecución; antes de esa versión no existe y el estado siempre
  /// es "concedido". En iOS siempre hay que pedirlo explícitamente.
  Future<EstadoPermiso> solicitarPermiso();

  Future<void> mostrar({
    required int id,
    required String titulo,
    required String cuerpo,
  });

  Future<void> abrirAjustesDeLaApp();
}

class NotificacionesServicioLocal implements NotificacionesServicio {
  NotificacionesServicioLocal({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _idCanal = 'atlas_ideas_publicadas';
  static const _nombreCanal = 'Ideas publicadas';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _inicializado = false;

  @override
  Future<void> inicializar() async {
    if (_inicializado) return;
    // No se piden permisos aquí: `DarwinInitializationSettings` los deja en
    // `false` a propósito, porque el taller exige pedirlos en el momento de
    // uso (cuando el usuario activa el interruptor), no al arrancar.
    const configuracion = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: configuracion);
    _inicializado = true;
  }

  @override
  Future<EstadoPermiso> estadoPermiso() async {
    return _traducir(await Permission.notification.status);
  }

  @override
  Future<EstadoPermiso> solicitarPermiso() async {
    return _traducir(await Permission.notification.request());
  }

  @override
  Future<void> mostrar({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    await inicializar();
    const detalles = NotificationDetails(
      android: AndroidNotificationDetails(
        _idCanal,
        _nombreCanal,
        channelDescription:
            'Avisa cuando una idea capturada en Atlas termina de procesarse '
            'y ya tiene una publicación lista.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: id,
      title: titulo,
      body: cuerpo,
      notificationDetails: detalles,
    );
  }

  @override
  Future<void> abrirAjustesDeLaApp() async {
    await openAppSettings();
  }

  static EstadoPermiso _traducir(PermissionStatus estado) {
    if (estado.isPermanentlyDenied) return EstadoPermiso.denegadoPermanente;
    if (estado.isRestricted) return EstadoPermiso.restringido;
    if (estado.isGranted || estado.isLimited) return EstadoPermiso.concedido;
    return EstadoPermiso.denegado;
  }
}

/// Implementación en memoria, para las pruebas de widget.
class NotificacionesServicioFalso implements NotificacionesServicio {
  NotificacionesServicioFalso({
    this.estadoInicial = EstadoPermiso.concedido,
    EstadoPermiso? estadoTrasSolicitar,
  }) : _estado = estadoInicial,
       _estadoTrasSolicitar = estadoTrasSolicitar ?? estadoInicial;

  final EstadoPermiso estadoInicial;
  final EstadoPermiso _estadoTrasSolicitar;
  EstadoPermiso _estado;
  bool ajustesAbiertos = false;

  /// Notificaciones "mostradas", en el orden en que se mostraron. Las
  /// pruebas leen esta lista en vez de un canal nativo que no existe en
  /// `flutter test`.
  final List<({int id, String titulo, String cuerpo})> mostradas = [];

  @override
  Future<void> inicializar() async {}

  @override
  Future<EstadoPermiso> estadoPermiso() async => _estado;

  @override
  Future<EstadoPermiso> solicitarPermiso() async {
    _estado = _estadoTrasSolicitar;
    return _estado;
  }

  @override
  Future<void> mostrar({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    mostradas.add((id: id, titulo: titulo, cuerpo: cuerpo));
  }

  @override
  Future<void> abrirAjustesDeLaApp() async => ajustesAbiertos = true;
}
