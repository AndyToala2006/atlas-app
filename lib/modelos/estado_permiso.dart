/// Los cuatro estados en los que puede quedar un permiso del sistema, tal
/// como los describe la guía del taller.
///
/// Se declara aquí, fuera de `permission_handler`, para que los servicios de
/// [voz](../servicios/voz_servicio.dart) y
/// [notificaciones](../servicios/notificaciones_servicio.dart) compartan un
/// mismo vocabulario y las pantallas no dependan directamente del paquete de
/// terceros: si el día de mañana cambia el plugin, solo cambia el mapeo en un
/// sitio.
enum EstadoPermiso {
  /// El usuario concedió el permiso: la funcionalidad puede usarse.
  concedido,

  /// El usuario lo negó, pero el sistema todavía permite volver a preguntar
  /// (por ejemplo, tras explicar de nuevo por qué se necesita).
  denegado,

  /// El usuario marcó "no volver a preguntar" (Android) o ya rechazó el
  /// permiso una vez desde el diálogo del sistema (iOS). A partir de aquí
  /// `solicitar()` no vuelve a mostrar el diálogo nativo: la única salida es
  /// abrir los ajustes de la aplicación.
  denegadoPermanente,

  /// El permiso está bloqueado por una política externa al usuario: control
  /// parental, perfil de trabajo o un MDM corporativo. Ni pedirlo ni abrir
  /// los ajustes de la aplicación sirve de algo.
  restringido;

  bool get concedidoOk => this == EstadoPermiso.concedido;

  /// `true` cuando hace falta guiar al usuario a los ajustes del sistema para
  /// revertir la decisión, porque volver a pedir el permiso no tendría efecto.
  bool get requiereAjustes =>
      this == EstadoPermiso.denegadoPermanente ||
      this == EstadoPermiso.restringido;
}
