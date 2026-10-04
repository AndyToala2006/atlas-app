# Guion del video — Taller Semana 14

**Incorporación de funcionalidades nativas al prototipo: dictado por voz y notificaciones locales**
Aplicaciones Móviles · 2626-UEA-L-UFPTI-008-C · Modalidad individual
Duración objetivo: **máximo 5 minutos**. Los tiempos de cada bloque suman ≈4:10, dejando margen; si te alargas en alguno, recorta primero el Bloque 6 (es una sola frase) y luego el cierre.

> El taller exige demostrar el comportamiento **con el permiso concedido** y **con el permiso denegado** —incluida la denegación permanente, con acceso a los ajustes del sistema—. Todo lo que sigue se ejecuta en vivo sobre el teléfono físico; el emulador no sirve para esta evidencia.

---

## Antes de grabar (lista de comprobación)

- [ ] **Backend levantado y con datos.** En `atlas-backend`: `docker compose up -d` y, si hace falta, `docker compose exec api python seed.py`.
- [ ] **Teléfono conectado y detectado**: `adb devices` debe listarlo como `device`.
- [ ] **App reinstalada con el código actual.** `.\run.ps1` (no sirve una instalación de una semana anterior: no tendría los permisos ni las funciones nuevas).
- [ ] **Pruebas en verde.** Ejecuta `flutter test` una vez antes de grabar: las **34** deben pasar (24 de semanas anteriores + 10 nuevas).
- [ ] **Permisos del teléfono reiniciados.** Ajustes → Apps → Atlas → Permisos → pon Micrófono y Notificaciones en "Preguntar cada vez" (o reinstala de cero). Si no haces esto, el primer intento no mostrará el diálogo real.
- [ ] **Inicia sesión ANTES de grabar, fuera de cámara.** En el login, escribe a mano `demo@atlas.app` / `atlas123` (la cuenta demo de `seed.py`; no es un secreto, ya está en texto plano en el repositorio `atlas-backend`). Si corriste `.\run.ps1` sin `-DemoEmail`/`-DemoPassword`, el botón de relleno automático no aparece, así que hay que escribirlo a mano. El login **no se repite** en este video: ya se demostró en semanas anteriores.
- [ ] **Acceso a la base de datos del backend a mano** (`docker compose exec` + `psql`, o tu cliente). No hay botón que dispare el procesamiento real de una idea: para el aviso de "publicada" hay que cambiar su `estado` a mano mientras la app está abierta.
- [ ] **Decide de antemano cómo forzar cada estado:** *denegado* = pulsar "Denegar" una vez; *denegado permanente* = denegar **dos veces seguidas** (o marcar "no preguntar de nuevo" si aparece la casilla).
- [ ] **Pantalla del teléfono visible** (`scrcpy` o cámara).
- [ ] Ensaya una vez sin grabar: con dos permisos y una demo de backend en vivo, es fácil pasarse de los 5 minutos si dudas en cámara.

---

## Bloque 0 — Presentación y selección (25 s)

> "Soy Andy Toala, Semana 14 de Aplicaciones Móviles, proyecto **Atlas**. Hasta la semana pasada la aplicación solo consumía mi backend; hoy le agrego dos capacidades del teléfono: **dictado por voz**, esencial porque Atlas se presenta desde la Semana 9 como una app que captura ideas por texto o por audio y hasta ahora solo hacía la mitad; y un **aviso local** cuando una idea queda publicada, opcional, para no tener que entrar a comprobarlo a mano. Elegí `permission_handler`, `speech_to_text`, `flutter_local_notifications` y `shared_preferences` con seis criterios de verificación que detallo en la sección 11.2 del README."

---

## Bloque 1 — Declaraciones de permisos (20 s)

**En pantalla, rápido:** `AndroidManifest.xml` y `Info.plist`.

> "En Android declaro `RECORD_AUDIO` y `POST_NOTIFICATIONS`, sin permisos de galería ni almacenamiento: no hacen falta. En iOS, las cadenas de propósito del micrófono y del reconocedor de voz explican el uso concreto; sin ellas iOS cierra la app al pedir el permiso, no muestra un error."

---

## Bloque 2 — Dictado por voz: permiso concedido (45 s)

Entra a *Nueva idea*, escribe el título, pulsa el ícono de micrófono.

> "Antes del diálogo del sistema, mi propia aplicación explica para qué se usa el micrófono: es la explicación previa que exige el taller."

Pulsa *Continuar*. Aparece el diálogo **nativo**. Concede el permiso y dicta una frase.

> "Concedo el permiso del sistema, y en cuanto hablo, el texto aparece en el campo."

Detén el dictado, guarda la idea, abre su detalle.

> "Guardo la idea, y en el detalle el origen aparece como 'audio': `POST /ideas` ya viaja con ese valor en vez de 'texto'."

---

## Bloque 3 — Dictado por voz: permiso denegado (15 s)

Nueva idea, pulsa el micrófono, y en el diálogo nativo pulsa *Denegar*.

> "Si deniego, la aplicación no se rompe: avisa que puedo escribir a mano, y el resto del formulario sigue funcionando normal."

Escribe el contenido a mano y guarda.

---

## Bloque 4 — Dictado por voz: denegación permanente y ajustes (40 s)

Pulsa el micrófono y deniega **una segunda vez**.

> "Deniego una segunda vez: a partir de aquí el sistema ya no vuelve a preguntar, es la denegación permanente."

Pulsa el micrófono otra vez.

> "Mi aplicación lo detecta y, en vez de insistir, ofrece el atajo directo a los ajustes del sistema."

Pulsa *Abrir ajustes*, concede el permiso desde ahí, vuelve a la app y pulsa el micrófono de nuevo.

> "Concedo desde ajustes, vuelvo, y ya dicta con normalidad otra vez."

---

## Bloque 5 — Notificaciones: activar y verlo llegar de verdad (60 s)

Ve a *Perfil*, activa el interruptor "Avisarme cuando una idea se publique".

> "Otra vez mi explicación antes del permiso nativo."

Pulsa *Continuar*, concede el permiso.

> "El interruptor se enciende; la preferencia queda en `shared_preferences`, no en el almacén cifrado del token, porque no es un dato sensible."

Ve a *Ideas*, señala una idea en estado "procesando".

> "Esta idea la está procesando mi backend de verdad. Sin un botón que lo acelere, simulo que termina cambiando su estado en la base de datos."

**Cambia a la terminal** (ajusta a tu propio `docker-compose.yml`):

```powershell
docker compose exec db psql -U <tu-usuario> -d <tu-base> -c "UPDATE ideas SET estado='publicada' WHERE id = <id-de-la-idea>;"
```

**Vuelve al teléfono**, refresca la lista.

> "Refresco: la aplicación compara el estado nuevo contra el último guardado, ve la transición a 'publicada', y…"

Muestra la notificación en la bandeja del sistema.

> "…ahí está. Es local, no push: no pasó por ningún servidor de mensajería."

---

## Bloque 6 — Notificaciones: denegación permanente (15 s)

> "El mismo mecanismo que con el micrófono: si deniego dos veces el permiso de notificaciones, la aplicación ofrece el atajo a ajustes en vez de insistir."

*(Solo la frase; no hace falta repetir la demostración completa en pantalla si el tiempo aprieta.)*

---

## Cierre (30 s)

> "En resumen: dos capacidades nativas, con sus cuatro estados de permiso manejados y degradación explícita en cada uno —incluida la denegación permanente con salida a ajustes—. Todo se integra con la persistencia local y con mi propio backend, sin permisos de acceso amplio y con el nivel de API objetivo ya en Android 16. El detalle completo, la matriz de degradación y las 34 pruebas automatizadas están en la sección 11 del README. Gracias."

---

## Después de grabar

- [ ] Subir el video a YouTube (**no listado**) o a Drive.
- [ ] **Verificar permisos**: ábrelo en incógnito y confirma que se ve sin iniciar sesión.
- [ ] Confirmar que el repositorio `atlas-app` es accesible para el docente.
- [ ] Comprobar que lo mostrado en el video **coincide con el código publicado** (push antes de entregar).
- [ ] Completar la columna "Verificado en el teléfono" de la tabla de casos de prueba (README §11.8).
- [ ] Subir a Moodle el enlace del video, el del repositorio, y el documento breve (README §11).

---

## Cobertura de la rúbrica

| Criterio | Puntaje | Bloques |
|---|---|---|
| 1. Selección y justificación | 1,0 | 0 |
| 2. Funcionamiento de las capacidades | 2,0 | 2 y 5 |
| 3. Solicitud en el momento correcto | 2,0 | 2, 4 y 5 |
| 4. Degradación elegante | 2,5 | 3, 4 y 6 |
| 5. Declaraciones de ambas plataformas | 1,5 | 1 |
| 6. Cumplimiento de la tienda | 0,5 | Cierre (detalle en README §11.7) |
| 7. Pruebas en dispositivo físico | 0,5 | Cierre (detalle en README §11.8) |
| **Total** | **10** | |

## Lo que el taller exige, y dónde se ve

| Requisito | Bloque |
|---|---|
| Dos capacidades funcionando con permiso concedido | 2 y 5 |
| Comportamiento ante la denegación | 3 y 6 |
| Denegación permanente con acceso a ajustes | 4 y 6 |
| Explicación previa a la solicitud | 2 y 5 |
| Declaraciones en Android e iOS | 1 |
| Degradación ante indisponibilidad del servicio (no solo del permiso) | README §11.5 (difícil de forzar en vivo sin un dispositivo sin Play Services; cubierto por `flutter test`) |
| Integración con persistencia local y backend | 5 y README §11.6 |
| Cumplimiento (permisos amplios, nivel de API) | Cierre y README §11.7 |
| Cinco casos de prueba en dispositivo físico | README §11.8 |
