# Atlas — aplicación móvil multiplataforma

Cliente móvil del proyecto integrador **Atlas**, desarrollado con Flutter y conectado al backend propio [`atlas-backend`](https://github.com/AndyToala2006/atlas-backend) (FastAPI + PostgreSQL + Redis + Celery).

| | |
|---|---|
| **Asignatura** | Aplicaciones Móviles (UEA-L-UFPTI-008) |
| **Código de aula** | 2626-UEA-L-UFPTI-008-C |
| **Taller vigente** | Semana 10 — Autenticación, navegación, estado y formularios (§7) |
| **Taller anterior** | Semana 9 — Configuración, verificación y conexión del entorno (§1–§6) |
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
| **Ideas** | `GET /ideas`, `POST /ideas` | Lectura y escritura de datos reales en PostgreSQL con el usuario autenticado. |
| **Detalle de idea** | `GET /ideas/{id}` | Relectura puntual de un registro, también protegida por token. |
| **Panel** | `GET /dashboard/metricas` | Reporte agregado servido con caché-aside en Redis. |

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

*(Taller Semana 10)*

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
│   │   ├── idea.dart                   Idea capturada
│   │   ├── metricas_panel.dart         Reporte del panel
│   │   └── respuesta_api.dart          RespuestaApi<T> y ErrorApi
│   ├── servicios/
│   │   ├── atlas_api.dart              Cliente HTTP: rutas, token y errores de red
│   │   └── almacen_sesion.dart         Token en el Keystore / Keychain del dispositivo
│   ├── estado/                         Manejo de estado (ChangeNotifier)
│   │   ├── controlador_sesion.dart     Sesión, usuario y token
│   │   ├── controlador_ideas.dart      Lista de ideas y borrador
│   │   ├── controlador_panel.dart      Métricas del panel
│   │   └── ambito_atlas.dart           Reparte los controladores (InheritedWidget)
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
│   │   ├── pantalla_nueva_idea.dart    Formulario de creación
│   │   ├── pantalla_detalle_idea.dart  Detalle de una idea
│   │   ├── pantalla_panel.dart         Panel de métricas
│   │   └── pantalla_perfil.dart        Perfil y cierre de sesión
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
│   ├── AndroidManifest.xml             Permiso INTERNET y política de red
│   └── res/xml/
│       └── network_security_config.xml Excepción acotada de tráfico sin cifrar
├── herramientas/
│   ├── verificar-entorno.ps1           Reporte completo del entorno
│   ├── configurar-host.ps1             Sincroniza la política de red con la IP actual
│   └── abrir-firewall.ps1              Regla de firewall para el puerto 8000
├── test/
│   └── widget_test.dart                Flujo completo contra un backend simulado
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

---

## 10. Relación con el proyecto integrador

Este repositorio es el **componente móvil** de la práctica experimental de la asignatura. Se articula con los avances previos:

| Semana | Entregable | Repositorio |
|---|---|---|
| 1–3 | Propuesta, paradigma multiplataforma, lenguaje e IDE | `andytoala-dev/06-aplicaciones-moviles` |
| 4 | Base de datos normalizada (9 entidades, PostgreSQL) | `andytoala-dev/06-aplicaciones-moviles` |
| 8 | Backend, APIs, autenticación y optimización | `atlas-backend` |
| 9 | Entorno móvil, proyecto base e integración con la API | `atlas-app` (este repositorio) |
| **10** | **Autenticación, navegación, manejo de estado y formularios** | **`atlas-app`** (este repositorio) |

En términos de la guía de la práctica experimental, la Semana 9 cubrió el arranque de las actividades 12 (desarrollo de la aplicación móvil) y 13 (conexión con el backend); la Semana 10 continúa la actividad 12 con el flujo de sesión, la navegación y los formularios de la aplicación.

---

## Licencia

Proyecto académico — Universidad Estatal Amazónica.
