# Guion del video — Taller Semana 9

**Configuración, verificación y conexión del entorno de desarrollo móvil**
Aplicaciones Móviles · 2626-UEA-L-UFPTI-008-C · Modalidad individual
Duración objetivo: **10 a 12 minutos**

---

## Antes de grabar (lista de comprobación)

Haz esto en orden. Si algo falla aquí, arréglalo antes de encender la grabación.

- [ ] **Backend levantado.** En `atlas-backend`: `docker compose up -d`. Verifica en el navegador que `http://localhost:8000/health` devuelva `{"status":"ok"...}`.
- [ ] **Datos cargados.** Si la base está vacía: `docker compose exec api python seed.py`.
- [ ] **Regla de firewall activa.** PowerShell **como administrador**: `powershell -ExecutionPolicy Bypass -File .\herramientas\abrir-firewall.ps1`.
- [ ] **Teléfono conectado por USB**, con depuración USB activada y en la **misma red Wi-Fi** que el computador. Comprueba con `adb devices` que aparezca como `device`.
- [ ] **Licencias aceptadas.** Ejecuta `flutter doctor --android-licenses` y responde `y` hasta el final. Luego `flutter doctor` debe decir `No issues found!`.
- [ ] **IP confirmada.** Anota la IP que muestra `run.ps1` al arrancar; es la que vas a mencionar en el video. El script sincroniza solo la política de seguridad de red, pero verifica que el mensaje diga la IP correcta.
- [ ] **Docker Desktop abierto.** No basta con que el contenedor exista: el motor de Docker tiene que estar corriendo. Si `docker ps` da error de conexión, abre Docker Desktop y espera a que arranque.
- [ ] **Pantalla limpia.** Cierra pestañas y ventanas que no uses. Sube el tamaño de letra de la terminal (Ctrl + rueda del ratón) para que se lea en el video.
- [ ] **Grabación del teléfono.** Puedes apuntar la cámara al teléfono o proyectar la pantalla con `scrcpy`. Lo importante es que se vea la aplicación funcionando en el dispositivo real.

---

## Bloque 1 — Presentación (1 min)

> "Buenas, soy Andy Toala, estudiante de Ingeniería en Tecnologías de la Información de la Universidad Estatal Amazónica. Este es el taller de la semana 9 de Aplicaciones Móviles: configuración, verificación y conexión del entorno de desarrollo móvil.
>
> El proyecto integrador se llama **Atlas**. Es una aplicación móvil que captura ideas por texto o por audio, las convierte en publicaciones listas para redes sociales usando un modelo de inteligencia artificial, y después mide cómo rindieron esas publicaciones.
>
> En la semana 4 diseñé la base de datos. En la semana 8 construí el backend con FastAPI, PostgreSQL, Redis y Celery, y le apliqué técnicas de optimización. Hoy toca cerrar el círculo: montar el entorno móvil y demostrar que la aplicación llega a esa API que yo mismo construí."

**En pantalla:** el repositorio `atlas-app` abierto en VS Code.

---

## Bloque 2 — Framework elegido y su justificación (1,5 min)

> "El framework multiplataforma que elegí es **Flutter**, con el lenguaje Dart. Lo justifico por cinco razones concretas.
>
> Primera: una sola base de código genera Android e iOS. Mi prioridad es Android, gama media, que es el mercado real en Ecuador, pero no quiero cerrar la puerta a iOS.
>
> Segunda: Dart compila **ahead of time** a código ARM nativo. No hay un puente de JavaScript interpretándose en tiempo de ejecución, como sí ocurre en otros enfoques multiplataforma.
>
> Tercera: Flutter trae su propio motor de renderizado, dibuja cada píxel. Eso hace que la interfaz se vea igual en cualquier dispositivo, sin depender de los componentes del sistema.
>
> Cuarta: la recarga en caliente. Aplico un cambio y lo veo en menos de un segundo, sin perder el estado de la aplicación. Eso lo voy a demostrar en vivo más adelante.
>
> Y quinta: Dart tiene **null safety** nativo, lo que convierte en errores de compilación una familia entera de fallos que en otros lenguajes aparecen recién en tiempo de ejecución."

---

## Bloque 3 — Versiones instaladas (1,5 min)

**Ejecuta:**

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas\verificar-entorno.ps1
```

Deja correr el script y ve narrando mientras aparece cada bloque. **Desplázate despacio** para que se lea todo.

> "Este script imprime todo el entorno de una sola vez.
>
> Sistema operativo: Windows 11, versión 25H2.
>
> Flutter 3.41.7 en el canal estable, con Dart 3.11.5.
>
> El JDK: Microsoft OpenJDK 17. Este es el que usa Gradle para compilar el módulo de Android.
>
> El Android SDK está en `C:\Android\Sdk`, con la plataforma android-36 y las build-tools 36.0.0. El adb es la versión 1.0.41.
>
> El editor es Visual Studio Code con las extensiones de Dart y Flutter."

---

## Bloque 4 — Diagnóstico sin hallazgos (1,5 min)

El script ya ejecutó `flutter doctor -v`. **Desplázate hacia arriba y recorre la salida completa**, no solo el resultado final. Esto lo pide el taller de forma expresa.

> "Aquí está la salida completa del diagnóstico de Flutter, no solamente el resumen.
>
> Flutter: correcto, con la ruta del SDK y la revisión.
>
> La cadena de herramientas de Android: correcta. Detecta el SDK en `C:\Android\Sdk`, la plataforma android-36, las build-tools 36.0.0, las variables `ANDROID_HOME` y `ANDROID_SDK_ROOT`, el binario de Java del JDK 17, y las licencias aceptadas.
>
> Chrome: correcto.
>
> Dispositivos conectados: ahí aparece mi teléfono físico.
>
> Recursos de red: correcto.
>
> Y al final: **No issues found**. Cero hallazgos pendientes.
>
> Aclaro una decisión: desactivé los objetivos de escritorio con `flutter config --no-enable-windows-desktop`. Mi proyecto apunta a Android e iOS, no a Windows. Si los dejo activos, el diagnóstico exige Visual Studio con la carga de trabajo de C++, que es una dependencia que este proyecto no necesita. Por eso el diagnóstico queda limpio para las plataformas que sí están previstas."

---

## Bloque 5 — Estructura del proyecto (1,5 min)

**En pantalla:** el árbol de archivos en VS Code. Abre cada archivo que menciones.

> "Recorro la estructura.
>
> En `lib` está el código Dart. `main.dart` es el punto de entrada y arma la navegación entre tres pantallas.
>
> `config/app_config.dart` es importante: aquí se lee la URL base de la API. Fíjense que **no está escrita fija**, se lee con `String.fromEnvironment`, es decir, viene de una variable de entorno que se inyecta al compilar.
>
> `api/atlas_api.dart` es el cliente HTTP: concentra la URL base, la cabecera de autorización con el token, los modelos de datos y la traducción de errores de red a mensajes entendibles.
>
> En `pantallas` están las tres vistas: conexión, sesión e ideas.
>
> En `android/app/src/main` está el manifiesto, donde declaro el permiso de internet y enlazo la política de seguridad de red, que está en `res/xml/network_security_config.xml`. A ese archivo vuelvo en un momento.
>
> En `herramientas` están los dos scripts: el de verificación del entorno y el del firewall.
>
> Y `run.ps1` es el lanzador: detecta la IP del computador y arranca la aplicación con la variable de entorno correcta."

---

## Bloque 6 — Direccionamiento hacia el backend (2 min)

Este bloque vale puntos en dos criterios: conectividad y fundamentación. **No lo apures.**

**En pantalla:** `lib/config/app_config.dart` y luego `network_security_config.xml`.

> "Ahora la parte central del taller: qué dirección usa la aplicación para alcanzar mi backend, y por qué.
>
> El backend corre en el puerto 8000 de este computador. Pero la dirección correcta **depende de dónde se ejecuta la aplicación**, porque `localhost` siempre significa 'esta misma máquina'.
>
> Si la aplicación corriera en el navegador de este computador, `localhost:8000` funcionaría, porque es la misma máquina.
>
> Si corriera en un emulador de Android, tendría que usar `10.0.2.2`, que es el alias que el emulador reserva para el `localhost` del computador anfitrión. Si pusiera `127.0.0.1`, apuntaría al propio dispositivo virtual y no encontraría nada.
>
> Pero yo estoy usando un **teléfono físico**. El teléfono es otra máquina en la red Wi-Fi. Entonces tiene que alcanzar a mi computador por su **IP en la red local**, que en este momento es `192.168.100.116`. Si pusiera `localhost`, el teléfono se buscaría a sí mismo.
>
> Por eso la URL no está quemada en el código. Se inyecta al compilar con `--dart-define`, que es el mecanismo de variables de entorno de Dart. El mismo código sirve para los tres destinos sin tocar una línea.

> **Di la IP que te mostró `run.ps1`, no la del guion.** El router la asigna por DHCP y cambia. Si no coincide, corrige la frase sobre la marcha.
>
> Faltan dos permisos más. El primero: desde Android 9, el sistema **bloquea el tráfico HTTP sin cifrar** por defecto. Mi backend de desarrollo va por `http`, no por `https`. Miren cómo lo resolví: en `network_security_config.xml` la regla general dice `cleartextTrafficPermitted` en **falso**, o sea, ningún dominio puede viajar sin cifrar. Y abajo hay una excepción **acotada** solo a los hosts de desarrollo: mi IP local, el alias del emulador y localhost.
>
> Lo importante es lo que **no** hice: no puse `usesCleartextTraffic` en verdadero a nivel de aplicación, porque eso habría abierto el tráfico sin cifrar hacia cualquier destino de internet. Y este bloque de excepción se elimina antes de cualquier distribución.
>
> El segundo permiso es el firewall de Windows. Como el teléfono es un equipo externo, Windows bloquea la conexión entrante al puerto 8000. Creé una regla acotada a la subred local y al perfil de red privada, con el script `abrir-firewall.ps1`."

**Muestra la regla:**

```powershell
Get-NetFirewallRule -DisplayName "Atlas backend (desarrollo) - puerto 8000" |
  Format-List DisplayName, Enabled, Direction, Action, Profile
```

---

## Bloque 7 — Ejecución sobre el dispositivo real (2 min)

**Ejecuta:**

```powershell
flutter devices
.\run.ps1
```

> "Primero confirmo que Flutter ve mi teléfono. Ahí está, listado como dispositivo.
>
> Ahora lanzo la aplicación con `run.ps1`. El script hace dos cosas: detecta la IP del computador y la inyecta como variable de entorno, y además sincroniza la política de seguridad de red con esa misma IP. Vean en la salida: `API_BASE_URL` igual a `http://192.168.100.116:8000`.
>
> Está compilando e instalando el APK directamente en el teléfono."

**Cuando arranque, muestra el teléfono.**

> "La aplicación ya está corriendo en el dispositivo real. La primera pantalla es la de diagnóstico: muestra la URL base que recibió, el entorno y el tiempo máximo de espera. Y advierte que el tráfico sin cifrar está autorizado únicamente para el host de desarrollo."

### Recarga en caliente

Con la app corriendo, edita `lib/pantallas/pantalla_conexion.dart` y cambia el texto del título de la tarjeta (por ejemplo, agrega " — Semana 9"). Guarda y presiona `r` en la terminal.

> "Voy a demostrar la recarga en caliente. Cambio este texto, guardo, y presiono `r` en la terminal.
>
> Ahí está: menos de un segundo, y sin perder el estado de la aplicación. No se reinició, solo se actualizó."

---

## Bloque 8 — Solicitud exitosa a la API propia (2 min)

Este es el criterio de mayor peso junto con la instalación. **Muestra el teléfono en primer plano.**

**Paso 1 — Endpoint público**

> "Pulso 'Probar conexión con la API'. Esto hace un `GET` a `/health`, que es el endpoint público de mi backend.
>
> Respondió: `status ok`, `servicio atlas-backend`. Código HTTP 200.
>
> Y fíjense en las etiquetas de abajo: el tiempo medido en el cliente y el tiempo real de procesamiento en el servidor, que viene en la cabecera `X-Process-Time-ms`. Ese dato lo genera mi backend, no la aplicación. Eso prueba que la respuesta es real."

**Paso 2 — Autenticación**

> "Ahora voy a la pestaña de sesión e inicio sesión con el usuario de demostración. Esto hace un `POST` a `/auth/login`.
>
> Devolvió un token JWT, y con ese token consulté `/auth/me`. Vean la etiqueta: **cero consultas SQL**. Eso es porque el backend toma la identidad de los claims del token, sin ir a la base de datos. Es una de las optimizaciones que implementé en la semana 8, y desde aquí se comprueba."

**Paso 3 — Datos reales**

> "En la pestaña de ideas pulso 'Cargar ideas'. Esto hace un `GET` a `/ideas` con el token en la cabecera de autorización.
>
> Ahí están las ideas del usuario, traídas de PostgreSQL. Título, estado, origen, etiquetas y número de publicaciones.
>
> Y este interruptor de 'consulta optimizada' cambia el parámetro `optimized` de la API. Con optimización activada: **tres consultas SQL**. Lo apago, recargo: **muchas más consultas**, porque ahí aparece el problema N+1. Es la misma optimización de la semana 8, ahora medida desde el teléfono."

**Paso 4 — Escritura**

> "Y para cerrar el flujo completo, creo una idea desde el teléfono con el botón de más. Esto hace un `POST` a `/ideas`.
>
> Devolvió el identificador que asignó la base de datos. Recargo la lista y ahí aparece. El dato viajó del teléfono al backend y de ahí a PostgreSQL."

---

## Bloque 9 — Limitaciones y dificultades (1,5 min)

El taller pide esto de forma explícita. **Sé honesto: da puntos, no los quita.**

> "Termino con las limitaciones del entorno y las dificultades que encontré.
>
> **Limitaciones:**
>
> Primera: no puedo compilar para iOS. Xcode solo existe en macOS. El código de iOS está generado y versionado, pero esa compilación queda fuera de mi alcance con el hardware que tengo.
>
> Segunda: no configuré emulador. Fue una decisión, no un descuido. Este equipo tiene 13,7 GB de RAM, y durante la demostración tienen que convivir el backend completo en Docker —API, PostgreSQL, Redis y el worker de Celery—, más VS Code y la compilación de Gradle. Sumar un dispositivo virtual deja el sistema al límite. Además, el dispositivo físico da una medición honesta: red real y latencia real. El taller permite expresamente esta ruta declarándola como decisión justificada.
>
> Tercera: la IP local la asigna el router por DHCP y puede cambiar. Por eso el script la detecta en cada ejecución.
>
> Cuarta: el teléfono y el computador tienen que estar en la misma red Wi-Fi. En redes con aislamiento de clientes, típico de redes públicas, no funcionaría aunque el firewall esté abierto.
>
> Quinta: el tráfico va sin cifrar. Es aceptable solo en desarrollo y está acotado. Un despliegue real exige HTTPS.
>
> **Dificultades que encontré:**
>
> La principal fue el direccionamiento. Mi primer intento fue `localhost:8000` y no conectaba. El error tenía sentido una vez que entendí que `localhost`, dentro del teléfono, significa el propio teléfono. Ahí quedó claro por qué hay que usar la IP de la red local.
>
> La segunda fue el firewall. Aunque la IP era correcta, Windows bloqueaba la conexión entrante al puerto 8000. Se resolvió con una regla acotada a la subred local, no abriendo el puerto a cualquier origen.
>
> Ligada a esa, apareció otra: el router cambió la IP del computador entre una sesión de trabajo y la siguiente. La URL base se corregía sola, pero la política de seguridad de red seguía autorizando la dirección vieja, así que Android bloqueaba la conexión sin dar una pista clara. Por eso automaticé la sincronización: el lanzador actualiza el XML con la IP actual antes de compilar, y la excepción sigue acotada a un solo host.
>
> Y la tercera fue el bloqueo de tráfico sin cifrar de Android. La salida fácil era activar `usesCleartextTraffic` a nivel de aplicación, pero eso abre el tráfico sin cifrar hacia todo internet. Preferí la política de seguridad de red con excepción acotada, que es la práctica correcta."

---

## Cierre (30 s)

> "En resumen: entorno instalado y verificado con diagnóstico limpio, proyecto base ejecutándose sobre un dispositivo físico real con recarga en caliente funcionando, y solicitudes exitosas contra mi propio backend, incluyendo autenticación y escritura en la base de datos.
>
> El repositorio con todo el código y el documento de configuración del entorno queda en el enlace que adjunto en Moodle. Gracias."

---

## Después de grabar

- [ ] Subir el video a YouTube (**no listado**) o a Google Drive.
- [ ] **Verificar los permisos**: abre el enlace en una ventana de incógnito para confirmar que se ve sin iniciar sesión.
- [ ] Subir a Moodle el enlace del video **y** el enlace del repositorio `atlas-app`.
- [ ] Confirmar que el repositorio es público y que el `README.md` se ve bien en GitHub.

---

## Cobertura de la rúbrica

| Criterio | Puntaje | Bloque del guion |
|---|---|---|
| Instalación y verificación del entorno | 2,5 | 3 y 4 |
| Ejecución del proyecto | 2,0 | 7 |
| Conectividad con el backend propio | 2,0 | 6 y 8 |
| Fundamentación técnica | 1,5 | 2, 6 y 9 |
| Explicación en el video | 1,0 | todo el guion |
| Documentación del entorno | 0,5 | README, sección 1 |
| Relación con el proyecto | 0,5 | 1 y 8 |
| **Total** | **10** | |
