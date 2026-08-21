# Lanza Atlas sobre el destino elegido, inyectando la URL base de la API
# mediante --dart-define (variables de entorno de Dart/Flutter).
#
#   .\run.ps1                        -> dispositivo fisico, IP detectada automaticamente
#   .\run.ps1 -Destino emulador      -> emulador Android (10.0.2.2)
#   .\run.ps1 -Destino web           -> navegador (localhost)
#   .\run.ps1 -Ip 192.168.1.20       -> fuerza una IP concreta

param(
    [ValidateSet('dispositivo', 'emulador', 'web')]
    [string]$Destino = 'dispositivo',
    [string]$Ip,
    [int]$Puerto = 8000
)

if (-not $Ip) {
    $Ip = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.InterfaceAlias -notlike '*WSL*' -and
            $_.InterfaceAlias -notlike '*Hyper-V*'
        } | Select-Object -First 1).IPAddress
}

switch ($Destino) {
    'dispositivo' { $base = "http://${Ip}:$Puerto"; $extra = @() }
    'emulador'    { $base = "http://10.0.2.2:$Puerto"; $extra = @() }
    'web'         { $base = "http://localhost:$Puerto"; $extra = @('-d', 'chrome') }
}

Write-Host "Destino      : $Destino"
Write-Host "API_BASE_URL : $base"
Write-Host ""

if ($Destino -eq 'dispositivo') {
    if ($base -notmatch '192\.168\.|10\.|172\.') {
        Write-Host "Aviso: '$Ip' no parece una IP de red local. Verifica la conexion Wi-Fi." -ForegroundColor Yellow
    }
    # La politica de seguridad de red debe autorizar la IP actual, o Android
    # bloquea el trafico sin cifrar aunque la URL base sea la correcta.
    & (Join-Path $PSScriptRoot 'herramientas\configurar-host.ps1') -Ip $Ip
    Write-Host ""
}

flutter run `
    --dart-define=API_BASE_URL=$base `
    --dart-define=APP_ENV=$Destino `
    @extra
