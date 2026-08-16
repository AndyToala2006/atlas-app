# Atlas — aplicación móvil multiplataforma

Cliente móvil del proyecto integrador **Atlas**, desarrollado con Flutter y conectado al backend propio [`atlas-backend`](https://github.com/AndyToala2006/atlas-backend) (FastAPI + PostgreSQL + Redis + Celery).

| | |
|---|---|
| **Asignatura** | Aplicaciones Móviles (UEA-L-UFPTI-008) |
| **Código de aula** | 2626-UEA-L-UFPTI-008-C |
| **Taller** | Semana 9 — Configuración, verificación y conexión del entorno de desarrollo móvil |
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
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.4:8000
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
| **Dispositivo físico** | `http://192.168.1.4:8000` | El teléfono es otra máquina en la red Wi-Fi. Debe alcanzar al computador por su **IP en la LAN**. `localhost` apuntaría al propio teléfono. |
| Emulador de Android | `http://10.0.2.2:8000` | El emulador aísla su red; `10.0.2.2` es el alias que reserva para el `localhost` del anfitrión. `127.0.0.1` apuntaría al dispositivo virtual. |
| Navegador / escritorio | `http://localhost:8000` | La aplicación corre en el mismo equipo que el backend. |

La IP local se consulta con:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.InterfaceAlias -notlike '*WSL*' } |
  Select-Object IPAddress, InterfaceAlias
```

> La IP asignada por DHCP puede cambiar al reconectarse a la red. El script `run.ps1` la detecta automáticamente en cada ejecución.

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
flutter run --dart-define=API_BASE_URL=http://192.168.1.4:8000 --dart-define=APP_ENV=dispositivo
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
        <domain includeSubdomains="false">192.168.1.4</domain>
        <domain includeSubdomains="false">10.0.2.2</domain>
        <domain includeSubdomains="false">localhost</domain>
        <domain includeSubdomains="false">127.0.0.1</domain>
    </domain-config>
</network-security-config>
```

Lo importante es lo que **no** se hizo: no se activó `android:usesCleartextTraffic="true"` a nivel de aplicación, que habría abierto el tráfico sin cifrar hacia cualquier destino de internet. La `base-config` mantiene la exigencia de HTTPS para todo lo demás.

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

```powershell
cd ..\atlas-backend
docker compose up -d
curl http://localhost:8000/health      # {"status":"ok","servicio":"atlas-backend"}
```

### 5.2 Lanzar la aplicación

```powershell
cd ..\atlas-app
flutter devices        # confirmar que el teléfono aparece listado
.\run.ps1              # detecta la IP y arranca con --dart-define
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

La aplicación consume el backend construido en la unidad anterior. Tres pantallas cubren el recorrido completo:

| Pantalla | Endpoint | Qué demuestra |
|---|---|---|
| **Conexión** | `GET /health` | Primera solicitud exitosa. Endpoint público, sin autenticación. |
| **Sesión** | `POST /auth/login` → `GET /auth/me` | Autenticación con JWT. El token se guarda y viaja en `Authorization: Bearer`. |
| **Ideas** | `GET /ideas`, `POST /ideas` | Lectura y escritura de datos reales en PostgreSQL con el usuario autenticado. |

Cada respuesta se muestra en pantalla junto con los **datos de diagnóstico** que el backend devuelve en cabeceras, lo que evidencia que la información proviene realmente de la API y no de datos simulados en el cliente:

- `X-Process-Time-ms` — tiempo real de procesamiento en el servidor
- `X-Query-Count` — número de consultas SQL ejecutadas
- `X-Cache` — acierto o fallo de la caché en Redis

El interruptor *"consulta optimizada"* de la pantalla de ideas alterna el parámetro `optimized` de `GET /ideas`, que en el backend cambia entre *eager loading* y la versión ingenua con N+1. La diferencia se ve directamente en el teléfono a través de `X-Query-Count`.

**Credenciales de demostración** (creadas por `seed.py` en el backend): `demo@atlas.app` / `atlas123`

---

## 7. Estructura del proyecto

```
atlas-app/
├── lib/
│   ├── main.dart                       Punto de entrada y shell de navegación
│   ├── config/
│   │   └── app_config.dart             Variables de entorno (--dart-define)
│   ├── api/
│   │   └── atlas_api.dart              Cliente HTTP, modelos y manejo de errores
│   ├── pantallas/
│   │   ├── pantalla_conexion.dart      Diagnóstico y prueba de conectividad
│   │   ├── pantalla_sesion.dart        Login con JWT y validación de formulario
│   │   └── pantalla_ideas.dart         Listado y creación de ideas
│   └── widgets/
│       └── bloque_resultado.dart       Tarjeta de resultado con cabeceras
├── android/app/src/main/
│   ├── AndroidManifest.xml             Permiso INTERNET y política de red
│   └── res/xml/
│       └── network_security_config.xml Excepción acotada de tráfico sin cifrar
├── herramientas/
│   ├── verificar-entorno.ps1           Reporte completo del entorno
│   └── abrir-firewall.ps1              Regla de firewall para el puerto 8000
├── test/
│   └── widget_test.dart                Pruebas de arranque y navegación
├── .vscode/
│   ├── launch.json                     Configuraciones de ejecución por destino
│   └── extensions.json                 Extensiones recomendadas
├── run.ps1                             Lanzador con detección automática de IP
└── pubspec.yaml                        Dependencias (pub)
```

---

## 8. Limitaciones conocidas del entorno

Declaradas de forma explícita, como exige el taller:

1. **No se puede compilar para iOS.** La cadena de herramientas de Apple (Xcode) solo existe en macOS. El código fuente de iOS está generado y versionado, pero la compilación de ese objetivo queda fuera del alcance con el hardware disponible.
2. **No hay emulador configurado.** Se optó por dispositivo físico (§2.2). Ejecutar un dispositivo virtual requeriría instalar Android Studio y las imágenes del sistema.
3. **La IP local depende de DHCP.** Si el router asigna otra dirección, hay que relanzar la aplicación (`run.ps1` la detecta sola) y actualizar `network_security_config.xml`.
4. **El teléfono y el computador deben estar en la misma red Wi-Fi.** Las redes con aislamiento de clientes (*AP isolation*), habitual en redes públicas o corporativas, impiden la conexión aunque el firewall esté abierto.
5. **El tráfico va sin cifrar.** Aceptable solo en desarrollo y acotado a los hosts declarados (§4). Un despliegue real exige HTTPS.
6. **El backend debe estar levantado antes de arrancar la aplicación.** Si Docker no está corriendo, la pantalla de conexión muestra el error y la sugerencia correspondiente.

---

## 9. Relación con el proyecto integrador

Este repositorio es el **componente móvil** de la práctica experimental de la asignatura. Se articula con los avances previos:

| Semana | Entregable | Repositorio |
|---|---|---|
| 1–3 | Propuesta, paradigma multiplataforma, lenguaje e IDE | `andytoala-dev/06-aplicaciones-moviles` |
| 4 | Base de datos normalizada (9 entidades, PostgreSQL) | `andytoala-dev/06-aplicaciones-moviles` |
| 8 | Backend, APIs, autenticación y optimización | `atlas-backend` |
| **9** | **Entorno móvil, proyecto base e integración con la API** | **`atlas-app`** (este repositorio) |

En términos de la guía de la práctica experimental, este taller cubre el arranque de las actividades 12 (desarrollo de la aplicación móvil) y 13 (conexión de la aplicación móvil con el backend).

---

## Licencia

Proyecto académico — Universidad Estatal Amazónica.
