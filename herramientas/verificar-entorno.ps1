# Verificacion del entorno de desarrollo movil - Atlas
# Taller Semana 9, Aplicaciones Moviles (UEA)
#
# Imprime en una sola corrida todas las versiones y rutas del entorno.
# Uso:  powershell -ExecutionPolicy Bypass -File .\herramientas\verificar-entorno.ps1

$ErrorActionPreference = 'Continue'

function Titulo($texto) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor DarkCyan
    Write-Host "  $texto" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor DarkCyan
}

Titulo "1. Sistema operativo"
$so = Get-CimInstance Win32_OperatingSystem
"{0}  (build {1})" -f $so.Caption, $so.BuildNumber
$cs = Get-CimInstance Win32_ComputerSystem
"CPU  : {0}" -f (Get-CimInstance Win32_Processor).Name.Trim()
"RAM  : {0} GB" -f [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)

Titulo "2. Flutter y Dart"
flutter --version

Titulo "3. Java (JDK usado por Gradle)"
"JAVA_HOME = $env:JAVA_HOME"
java -version

Titulo "4. Android SDK"
"ANDROID_HOME = $env:ANDROID_HOME"
adb version
"Plataformas instaladas :"
Get-ChildItem "$env:ANDROID_HOME\platforms" -ErrorAction SilentlyContinue |
    ForEach-Object { "  - $($_.Name)" }
"Build-tools instaladas :"
Get-ChildItem "$env:ANDROID_HOME\build-tools" -ErrorAction SilentlyContinue |
    ForEach-Object { "  - $($_.Name)" }

Titulo "5. Diagnostico completo de Flutter"
flutter doctor -v

Titulo "6. Dispositivos conectados"
flutter devices

Titulo "7. Red local (direccion que usa el dispositivo fisico)"
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object IPAddress, InterfaceAlias | Format-Table -AutoSize

Titulo "8. Backend alcanzable desde el computador"
try {
    $r = Invoke-WebRequest -Uri "http://localhost:8000/health" -UseBasicParsing -TimeoutSec 5
    "HTTP $($r.StatusCode) -> $($r.Content)"
} catch {
    "El backend NO responde en http://localhost:8000/health"
    "Levantalo con:  docker compose up -d   (en el repositorio atlas-backend)"
}

Write-Host ""
Write-Host "Verificacion finalizada." -ForegroundColor Green
