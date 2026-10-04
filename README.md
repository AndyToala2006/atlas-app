# Atlas — aplicación móvil multiplataforma

Cliente móvil del proyecto integrador **Atlas**, desarrollado con Flutter y conectado al backend propio [`atlas-backend`](https://github.com/AndyToala2006/atlas-backend) (FastAPI + PostgreSQL + Redis + Celery).

| | |
|---|---|
| **Asignatura** | Aplicaciones Móviles (UEA-L-UFPTI-008) |
| **Código de aula** | 2626-UEA-L-UFPTI-008-C |
| **Entrega vigente** | Semana 15 — Publicaciones con IA real (OpenRouter) y pirámide de pruebas (§12) |
| **Taller anterior** | Semana 14 — Funcionalidades nativas: dictado por voz y notificaciones locales (§11) |
| **Talleres previos** | Semana 13 — CRUD completo de ideas (§6, §7.3) · Semana 12 — Autenticación, navegación, estado y formularios (§7) · Semana 9 — Configuración, verificación y conexión del entorno (§1–§6) |
| **Modalidad** | Individual |
| **Autor** | Andy Toala |

---

## 1. Documento de configuración del entorno

Esta sección registra versiones, rutas y comandos exactos para que **un tercero pueda reproducir el entorno desde cero** en Windows.

### 1.1 Versiones verificadas

Todas las versiones fueron obtenidas ejecutando los comandos de la columna derecha en este mismo equipo.

| Componente | Versión instalada | Comando de verificación |
|---|---|---|
| Sistema operativo | Windows 11 Home 25H2 (build 26200) | `winver` |
| Flutter SDK | 3.41.7 · canal `stable` | `flutter --version` |
| Dart SDK | 3.11.5 | `dart --version` |
| DevTools | 2.54.2 | `flutter --version` |
| JDK | Microsoft OpenJDK 17.0.20 LTS | `java -version` |
| Android SDK Platform | android-36 | `sdkmanager --list_installed` |
| Android SDK Build-Tools | 36.0.0 y 35.0.0 | `sdkmanager --list_installed` |
| Android SDK Platform-Tools | 37.0.1 (adb 1.0.41) | `adb version` |
| Android NDK | 28.2.13676358 | `sdkmanager --list_installed` |
| CMake | 3.22.1 | `sdkmanager --list_installed` |
| Android CLI / cmdline-tools | 15859902 (`latest`) | `sdkmanager --version` |
| Editor | Visual Studio Code + extensiones Dart y Flutter | `code --version` |
| Paquete `http` | 1.5.0 | `flutter pub deps` |

**Rutas de instalación:**

| Variable | Valor |
|---|---|
| Flutter SDK | `C:\src\flutter` |
| `JAVA_HOME` | `C:\dev\jdk-17` |
| `ANDROID_HOME` / `ANDROID_SDK_ROOT` | `C:\Android\Sdk` |

**Hardware del equipo de desarrollo:** AMD Ryzen 7 6800H (8 núcleos / 16 hilos), 13,7 GB de RAM, 222 GB libres en disco.

### 1.2 Instalación reproducible paso a paso

Todos los comandos se ejecutan en **PowerShell**.

**Paso 1 — Flutter SDK**

```powershell
# Descargar y descomprimir el SDK estable en C:\src\flutter
# https://docs.flutter.dev/get-started/install/windows
flutter --version
```

**Paso 2 — JDK 17** (lo necesita Gradle para compilar el módulo Android)

```powershell
Invoke-WebRequest -Uri "https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip" `
                  -OutFile "$env:TEMP\jdk17.zip"
Expand-Archive "$env:TEMP\jdk17.zip" -DestinationPath "C:\dev\jdk-tmp"
Move-Item (Get-ChildItem "C:\dev\jdk-tmp" -Directory)[0].FullName "C:\dev\jdk-17"
[Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\dev\jdk-17", "User")
```

**Paso 3 — Android SDK (command-line tools)**

No se instala Android Studio completo: el proyecto se ejecuta sobre un dispositivo físico, por lo que basta la cadena de herramientas de línea de comandos (ver justificación en §2.2).

```powershell
# El número de compilación cambia; la URL vigente está en https://developer.android.com/studio
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip" `
                  -OutFile "$env:TEMP\cmdline-tools.zip"
Expand-Archive "$env:TEMP\cmdline-tools.zip" -DestinationPath "$env:TEMP\cmdt"
New-Item -ItemType Directory -Force "C:\Android\Sdk\cmdline-tools" | Out-Null
Move-Item "$env:TEMP\cmdt\cmdline-tools" "C:\Android\Sdk\cmdline-tools\latest"

[Environment]::SetEnvironmentVariable("ANDROID_HOME",     "C:\Android\Sdk", "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", "C:\Android\Sdk", "User")
```

Agregar al `Path` del usuario:

```
C:\dev\jdk-17\bin
C:\Android\Sdk\platform-tools
C:\Android\Sdk\cmdline-tools\latest\bin
```

**Paso 4 — Componentes del SDK**

```powershell
android sdk install "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

> La primera compilación de Gradle descarga por su cuenta los componentes que le faltan —NDK 28.2.13676358, CMake 3.22.1 y build-tools 35.0.0— y los deja en `C:\Android\Sdk`. Esa primera compilación tarda alrededor de 9 minutos; las siguientes son incrementales.

**Paso 5 — Enlazar Flutter con el SDK y el JDK**

```powershell
flutter config --android-sdk "C:\Android\Sdk"
flutter config --jdk-dir     "C:\dev\jdk-17"

# El proyecto solo apunta a Android e iOS: se desactivan los objetivos de
# escritorio para que el diagnóstico no reporte dependencias irrelevantes
# (Visual Studio con carga de trabajo C++).
flutter config --no-enable-windows-desktop --no-enable-linux-desktop --no-enable-macos-desktop
```

**Paso 6 — Aceptar las licencias del SDK**

```powershell
flutter doctor --android-licenses   # responder "y" a cada licencia
```

**Paso 7 — Verificar que el diagnóstico quede sin hallazgos**

```powershell
flutter doctor -v
```

Salida esperada: todas las categorías en `[√]` y el mensaje `No issues found!`.

**Paso 8 — Extensiones del editor**

```powershell
code --install-extension Dart-Code.dart-code
code --install-extension Dart-Code.flutter
```

El archivo [`.vscode/extensions.json`](.vscode/extensions.json) las declara como recomendadas del proyecto.

### 1.3 Compilación de verificación

Para comprobar que toda la cadena (Flutter → Gradle → JDK → Android SDK) funciona sin necesidad de tener el teléfono conectado:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.100.116:8000
```

Resultado esperado: `√ Built build\app\outputs\flutter-apk\app-debug.apk` (≈138 MB en modo depuración, porque incluye las tres arquitecturas y los símbolos).

### 1.4 Comando único de verificación

El repositorio incluye un script que imprime en una sola corrida el sistema operativo, todas las versiones, el diagnóstico completo, los dispositivos conectados, las IP de la red local y el estado del backend:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas\verificar-entorno.ps1
```

---

## 2. Fundamentación técnica

### 2.1 Elección del framework multiplataforma: Flutter

| Criterio | Justificación |
|---|---|
| **Base de código única** | Una sola base en Dart genera binarios para Android e iOS. El proyecto prioriza Android (gama media, mercado ecuatoriano) sin cerrar la puerta a iOS. |
| **Rendimiento** | Dart compila AOT a código ARM nativo. No hay puente JavaScript en tiempo de ejecución, a diferencia de los frameworks basados en WebView o en un bridge interpretado. |
| **Renderizado propio** | Flutter dibuja cada píxel con su propio motor gráfico, lo que garantiza que la interfaz se vea idéntica en todos los dispositivos y elimina discrepancias entre versiones de Android. |
| **Productividad** | La recarga en caliente (*hot reload*) aplica cambios en menos de un segundo conservando el estado de la aplicación, lo que acorta drásticamente el ciclo de desarrollo. |
| **Seguridad de tipos** | Dart tiene *null safety* de forma nativa, lo que traslada a tiempo de compilación una clase entera de errores en tiempo de ejecución. |
| **Continuidad del proyecto** | El framework ya fue seleccionado y justificado en los avances de las semanas 1 a 3, y la base de datos (semana 4) y el backend (semana 8) se diseñaron alrededor de esta decisión. |

### 2.2 Elección del destino de ejecución: dispositivo físico

Se ejecuta sobre un **teléfono Android físico conectado por USB**, no sobre un emulador. La decisión es deliberada y responde a los recursos disponibles:

- El equipo dispone de **13,7 GB de RAM**. Durante la demostración deben coexistir el backend completo en Docker (API + PostgreSQL + Redis + worker Celery), Visual Studio Code y el proceso de compilación de Gradle. Sumar un dispositivo virtual acelerado por hardware deja el sistema al límite y compromete la fluidez de la grabación.
- Instalar Android Studio con las imágenes del sistema añade cerca de **8 GB en disco** y no aporta nada al objetivo del taller: la cadena de herramientas de línea de comandos es suficiente para compilar, instalar y depurar.
- Un dispositivo real ofrece una **medición honesta**: rendimiento real de gama media, red Wi-Fi real y latencia real hacia el backend. El emulador comparte la pila de red del anfitrión y oculta precisamente los problemas de conectividad que este taller busca resolver.

Esta ruta está expresamente contemplada en las recomendaciones del taller, que permiten trabajar sobre dispositivo físico declarándolo como decisión justificada.

**Preparación del dispositivo:**

```powershell
# En el teléfono: Ajustes > Información > pulsar 7 veces "Número de compilación"
# Luego: Opciones de desarrollador > activar "Depuración por USB"
adb devices          # debe listar el dispositivo como "device", no "unauthorized"
flutter devices
```

### 2.3 Elección del direccionamiento hacia el backend

El backend de Atlas se sirve en el puerto **8000** del computador de desarrollo. La dirección que la aplicación debe usar **depende del destino de ejecución**, porque `localhost` siempre se resuelve dentro del propio dispositivo que ejecuta el código:

| Destino | Dirección correcta | Motivo |
|---|---|---|
| **Dispositivo físico** | `http://192.168.100.116:8000` | El teléfono es otra máquina en la red Wi-Fi. Debe alcanzar al computador por su **IP en la LAN**. `localhost` apuntaría al propio teléfono. |
| Emulador de Android | `http://10.0.2.2:8000` | El emulador aísla su red; `10.0.2.2` es el alias que reserva para el `localhost` del anfitrión. `127.0.0.1` apuntaría al dispositivo virtual. |
| Navegador / escritorio | `http://localhost:8000` | La aplicación corre en el mismo equipo que el backend. |

La IP local se consulta con:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.InterfaceAlias -notlike '*WSL*' } |
  Select-Object IPAddress, InterfaceAlias
```

> La IP asignada por DHCP puede cambiar al reconectarse a la red. Eso afecta a **dos** lugares: la URL base y la política de seguridad de red (§4). `run.ps1` resuelve ambos: detecta la IP, la inyecta como variable de entorno y sincroniza `network_security_config.xml` llamando a `herramientas/configurar-host.ps1`. Si la política conserva una IP vieja, Android bloquea la conexión aunque la URL base sea correcta.

---

## 3. Configuración de la URL base por variables de entorno

La URL de la API **no está escrita fija en el código**. Se inyecta en tiempo de compilación con `--dart-define`, que es el mecanismo de variables de entorno de Dart, y se lee en [`lib/config/app_config.dart`](lib/config/app_config.dart):

```dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);
```

Así, el mismo código apunta al backend local, al emulador o a un servidor remoto sin modificar una sola línea:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.100.116:8000 --dart-define=APP_ENV=dispositivo
```

El repositorio incluye tres formas equivalentes de lanzarlo:

| Forma | Comando |
|---|---|
| Script (detecta la IP sola) | `.\run.ps1` |
| Script con destino explícito | `.\run.ps1 -Destino emulador` |
| VS Code | `F5` y elegir la configuración en [`.vscode/launch.json`](.vscode/launch.json) |

---

## 4. Autorización acotada del tráfico sin cifrar

Desde Android 9 (API 28) el sistema **bloquea el tráfico HTTP sin cifrar** de forma predeterminada. El backend de desarrollo se sirve por `http` en la red local, de modo que se declara una excepción **limitada a los hosts de desarrollo** en [`android/app/src/main/res/xml/network_security_config.xml`](android/app/src/main/res/xml/network_security_config.xml):

```xml
<network-security-config>
    <!-- Regla general: ningún dominio puede viajar sin cifrar. -->
    <base-config cleartextTrafficPermitted="false" />

    <!-- Excepción única para el entorno de desarrollo. -->
    <domain-config cleartextTrafficPermitted="true">
        <!-- HOST-DESARROLLO:INICIO -->
        <domain includeSubdomains="false">192.168.100.116</domain>
        <!-- HOST-DESARROLLO:FIN -->
        <domain includeSubdomains="false">10.0.2.2</domain>
        <domain includeSubdomains="false">localhost</domain>
        <domain includeSubdomains="false">127.0.0.1</domain>
    </domain-config>
</network-security-config>
```

Lo importante es lo que **no** se hizo: no se activó `android:usesCleartextTraffic="true"` a nivel de aplicación, que habría abierto el tráfico sin cifrar hacia cualquier destino de internet. Tampoco se autorizó un rango completo de la red: la excepción cubre **una sola dirección**. La `base-config` mantiene la exigencia de HTTPS para todo lo demás.

Las marcas `HOST-DESARROLLO` delimitan la única línea que cambia cuando el router asigna otra IP. La actualiza el script:

```powershell
.\herramientas\configurar-host.ps1              # detecta la IP actual
.\herramientas\configurar-host.ps1 -Ip 10.0.0.5 # o se fuerza una concreta
```

`run.ps1` lo invoca solo antes de cada ejecución sobre dispositivo físico, de modo que la excepción sigue acotada a un host sin tener que editar el XML a mano. Al ser un recurso de Android, el cambio exige recompilar: la recarga en caliente no lo aplica.

> **Antes de cualquier distribución (release / Play Store) el bloque `<domain-config>` debe eliminarse** y el backend debe servirse por HTTPS.

El manifiesto declara además el permiso necesario y enlaza la política:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<application android:networkSecurityConfig="@xml/network_security_config" ...>
```

### Firewall de Windows

El teléfono es un equipo externo, así que Windows bloquea por defecto la conexión entrante al puerto 8000. La regla se crea acotada a la subred local y al perfil de red privada:

```powershell
# Requiere PowerShell como administrador
powershell -ExecutionPolicy Bypass -File .\herramientas\abrir-firewall.ps1

# Para revertirla al terminar:
powershell -ExecutionPolicy Bypass -File .\herramientas\abrir-firewall.ps1 -Quitar
```

---

## 5. Ejecución de la aplicación

### 5.1 Levantar el backend

El backend es un repositorio independiente. Si aún no lo tienes:

```powershell
git clone https://github.com/AndyToala2006/atlas-backend.git
```

Desde la carpeta del backend, en su propia terminal:

```powershell
docker compose up -d
curl http://localhost:8000/health      # {"status":"ok","servicio":"atlas-backend"}
```

> Requiere Docker Desktop en ejecución. Si `docker ps` responde con un error de
> conexión al *daemon*, abre Docker Desktop y espera a que termine de arrancar.
> Sin un archivo `.env`, la API usa el PostgreSQL del propio `docker-compose.yml`,
> que es lo preferible para esta demostración: una dependencia externa menos.

Para cargar datos de prueba:

```powershell
docker compose exec api python seed.py
```

### 5.2 Lanzar la aplicación

Desde la carpeta de **este** repositorio, en una segunda terminal:

```powershell
flutter devices        # confirmar que el teléfono aparece listado
.\run.ps1              # detecta la IP, sincroniza la política de red y arranca
```

### 5.3 Recarga en caliente

Con la aplicación corriendo, en la terminal de `flutter run`:

| Tecla | Acción |
|---|---|
| `r` | *Hot reload* — aplica los cambios conservando el estado actual |
| `R` | *Hot restart* — reinicia la aplicación desde cero |
| `q` | Salir |

---

## 6. Consumo de la API propia

La aplicación consume el backend construido en la unidad anterior. Estas son las llamadas que realiza:

| Pantalla | Endpoint | Qué demuestra |
|---|---|---|
| **Diagnóstico** | `GET /health` | Primera solicitud exitosa. Endpoint público, sin autenticación. |
| **Login** | `POST /auth/login` → `GET /auth/me` | Autenticación con JWT. El token se guarda y viaja en `Authorization: Bearer`. |
| **Registro** | `POST /auth/register` → `GET /auth/me` | Alta de cuenta con sesión iniciada de inmediato. |
| **Ideas** | `GET /ideas` | Listado del usuario autenticado. Respuesta *ligera*: el backend no devuelve aquí el campo `contenido`. |
| **Nueva idea** | `POST /ideas` | Escritura de datos reales en PostgreSQL: la idea creada vuelve ya con su `id` y su detalle. Desde la Semana 14, `origen` viaja como `'audio'` cuando el contenido se dictó por voz (§11). |
| **Detalle de idea** | `GET /ideas/{id}` | Relectura puntual de un registro, también protegida por token. Es la única llamada que trae el `contenido`, y por eso el detalle lo pide al abrirse si aún no lo tiene. |
| **Editar idea** | `PATCH /ideas/{id}` | Actualización parcial: el cuerpo lleva solo los campos que cambiaron. Se lanza desde el mismo formulario de creación en modo edición, al que se llega con el botón *Editar* del detalle. |
| **Detalle de idea** | `DELETE /ideas/{id}` | Borrado real de la fila, previa confirmación en un diálogo. El backend responde `204` sin cuerpo y la idea desaparece del listado sin recargarlo. |
| **Panel** | `GET /dashboard/metricas` | Reporte agregado servido con caché-aside en Redis. |

Con `PATCH` y `DELETE` el ciclo de vida completo de una idea —crear, consultar, editar y eliminar— se ejecuta desde el teléfono contra la API real, sin Postman ni consultas manuales a la base. Las cuatro rutas van firmadas con el token: una idea de otro usuario responde `404`, así que la aplicación nunca puede leer ni modificar datos ajenos.

Cada respuesta se muestra en pantalla junto con los **datos de diagnóstico** que el backend devuelve en cabeceras, lo que evidencia que la información proviene realmente de la API y no de datos simulados en el cliente:

- `X-Process-Time-ms` — tiempo real de procesamiento en el servidor
- `X-Query-Count` — número de consultas SQL ejecutadas
- `X-Cache` — acierto o fallo de la caché en Redis

El interruptor *"consulta optimizada"* de la pantalla de ideas alterna el parámetro `optimized` de `GET /ideas`, que en el backend cambia entre *eager loading* y la versión ingenua con N+1. La diferencia se ve directamente en el teléfono a través de `X-Query-Count`.

**Cuenta de demostración.** El backend la crea con `seed.py`. Sus credenciales **no se versionan aquí**: se inyectan al lanzar, igual que la URL base, y solo entonces aparece en el login el botón que rellena el formulario.

```powershell
.\run.ps1 -DemoEmail demo@atlas.app -DemoPassword <la-del-seed>
```

Sin esos valores el botón no se muestra y el formulario se llena a mano, que es el comportamiento normal de la aplicación.

---

## 7. Autenticación, navegación y manejo de estado

*(Taller Semana 12)*

### 7.1 Flujo de autenticación

La aplicación **arranca comprobando si hay una sesión guardada**, y solo entra al contenido cuando la hay. El recorrido es:

```
/ (arranque) ──lee el token del almacén cifrado──> ¿válido? ──sí──> /inicio
   │                                                   │
   │                                                   no
   ▼                                                   ▼
/login ──POST /auth/login──> JWT ──GET /auth/me──> /inicio (área privada)
   │                                                   │
   └──> /registro ──POST /auth/register──> JWT ─────────┘
   └──> /diagnostico (público, GET /health)
```

El backend firma un JWT que lleva la identidad del usuario en los *claims*, de modo que `GET /auth/me` la resuelve **sin consultar la base de datos**. La aplicación guarda ese token en `AtlasApi.token` y lo adjunta como `Authorization: Bearer` en cada petición protegida.

El **registro está habilitado** porque el backend expone `POST /auth/register`. Crea la cuenta, su perfil de tono y devuelve el token, así que el usuario entra directamente sin pasar por el login.

### 7.2 Formularios y validaciones

Las reglas viven en [`lib/utiles/validadores.dart`](lib/utiles/validadores.dart), fuera de las pantallas: se reutilizan entre formularios y se pueden probar sin levantar la interfaz. Cada una devuelve `null` si el valor es aceptable y el mensaje de error si no lo es, que es el contrato de `TextFormField.validator`.

| Campo | Reglas | Dónde |
|---|---|---|
| Correo | Obligatorio · formato `nombre@dominio.ext` · máx. 160 | Login, Registro |
| Contraseña | Obligatoria · 6–72 caracteres | Login |
| Contraseña nueva | Lo anterior · al menos una letra y un número | Registro |
| Confirmación | Obligatoria · debe coincidir | Registro |
| Nombre | Obligatorio · 2–120 caracteres | Registro |
| Título | Obligatorio · 2–160 caracteres | Nueva idea |
| Contenido | Obligatorio · mínimo 10 caracteres | Nueva idea |
| Etiquetas | Opcionales · separadas por coma · máx. 5 · 40 caracteres cada una | Nueva idea |

Los límites replican los del esquema del servidor (`app/schemas.py`) para que el teléfono rechace lo mismo que rechazaría el backend, sin gastar una llamada de red. Hasta el primer envío no se marca nada en rojo (`AutovalidateMode.disabled`); a partir de ahí cada pulsación revalida, así el error desaparece en cuanto se corrige.

Los errores que **no pertenecen a un campo** —credenciales incorrectas, correo ya registrado, backend inalcanzable— se muestran en un aviso sobre el formulario. `ErrorApi` conserva el código de estado HTTP y el controlador de sesión lo traduce: 401 → *"Correo o contraseña incorrectos"*, 409 → *"Ese correo ya tiene una cuenta"*, 422 → los mensajes de validación de Pydantic.

### 7.3 Navegación

Navegación por **rutas con nombre**, todas declaradas en [`lib/rutas/rutas.dart`](lib/rutas/rutas.dart) y resueltas por un único `onGenerateRoute`:

| Ruta | Pantalla | Acceso |
|---|---|---|
| `/login` | Inicio de sesión | Pública (ruta inicial) |
| `/registro` | Crear cuenta | Pública |
| `/diagnostico` | Prueba de conectividad | Pública |
| `/inicio` | Contenedor con Ideas · Panel · Perfil | **Protegida** |
| `/ideas/nueva` | Formulario de nueva idea | **Protegida** |
| `/ideas/detalle` | Detalle de una idea (recibe la idea como argumento) | **Protegida** |
| `/ideas/editar` | El mismo formulario en modo edición (recibe la idea como argumento) | **Protegida** |

`/ideas/editar` reutiliza la pantalla de creación en lugar de duplicarla: si el argumento no es una `Idea` la tabla devuelve la ruta inválida, igual que hace `/ideas/detalle`. Al cerrarse devuelve la idea actualizada con `Navigator.pop`, de modo que el detalle se refresca sin volver a pedirla al backend.

Dentro de `/inicio`, un `NavigationBar` alterna entre las tres secciones sobre un `IndexedStack`, de modo que cambiar de pestaña no destruye la pantalla. Al autenticarse se usa `pushNamedAndRemoveUntil`, así que desde el área privada el botón *atrás* del sistema no devuelve al formulario de login.

### 7.4 Protección de vistas

Cada ruta privada se construye envuelta en [`GuardiaSesion`](lib/rutas/guardia_sesion.dart). No es una comprobación de una sola vez al abrir la pantalla: el widget **escucha** al controlador de sesión, de modo que si la sesión termina —por cierre voluntario o porque la API devolvió 401— la pantalla protegida se reemplaza en el acto por el aviso de acceso restringido, sin dejar datos a la vista.

Como la guardia está en la tabla de rutas y no en cada pantalla, no hay forma de esquivarla: da igual que la navegación venga de un botón, de un `pushNamed` suelto o de un error. El login incluye a propósito el enlace *"Intentar entrar sin iniciar sesión"* para poder comprobarlo en la demostración.

La protección es doble: aunque alguien alcanzara la pantalla, la API rechazaría la petición con 401 porque la cabecera `Authorization` viajaría vacía.

### 7.5 Manejo de estado

El estado se resuelve con las herramientas del propio Flutter, **sin paquetes de terceros**: `ChangeNotifier` para guardar y notificar, `InheritedWidget` para repartir y `ListenableBuilder` para redibujar solo lo que depende del dato. La aplicación tiene tres piezas de estado bien delimitadas y una dependencia externa no aportaría nada que este esquema no cubra.

```
AtlasApp                crea el cliente HTTP y los tres controladores
  AmbitoAtlas           los reparte a toda la aplicación (InheritedWidget)
    MaterialApp         navegación por rutas con nombre
      GuardiaSesion     envuelve cada ruta privada
```

| Controlador | Qué guarda |
|---|---|
| [`ControladorSesion`](lib/estado/controlador_sesion.dart) | Estado de la sesión, usuario autenticado, token y último error |
| [`ControladorIdeas`](lib/estado/controlador_ideas.dart) | Lista de ideas, cabeceras de la última respuesta y el borrador sin guardar |
| [`ControladorPanel`](lib/estado/controlador_panel.dart) | Último reporte de métricas recibido |

Lo decisivo es **dónde** viven: por encima del `Navigator`. Las pantallas se crean y se destruyen al navegar; los controladores no. Eso es lo que hace que, al cambiar de pestaña o volver del detalle de una idea:

- el nombre del usuario siga en la barra superior sin volver a pedir `GET /auth/me`;
- la lista de ideas ya esté cargada sin repetir `GET /ideas`;
- el **borrador a medio escribir** de una idea nueva siga intacto —se copia al controlador en cada pulsación, precisamente para poder demostrarlo.

### 7.6 Persistencia de la sesión

El JWT se guarda en el **almacén cifrado del sistema operativo** con [`AlmacenSesion`](lib/servicios/almacen_sesion.dart): `EncryptedSharedPreferences` respaldado por el **Keystore** en Android, y el **Keychain** en iOS. Nunca se escribe en almacenamiento en claro; un token en `SharedPreferences` sin cifrar es legible por cualquiera con acceso al sistema de archivos en un dispositivo con root.

Al arrancar, la aplicación lee ese token y lo valida contra `GET /auth/me`. Si sigue vigente, entra directa al área privada; si el backend lo rechaza, se borra en silencio y el usuario aparece en el login, como si nunca hubiera estado. Mientras dura esa comprobación se ve la pantalla de arranque, que evita el parpadeo de mostrar el login un instante y saltar enseguida al contenido.

`AlmacenSesion` es una interfaz, no una clase concreta. La implementación real usa `flutter_secure_storage`; las pruebas inyectan una en memoria, así que el flujo de persistencia se verifica sin depender del canal nativo del plugin.

### 7.7 Cierre de sesión

Desde *Perfil*, con confirmación previa. En orden: se desmonta el área privada con `pushNamedAndRemoveUntil('/login')`, se limpian los controladores de ideas y de panel, y se borra el token del cliente HTTP **y del almacén cifrado**. Ese orden evita que una pantalla protegida llegue a redibujarse sin sesión.

Limpiar los datos no es un detalle estético: impide que las ideas de un usuario queden visibles para el siguiente que inicie sesión en el mismo teléfono. El mismo camino se recorre automáticamente cuando la API responde 401 a una pantalla protegida, es decir, cuando el token expira.

### 7.8 Interfaz

El aspecto de la aplicación no se decide pantalla por pantalla. [`lib/tema/tema_atlas.dart`](lib/tema/tema_atlas.dart) concentra la paleta, la tipografía, los radios y el estilo de cada componente —campos, botones, tarjetas, barra de navegación, diálogos—, y las pantallas solo piden esos valores al tema. Un cambio de identidad visual se hace en ese archivo y no en veinte.

Hay **tema claro y tema oscuro**, ambos derivados de la misma semilla de marca, y la aplicación sigue la preferencia del sistema (`ThemeMode.system`).

Tres decisiones que sostienen el resto:

- **Estados explícitos.** Cada pantalla que depende de la red distingue cuatro situaciones: cargando, con datos, vacía y con error. Una lista vacía sin explicación parece una aplicación rota; por eso [`EstadoVacio`](lib/widgets/estado_vacio.dart) dice qué falta y ofrece la acción que lo resuelve, y mientras llega la respuesta se muestran marcadores con la forma del contenido en lugar de un círculo girando.
- **El color comunica.** El estado de una idea (`borrador`, `procesando`, `publicada`) tiene un color propio y una franja lateral en la tarjeta, para reconocerlo sin leer. El acierto de caché del panel se pinta en verde y el fallo en ámbar.
- **Los errores se explican donde ocurren.** Lo que pertenece a un campo aparece bajo el campo; lo que no —credenciales incorrectas, backend inalcanzable— aparece en un aviso sobre el formulario, con el mensaje ya traducido.

### 7.9 Pruebas del flujo

[`test/widget_test.dart`](test/widget_test.dart) recorre el flujo completo contra un backend simulado con `MockClient` y un almacén de sesión en memoria, sin necesidad de tener la API levantada:

```powershell
flutter test
```

Cubre las 17 comprobaciones: arranque sin sesión, campos obligatorios, formato de correo y largo de contraseña, credenciales incorrectas, autenticación correcta con token guardado, restauración de una sesión persistida, descarte de un token caducado, permanencia del estado al navegar entre las tres pantallas, identidad conservada en el detalle, borrador que sobrevive al cambio de pantalla, validaciones del registro, alta correcta, bloqueo de ruta privada sin sesión, cierre de sesión con borrado del token y bloqueo posterior, acceso público al diagnóstico y validación de la configuración.

Las pruebas fijan una ventana de 390×900 puntos, el tamaño de un teléfono real, en lugar de la de 800×600 que trae `flutter_test` por defecto. Así detectan desbordamientos de diseño que en una ventana ancha no aparecerían.

### 7.10 Correspondencia con la arquitectura de referencia

Los repositorios de referencia de la asignatura ([`canchago`](https://github.com/wpleonesz/canchago) y [`canchago-ionic`](https://github.com/wpleonesz/canchago-ionic)) están construidos con Ionic React, TypeScript y Capacitor. Atlas usa Flutter, así que la equivalencia no es de herramientas sino de **decisiones de arquitectura**:

| Convención de la referencia | Cómo se resuelve en Atlas |
|---|---|
| `services/api`: una única puerta HTTP | [`servicios/atlas_api.dart`](lib/servicios/atlas_api.dart). Ninguna pantalla habla con la red directamente. |
| `services/storage`: token en Secure Storage, **nunca** en almacenamiento en claro | [`servicios/almacen_sesion.dart`](lib/servicios/almacen_sesion.dart) sobre Keystore / Keychain (§7.6). |
| `store/`: estado de sesión (Zustand) | [`estado/`](lib/estado/) con `ChangeNotifier` + `InheritedWidget` (§7.5). |
| `pages/` y `routes/` separados | [`pantallas/`](lib/pantallas/) y [`rutas/`](lib/rutas/). |
| Rutas protegidas | [`GuardiaSesion`](lib/rutas/guardia_sesion.dart) en la tabla de rutas (§7.4). |
| Formularios con validación por esquema (React Hook Form + Zod) | `Form` + [`utiles/validadores.dart`](lib/utiles/validadores.dart), con los límites del esquema del backend (§7.2). |
| `config/env.ts` valida las variables al iniciar | `AppConfig.validar()`, que detiene el arranque con un mensaje claro si `API_BASE_URL` es inválida. |
| Nunca secretos en variables públicas del bundle | Ver la limitación 10 de §9: `--dart-define` tiene exactamente la misma exposición que `VITE_*`. |
| Verificación antes de integrar (`lint`, `typecheck`, `test`, `build`) | `flutter analyze`, `flutter test` y `flutter build apk`. |

**Diferencia declarada:** la referencia protege por **roles y permisos** (RBAC sobre Keycloak, con administrador, futbolista y gestor de cancha). El backend de Atlas emite un JWT con la identidad del usuario, pero no modela roles, así que la protección aquí es binaria: hay sesión o no la hay. Añadir autorización por rol exigiría primero cambiar el backend, y se declara como pendiente en lugar de simularla en el cliente.

---

## 8. Estructura del proyecto

```
atlas-app/
├── lib/
│   ├── main.dart                       Punto de entrada: crea el estado y monta las rutas
│   ├── config/
│   │   └── app_config.dart             Variables de entorno (--dart-define) y su validación
│   ├── tema/
│   │   └── tema_atlas.dart             Sistema de diseño: color, tipografía y componentes
│   ├── modelos/                        Datos que viajan entre la API y la interfaz
│   │   ├── usuario.dart                Usuario autenticado
│   │   ├── idea.dart                   Idea capturada (contenido nulable: solo llega en el detalle)
│   │   ├── metricas_panel.dart         Reporte del panel
│   │   ├── respuesta_api.dart          RespuestaApi<T> y ErrorApi
│   │   └── estado_permiso.dart         Los 4 estados de un permiso (S14): concedido/denegado/denegado
│   │                                   permanente/restringido
│   ├── servicios/
│   │   ├── atlas_api.dart              Cliente HTTP: rutas, token y errores de red
│   │   ├── almacen_sesion.dart         Token en el Keystore / Keychain del dispositivo
│   │   ├── voz_servicio.dart           Dictado por voz: speech_to_text + permission_handler (S14)
│   │   ├── notificaciones_servicio.dart Aviso local de idea publicada: flutter_local_notifications (S14)
│   │   └── preferencias_locales.dart   SharedPreferences: preferencia de aviso y último estado visto (S14)
│   ├── estado/                         Manejo de estado (ChangeNotifier)
│   │   ├── controlador_sesion.dart     Sesión, usuario y token
│   │   ├── controlador_ideas.dart      Lista de ideas, borrador, CRUD y aviso de "idea publicada" (S14)
│   │   ├── controlador_panel.dart      Métricas del panel
│   │   ├── controlador_publicaciones.dart  Generación con IA: publicar, consultar el job y leer el resultado (S15)
│   │   └── ambito_atlas.dart           Reparte los controladores y el servicio de voz (InheritedWidget)
│   ├── rutas/
│   │   ├── rutas.dart                  Tabla de rutas con nombre (onGenerateRoute)
│   │   └── guardia_sesion.dart         Bloquea las rutas privadas sin sesión
│   ├── pantallas/                      Páginas de la aplicación
│   │   ├── pantalla_carga.dart         Arranque y configuración inválida
│   │   ├── pantalla_login.dart         Inicio de sesión (pública)
│   │   ├── pantalla_registro.dart      Alta de cuenta (pública)
│   │   ├── pantalla_conexion.dart      Diagnóstico de conectividad (pública)
│   │   ├── pantalla_inicio.dart        Contenedor privado con barra inferior
│   │   ├── pantalla_ideas.dart         Listado de ideas
│   │   ├── pantalla_nueva_idea.dart    Formulario de creación/edición, con dictado por voz (S14)
│   │   ├── pantalla_detalle_idea.dart  Detalle de una idea, con editar y eliminar
│   │   ├── pantalla_panel.dart         Panel de métricas
│   │   └── pantalla_perfil.dart        Perfil, cierre de sesión y aviso de idea publicada (S14)
│   ├── utiles/
│   │   └── validadores.dart            Reglas de validación reutilizables
│   └── widgets/                        Componentes compartidos
│       ├── campo_texto.dart            Campo de formulario validado
│       ├── aviso_error.dart            Aviso de error de formulario o de API
│       ├── marca_atlas.dart            Logotipo y avatar con el degradado de marca
│       ├── estado_vacio.dart           Estado vacío y marcadores de carga
│       ├── tarjeta_idea.dart           Tarjeta de idea, insignia de estado y etiquetas
│       └── bloque_resultado.dart       Tarjeta de resultado con cabeceras
├── android/app/src/main/
│   ├── AndroidManifest.xml             Permisos (INTERNET, RECORD_AUDIO, POST_NOTIFICATIONS) y política de red
│   └── res/xml/
│       └── network_security_config.xml Excepción acotada de tráfico sin cifrar
├── ios/Runner/
│   └── Info.plist                      Cadenas de propósito: micrófono y reconocimiento de voz (S14)
├── herramientas/
│   ├── verificar-entorno.ps1           Reporte completo del entorno
│   ├── configurar-host.ps1             Sincroniza la política de red con la IP actual
│   └── abrir-firewall.ps1              Regla de firewall para el puerto 8000
├── test/
│   ├── unidad/                         Pruebas unitarias: validadores, cliente HTTP y controlador de IA (S15)
│   └── widget_test.dart                Flujo completo contra un backend simulado
├── integration_test/
│   └── flujo_completo_test.dart        Punta a punta en el teléfono contra el backend real (S15)
├── .vscode/
│   ├── launch.json                     Configuraciones de ejecución por destino
│   └── extensions.json                 Extensiones recomendadas
├── run.ps1                             Lanzador con detección automática de IP
└── pubspec.yaml                        Dependencias (pub)
```

---

## 9. Limitaciones conocidas del entorno

Declaradas de forma explícita, como exige el taller:

1. **No se puede compilar para iOS.** La cadena de herramientas de Apple (Xcode) solo existe en macOS. El código fuente de iOS está generado y versionado, pero la compilación de ese objetivo queda fuera del alcance con el hardware disponible.
2. **No hay emulador configurado.** Se optó por dispositivo físico (§2.2). Ejecutar un dispositivo virtual requeriría instalar Android Studio y las imágenes del sistema.
3. **La IP local depende de DHCP.** Si el router asigna otra dirección, hay que recompilar: `run.ps1` detecta la nueva IP y sincroniza la política de seguridad de red, pero al ser un recurso de Android el cambio no se aplica con recarga en caliente.
4. **El teléfono y el computador deben estar en la misma red Wi-Fi.** Las redes con aislamiento de clientes (*AP isolation*), habitual en redes públicas o corporativas, impiden la conexión aunque el firewall esté abierto.
5. **El tráfico va sin cifrar.** Aceptable solo en desarrollo y acotado a los hosts declarados (§4). Un despliegue real exige HTTPS.
6. **El backend debe estar levantado antes de arrancar la aplicación.** Si Docker no está corriendo, la pantalla de diagnóstico muestra el error y la sugerencia correspondiente.
7. **No hay renovación automática del token.** El JWT se guarda cifrado y sobrevive al cierre de la aplicación (§7.6), pero cuando expira no se renueva solo: la aplicación cierra la sesión y pide autenticarse de nuevo. Un *refresh token* exige soporte en el backend.
8. **No hay recuperación de contraseña.** El backend no expone todavía ese flujo, así que la aplicación no puede ofrecerlo.
9. **No hay roles ni permisos.** La protección es binaria: hay sesión o no la hay. El backend de Atlas no modela roles, así que no hay nada que autorizar por encima de eso.
10. **`--dart-define` no es un almacén de secretos.** El valor queda compilado dentro del binario y es extraíble de la APK. Sirve para mantener un dato *fuera del repositorio*, no para protegerlo; por eso solo se inyecta por esa vía la contraseña de una cuenta de demostración desechable.
11. **El dictado por voz depende de un servicio del sistema que la aplicación no controla.** En Android, de que el dispositivo tenga instalado el reconocimiento de voz de Google (ausente en compilaciones AOSP sin Play Services); en iOS, de que Apple habilite el reconocedor para el idioma configurado. `hayReconocimientoDisponible()` (§11.4) detecta esta condición y la aplicación degrada a la escritura manual; no hay un dictado alternativo *on-device* propio.
12. **La notificación de "idea publicada" no es push.** Es una notificación LOCAL que se dispara al comparar el `GET /ideas` más reciente contra el último estado guardado (§11.6): si la aplicación nunca vuelve a primer plano ni se refresca la lista, la transición no se detecta y el aviso no llega hasta la siguiente vez que se abra. Implementar un aviso verdaderamente en tiempo real exigiría notificaciones push (FCM/APNs) y que el backend conociera el token del dispositivo, lo que está fuera del alcance de este taller.
13. **El estado de permiso "restringido" no se pudo grabar en un dispositivo real.** Se reproduce mediante un doble de prueba (`VozServicioFalso`/`NotificacionesServicioFalso` con `EstadoPermiso.restringido`, cubierto por `flutter test`) porque requeriría un perfil de trabajo o un MDM que no está disponible para esta demostración; el código lo maneja igual que la denegación permanente salvo que no ofrece el atajo a ajustes, porque en ese caso abrirlos tampoco cambiaría nada.

---

## 10. Relación con el proyecto integrador

Este repositorio es el **componente móvil** de la práctica experimental de la asignatura. Se articula con los avances previos:

| Semana | Entregable | Repositorio |
|---|---|---|
| 1–3 | Propuesta, paradigma multiplataforma, lenguaje e IDE | `andytoala-dev/06-aplicaciones-moviles` |
| 4 | Base de datos normalizada (7 entidades y una tabla puente, PostgreSQL) | `andytoala-dev/06-aplicaciones-moviles` |
| 8 | Backend, APIs, autenticación y optimización | `atlas-backend` |
| 9 | Entorno móvil, proyecto base e integración con la API | `atlas-app` (este repositorio) |
| 12 | Autenticación, navegación, manejo de estado y formularios | `atlas-app` (este repositorio) |
| 13 | CRUD completo de ideas contra la API real (crear, consultar, editar y eliminar) | `atlas-app` + `atlas-backend` |
| 14 | Funcionalidades nativas del dispositivo: dictado por voz y notificaciones locales | `atlas-app` |
| **15** | **Publicaciones con IA real (OpenRouter) y pruebas por niveles: unitarias, de widget e integración** | **`atlas-app` + `atlas-backend`** |

El modelo de la Semana 4 se implementa en [`atlas-backend/app/models.py`](https://github.com/AndyToala2006/atlas-backend/blob/main/app/models.py): **7 entidades** —`Usuario`, `PerfilTono`, `Etiqueta`, `Idea`, `Publicacion`, `MetricaPublicacion` y `Job`— más la **tabla puente** `idea_etiqueta`, que resuelve la relación N:M entre ideas y etiquetas.

En términos de la guía de la práctica experimental, la Semana 9 cubrió el arranque de las actividades 12 (desarrollo de la aplicación móvil) y 13 (conexión con el backend); la Semana 12 continuó la actividad 12 con el flujo de sesión, la navegación y los formularios. La Semana 13 cerró las actividades 7, 13 y 14: el CRUD completo sobre la base de datos (7), la conexión de la aplicación con el backend propio (13) y la validación del flujo de datos de extremo a extremo (14). La **Semana 14 continúa la actividad 12**: el prototipo pasa de consumir solo la API a aprovechar también el hardware del teléfono, que es la mitad de la propuesta original de Atlas —"captura ideas por texto o por audio"— que hasta la Semana 13 no se había construido.

---

## 11. Funcionalidades nativas del dispositivo (Semana 14)

El prototipo integrado en la Semana 13 consumía la API propia pero no usaba ninguna capacidad del teléfono. Esta unidad incorpora dos: **dictado por voz** y **aviso local de idea publicada**, con los cuatro estados de un permiso, degradación explícita ante cada indisponibilidad y su integración con la persistencia local y el backend.

### 11.1 Selección y justificación

| Capacidad | Carácter | Por qué |
|---|---|---|
| **Micrófono → dictado por voz** | **Esencial** | Atlas se presenta desde la Semana 9 como una aplicación que "captura ideas **por texto o por audio**" (`PrubasV.md`, guion de la Semana 9). Hasta la Semana 13 solo existía la mitad de esa frase: el formulario únicamente aceptaba texto escrito. El dictado no es un añadido cosmético, es completar la propuesta original del proyecto. |
| **Notificaciones locales → aviso de "idea publicada"** | **Opcional** | El backend procesa una idea de forma asíncrona (Celery): pasa por `borrador` → `procesando` → `publicada`. Sin aviso, el usuario tiene que volver a entrar a comprobarlo a mano; con él, se entera en el momento. La aplicación funciona exactamente igual sin este permiso: es una mejora de experiencia, no un requisito del flujo. |

### 11.2 Plugins adoptados y verificación

Se aplicaron seis criterios explícitos antes de adoptar cada paquete: (1) resuelve una única responsabilidad, sin mezclar permisos con otras capacidades; (2) tiene soporte declarado para Android **e** iOS, no solo para uno; (3) instala sin conflictos de versión contra el resto de `pubspec.yaml` (verificado con `flutter pub add` y `flutter pub get`, sin *overrides* ni *downgrades* forzados); (4) es compatible con el SDK de Dart del proyecto (`^3.11.5`) y con *null safety*; (5) es el paquete de referencia del ecosistema Flutter para esa capacidad, no un *fork* personal de baja adopción; (6) no envía datos a un servidor de terceros ajeno al propio sistema operativo o al backend de Atlas.

| Paquete | Versión | Responsabilidad | Verificación puntual |
|---|---|---|---|
| [`permission_handler`](https://pub.dev/packages/permission_handler) | `^13.0.2` | Consulta y solicitud de permisos con los cuatro estados de plataforma | Paquete de referencia para permisos en Flutter; expone `PermissionStatus` con `isGranted`, `isPermanentlyDenied`, `isRestricted` y `isLimited`, que es exactamente el vocabulario de los cuatro estados que exige el taller (`modelos/estado_permiso.dart` los traduce uno a uno). |
| [`speech_to_text`](https://pub.dev/packages/speech_to_text) | `^7.4.0` | Reconocimiento de voz a texto | Es un envoltorio directo de `SpeechRecognizer` (Android) y `SFSpeechRecognizer` (iOS): el audio lo procesa el sistema operativo, nunca sale hacia un servidor de terceros ni hacia el backend de Atlas. |
| [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications) | `^22.3.1` | Notificación **local** (no push) | Se descartó deliberadamente cualquier SDK de mensajería (Firebase Cloud Messaging): el taller pide una capacidad nativa del dispositivo, no una integración de infraestructura de servidor. Esta librería no depende de un proyecto de Firebase ni de que el backend conozca un token de dispositivo. |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | `^2.5.5` | Persistencia local no sensible | Envoltorio oficial (`flutter.dev`) de `SharedPreferences`/`NSUserDefaults`. Se usa solo para la preferencia de aviso y el último `estado` visto de cada idea; el JWT sigue exclusivamente en `flutter_secure_storage` (§7.6): nunca se mezclan los dos almacenes. |

**Dificultad encontrada al compilar.** `flutter build apk --debug` (§1.3) es también la forma de comprobar que un plugin nuevo no rompe la cadena de compilación antes de tocar el teléfono. Dos plugins fallaron aquí, no en tiempo de ejecución:

- `permission_handler` resolvía por defecto `permission_handler_android` 14.1.0, publicado apenas unos días antes de esta entrega, cuyo `build.gradle.kts` exige AGP 9 y Kotlin 2.3.20 — versiones más nuevas que el AGP 8.11.1 / Kotlin 2.2.20 de este proyecto (§1.1). Se fijó la última versión anterior a ese salto con un `dependency_overrides` en `pubspec.yaml` (`permission_handler_android: 13.0.1`), documentado ahí mismo con el motivo.
- `flutter_local_notifications` usa en Android una API que requiere *core library desugaring* cuando el `minSdk` del proyecto es menor que 26. Se activó `isCoreLibraryDesugaringEnabled = true` y se agregó la dependencia `com.android.tools:desugar_jdk_libs` en [`android/app/build.gradle.kts`](android/app/build.gradle.kts).

Ninguno de los dos cambios afecta a `compileSdk`/`targetSdk` (§11.7): son ajustes de la cadena de compilación, no del nivel de API que ve el sistema operativo.

### 11.3 Permisos declarados en Android y cadenas de propósito en iOS

**Android** — [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml):

| Permiso | Uso concreto en Atlas |
|---|---|
| `RECORD_AUDIO` | Capturar el audio mientras el usuario dicta el contenido de una idea. Es un permiso "peligroso": Android pide confirmación en tiempo de ejecución. |
| `POST_NOTIFICATIONS` | Mostrar el aviso local de "idea publicada". Es un permiso en tiempo de ejecución solo desde Android 13 (API 33); en versiones anteriores el sistema lo concede con solo declararlo aquí. |

No se declaró `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE` ni ningún permiso de galería: ninguna de las dos funcionalidades lee ni escribe archivos multimedia. Tampoco se declararon los permisos de Bluetooth que documenta `speech_to_text` para auriculares emparejados: son opcionales y habrían ampliado la superficie de permisos sin necesidad, en contra del criterio de cumplimiento del propio taller.

**iOS** — [`ios/Runner/Info.plist`](ios/Runner/Info.plist):

| Clave | Cadena de propósito |
|---|---|
| `NSMicrophoneUsageDescription` | "Atlas usa el micrófono para dictar por voz el contenido de una idea, como alternativa a escribirlo a mano. Solo se activa mientras mantienes la escucha abierta." |
| `NSSpeechRecognitionUsageDescription` | "Atlas envía el audio dictado al reconocedor de voz del sistema para convertirlo en el texto de tu idea. El audio no se guarda ni se envía al backend de Atlas." |

Notificaciones no necesita una clave en `Info.plist`: en iOS se autoriza en tiempo de ejecución contra `UNUserNotificationCenter`, igual que se resuelve aquí con `Permission.notification`. Como la limitación 1 (§9) ya declara que este equipo no compila para iOS, la compilación real del target iOS con `pod install` queda pendiente para cuando se disponga de macOS/Xcode; en ese momento hay que habilitar explícitamente los flags `PERMISSION_MICROPHONE`, `PERMISSION_SPEECH_RECOGNIZER` y `PERMISSION_NOTIFICATIONS` de `permission_handler` en el `Podfile` (documentado en el README del paquete), porque por defecto vienen desactivados para no enlazar código de permisos que la aplicación no usa.

### 11.4 Solicitud en el momento de uso y los cuatro estados

Ni el micrófono ni las notificaciones se piden al arrancar la aplicación. El primero se solicita al pulsar el ícono de micrófono en el formulario de nueva idea ([`pantallas/pantalla_nueva_idea.dart`](lib/pantallas/pantalla_nueva_idea.dart)); el segundo, al activar el interruptor "Avisarme cuando una idea se publique" en el perfil ([`pantallas/pantalla_perfil.dart`](lib/pantallas/pantalla_perfil.dart)). En los dos casos, antes de mostrar el diálogo **nativo** del sistema aparece un diálogo **propio de la aplicación** que explica para qué se va a usar el permiso — es la explicación previa que exige el taller, porque el diálogo del sistema operativo no deja espacio para justificarlo.

Los cuatro estados se modelan en un solo lugar, [`modelos/estado_permiso.dart`](lib/modelos/estado_permiso.dart) (`EstadoPermiso`), para que los dos servicios nativos —[`servicios/voz_servicio.dart`](lib/servicios/voz_servicio.dart) y [`servicios/notificaciones_servicio.dart`](lib/servicios/notificaciones_servicio.dart)— compartan el mismo vocabulario en vez de que cada pantalla interprete `permission_handler` a su manera:

| Estado | Qué significa | Qué hace la aplicación |
|---|---|---|
| **Concedido** | El usuario aceptó | Enciende el micrófono / activa el interruptor y guarda la preferencia. |
| **Denegado** | Rechazó, pero el sistema puede volver a preguntar | Mensaje breve invitando a reintentar; la función sigue disponible al volver a pulsar el botón. |
| **Denegado permanente** | Marcó "no volver a preguntar" (Android) o ya rechazó una vez el diálogo nativo (iOS) | Diálogo con un botón que abre los ajustes de la aplicación (`openAppSettings()` de `permission_handler`), porque pedirlo de nuevo no mostraría nada. |
| **Restringido** | Bloqueado por una política externa al usuario (control parental, perfil de trabajo, MDM) | Aviso de que la función no está disponible por una política del sistema, **sin** ofrecer ir a ajustes: en este caso abrirlos no cambia nada. |

### 11.5 Degradación ante cada situación de indisponibilidad

No toda indisponibilidad es un permiso denegado. La guía del taller pide distinguir explícitamente el permiso del **servicio** del dispositivo (el ejemplo que da es ubicación vs. GPS apagado; aquí el equivalente es el permiso de micrófono vs. el reconocedor de voz del sistema):

| Situación | Micrófono (dictado) | Notificaciones |
|---|---|---|
| Permiso concedido, servicio disponible | Dicta y agrega el texto al campo "Contenido" | Se activa el interruptor; el aviso llega en cuanto una idea pasa a "publicada" |
| Permiso denegado | Explica y permite reintentar; el campo sigue editable a mano | El interruptor no se enciende; se puede reintentar |
| Denegación permanente | Diálogo con acceso directo a ajustes | Diálogo con acceso directo a ajustes |
| Restringido por política del sistema | Aviso sin ofrecer ajustes; se escribe a mano | Aviso sin ofrecer ajustes |
| **Permiso concedido pero el SERVICIO no responde** (sin Google app / Play Services, o sin el idioma instalado) | `hayReconocimientoDisponible()` lo detecta antes de escuchar y avisa; el usuario escribe la idea a mano sin que el formulario se bloquee | *(no aplica: la notificación local no depende de un servicio externo, solo del permiso)* |

En ningún caso la aplicación queda bloqueada o crashea: el formulario de nueva idea siempre acepta texto escrito, con o sin micrófono, y la lista de ideas siempre se puede consultar entrando a mirarla, con o sin notificaciones.

### 11.6 Integración con la persistencia local y el backend

- **Dictado → backend.** El texto reconocido se escribe en el mismo `TextEditingController` que ya alimentaba el borrador (§7.5): sigue guardándose en `ControladorIdeas` en cada pulsación, así que una idea a medio dictar sobrevive a la navegación exactamente igual que una escrita a mano. Al guardar, `origen` viaja como `'audio'` en vez de `'texto'` (`AtlasApi.crearIdea`, §6), y el detalle de la idea ya mostraba —desde antes de esta semana— un ícono distinto (`Icons.mic_none`) para ese valor: la interfaz estaba preparada para este dato, solo faltaba que el cliente lo produjera.
- **Notificaciones → persistencia local → backend.** [`servicios/preferencias_locales.dart`](lib/servicios/preferencias_locales.dart) guarda, con `shared_preferences`, dos cosas: si el usuario activó el aviso, y el último `estado` visto de cada idea (`{id: estado}`). Cada `GET /ideas` (`ControladorIdeas.cargar`) compara el `estado` recién leído contra ese mapa; si una fila pasó de `procesando` a `publicada`, dispara la notificación local y luego actualiza el mapa. Esa comparación sobrevive al cierre de la aplicación —el mapa vive en disco, no en memoria—, así que una idea que terminó de procesarse mientras el teléfono estaba apagado también genera el aviso la primera vez que se vuelve a abrir la lista.
- **Privacidad entre cuentas.** Al cerrar sesión, `ControladorIdeas.limpiar()` borra el mapa de estados guardado (no son datos del dispositivo, son datos de las ideas de un usuario concreto), igual que ya limpiaba la lista de ideas en memoria. La preferencia de "notificaciones activadas" sí se conserva: es un ajuste del teléfono, no un dato de la cuenta.
- **Nunca en el almacén del token.** El JWT sigue siendo el único dato que pasa por `flutter_secure_storage` (§7.6). Todo lo nuevo de esta semana usa `shared_preferences`, que no está cifrado a propósito: ninguno de los dos datos que guarda (una preferencia booleana y un mapa de estados públicos de las propias ideas del usuario) es sensible.

### 11.7 Cumplimiento de la tienda

- **Sin permisos de acceso amplio innecesarios.** No se declaró ningún permiso de galería/almacenamiento (no hace falta: ninguna funcionalidad nueva lee ni escribe archivos), ni los permisos de Bluetooth opcionales de `speech_to_text`, ni `ACCESS_FINE_LOCATION` ni ningún otro permiso ajeno a las dos capacidades incorporadas.
- **Nivel de API objetivo.** El proyecto usa `targetSdk = flutter.targetSdkVersion`, que en el Flutter SDK instalado (3.41.7, §1.1) resuelve a **Android 16 (API 36)** — el mismo nivel que ya reportaba `flutter doctor` en la Semana 9. Google Play exige apuntar a Android 16 desde el 31 de agosto de 2026 (recordatorio explícito del taller): este proyecto ya lo cumple sin cambios adicionales. `compileSdk` usa el mismo valor administrado por Flutter, así que ambos se mueven juntos en cada actualización del SDK.

### 11.8 Casos de prueba para ejecutar en un dispositivo físico

Los cinco casos siguientes están cubiertos por pruebas automatizadas en [`test/widget_test.dart`](test/widget_test.dart) con dobles de prueba (`VozServicioFalso`, `NotificacionesServicioFalso`, `PreferenciasLocalesEnMemoria`), porque el canal nativo de `speech_to_text`, `flutter_local_notifications` y `permission_handler` no existe en el entorno de `flutter test` — esa parte sí está verificada (`flutter test`, 34 pruebas en verde). Lo que falta, y es responsabilidad de quien grabe el video, es repetirlos **en el teléfono físico**, no en el emulador (misma justificación de §2.2), y registrar el resultado observado antes de la entrega:

| # | Caso | Cómo forzarlo en el teléfono | Resultado esperado | Prueba automatizada equivalente | Verificado en el teléfono |
|---|---|---|---|---|---|
| 1 | Permiso concedido en el primer intento | Ajustes → Apps → Atlas → Permisos → restablecer a "Preguntar cada vez"; abrir el formulario y pulsar el micrófono / activar el interruptor | El micrófono dicta y el texto aparece en el campo; el interruptor de notificaciones se enciende | `El dictado por voz completa el contenido...` / `Activar el aviso de notificaciones...` | ☐ |
| 2 | Permiso denegado (simple) | En el diálogo nativo, elegir "Denegar" (sin marcar "no volver a preguntar") | Aparece el mensaje de reintento; el campo de texto y el resto de la aplicación siguen funcionando con normalidad | `El microfono denegado explica antes de pedir el permiso...` | ☐ |
| 3 | Denegación permanente | Marcar "no volver a preguntar" al denegar (o denegar dos veces seguidas en Android) | La aplicación ofrece el atajo a Ajustes de la aplicación; al conceder el permiso desde ahí y volver, la función ya opera | `El microfono en denegacion permanente ofrece abrir los ajustes` / `Notificaciones en denegacion permanente...` | ☐ |
| 4 | Indisponibilidad del **servicio** con el permiso ya concedido | Si el teléfono de prueba tiene Google app, este caso es difícil de forzar en vivo; se documenta como verificado por la prueba automatizada, que sí fuerza `hayReconocimientoDisponible()` a `false` | Aviso de que el reconocimiento no está disponible; el formulario se sigue llenando a mano sin ningún bloqueo | `Si el reconocedor no esta disponible, se avisa sin bloquear la escritura manual` | — (cubierto solo por la prueba automatizada) |
| 5 | Notificaciones sin permiso concedido | Denegar el permiso de notificaciones y, aun así, dejar que una idea pase a "publicada" (cambiando a mano el estado de la idea en la base de datos) | Tal como advierte el propio taller: el código no lanza ningún error, simplemente la notificación nunca aparece; el interruptor permanece apagado y la aplicación sigue funcionando | `Notificaciones en denegacion permanente...` / `Notificaciones restringidas...` | ☐ |

El estado **restringido** (control parental / MDM) se documenta solo con el doble de prueba (`El microfono restringido...`, `Notificaciones restringidas...`), porque forzarlo de verdad exige un perfil de trabajo o un gestor de dispositivos que no todo equipo de prueba tiene disponible; si el tuyo lo tiene, es el sexto caso a demostrar. El código lo trata igual que la denegación permanente salvo que **no** ofrece el atajo a ajustes, porque en ese caso abrirlos no revertiría nada (§11.4).

---

## 12. Publicaciones con IA y estrategia de pruebas (Semana 15)

Hasta la Semana 14 la app capturaba ideas, pero la segunda mitad de la propuesta de Atlas —"y la IA las transforma en publicaciones"— solo existía en el backend y con un generador simulado. Esta entrega cierra el producto: la idea se convierte en una publicación **redactada por un modelo de lenguaje real** desde el propio teléfono.

### 12.1 Flujo de punta a punta

```
Teléfono (detalle de la idea)          atlas-backend                      Externo
─────────────────────────────          ─────────────                      ───────
Elige red + "Generar con IA"
  POST /ideas/{id}/publicar  ───────▶  crea Job, idea = "procesando"
                             ◀───────  202 {job_id}   (al instante)
                                       Celery encola ──▶ worker ──────▶  OpenRouter
  GET /jobs/{id}  cada 2 s   ───────▶  queued → processing                (modelo LLM)
                                       guarda Publicacion   ◀───────────  texto
                             ◀───────  done {resultado_publicacion_id}
  GET /ideas/{id}/publicaciones ────▶  lista, la más reciente primero
  Muestra el texto, "Copiar", notificación local "Tu publicación está lista"
```

### 12.2 Decisiones de diseño

| Decisión | Por qué |
|---|---|
| La **API key de OpenRouter vive solo en el backend** (`.env`) | Todo lo que va dentro de la APK es extraíble (§9, limitación 10). La app nunca la recibe; cambiar de modelo no exige publicar otra versión. |
| **Cola + consulta periódica** en vez de esperar en el request | Un LLM tarda varios segundos. El request responde `202` al instante y la interfaz sigue usable. |
| **Tope de espera** (2 min) en la consulta | Si el worker no está levantado, la app deja de preguntar y lo explica, en vez de gastar batería indefinidamente. |
| El estado de la generación vive en [`ControladorPublicaciones`](lib/estado/controlador_publicaciones.dart), **por encima del `Navigator`** | Si el usuario sale del detalle mientras la IA redacta, la consulta sigue y la publicación aparece al volver. |
| Al cerrar sesión se **descarta** cualquier consulta en vuelo | El resultado de un usuario no puede aparecer en la sesión del siguiente en el mismo teléfono. |
| Si la IA falla, el backend devuelve la idea a su estado anterior | Evita ideas atascadas en "procesando". La app muestra el motivo (key inválida, sin saldo, límite de peticiones) y permite reintentar. |

### 12.3 Pirámide de pruebas

| Nivel | Archivo | Pruebas | Qué verifica | Cómo se ejecuta |
|---|---|:---:|---|---|
| Unitaria (backend) | [`atlas-backend/tests/test_ia.py`](https://github.com/AndyToala2006/atlas-backend/blob/main/tests/test_ia.py) | 7 | Prompt con tono y red, límite de 280 caracteres en X, respaldo simulado sin key, errores de OpenRouter traducidos | `py -m unittest discover -s tests -t . -v` |
| Unitaria (app) | [`test/unidad/`](test/unidad/) | 16 | Contrato HTTP de los endpoints nuevos, decodificación de modelos, validadores alineados con el backend, y la lógica de consulta del job (tope de espera, doble toque, cierre de sesión a mitad) | `flutter test test/unidad` |
| Widget | [`test/widget_test.dart`](test/widget_test.dart) | 40 | Pantallas y navegación contra un backend simulado con `MockClient`: sesión, registro con su tono, CRUD, voz, notificaciones, el flujo "Generar con IA" con su camino de error, paginación, búsqueda y registro de rendimiento | `flutter test test/widget_test.dart` |
| Integración | [`integration_test/flujo_completo_test.dart`](integration_test/flujo_completo_test.dart) | 1 | En el teléfono y **sin nada simulado**: login → crear idea → generar con IA (FastAPI + Postgres + Redis + Celery + OpenRouter) → eliminar → comprobar en la API que ya no existe | ver §12.4 |

`flutter test` sin argumentos ejecuta los niveles unitario y de widget (56 pruebas).

### 12.4 Listado paginado, búsqueda y rendimiento de cada publicación

- **Paginación y búsqueda.** El listado pide las ideas de 20 en 20 (`limit`/`offset`) y muestra "Cargar más (20 de N)" con el total real que devuelve el backend en `X-Total-Count`. El buscador filtra en el servidor por título y contenido, y espera 400 ms desde la última tecla antes de consultar, para no lanzar una petición por cada letra.
- **Rendimiento.** Cada publicación tiene "Registrar rendimiento" (me gusta, comentarios, compartidos y alcance, validados igual que en el backend) y "Ver evolución", que lista los registros en el tiempo con la variación de interacciones entre uno y otro. El registro es **manual**, porque las APIs de métricas de las redes son de acceso restringido; el modelo de datos ya distingue `fuente = manual | api` para cuando la captura automática sea posible.
- **Panel coherente.** Registrar una métrica o generar una publicación refresca el panel. El backend suma solo la medición más reciente de cada publicación, así que medir dos veces la misma no duplica su engagement.

### 12.5 Ejecutar la prueba de integración

```powershell
# 1. Backend completo levantado (con OPENROUTER_API_KEY en atlas-backend/.env)
cd ..tlas-backend; docker compose up -d; cd ..tlas-app

# 2. Teléfono conectado por USB, en la misma red Wi-Fi que el PC
flutter test integration_test/flujo_completo_test.dart `
  --dart-define=API_BASE_URL=http://192.168.100.116:8000
```

### 12.6 Limitaciones declaradas frente a la propuesta inicial

| Propuesta inicial | Estado | Motivo |
|---|---|---|
| Enfoque *offline-first* con sincronización | No implementado | Las ideas viven en el backend; sin conexión la app avisa y no guarda. Requiere almacenamiento local y resolución de conflictos, fuera del alcance del semestre. |
| Grabaciones de audio almacenadas | Parcial | La voz se transcribe a texto en el teléfono (§11) y la idea queda marcada `origen = audio`; el archivo de audio no se guarda. |
| Captura automática de métricas desde las redes | Manual | Las APIs de Instagram, LinkedIn y X son de acceso restringido; el atributo `fuente` ya contempla el modo automático. |
| Supabase como backend | Opcional | El backend propio (FastAPI + PostgreSQL) puede apuntar a Supabase con `DATABASE_URL`; por defecto usa el PostgreSQL de Docker. |

La prueba registra una cuenta nueva en cada ejecución (`e2e-<marca>@atlas.app`), de modo que no depende de los datos de semilla ni modifica la cuenta de demostración. Sin `OPENROUTER_API_KEY` también pasa: el backend usa el generador simulado y la publicación sale marcada como "Generador simulado · sin API key".

---

## Licencia

Proyecto académico — Universidad Estatal Amazónica.
