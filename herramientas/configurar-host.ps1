# Sincroniza la politica de seguridad de red con la IP actual del computador.
#
# El router asigna la IP por DHCP y puede cambiar al reconectarse a la Wi-Fi.
# Si network_security_config.xml conserva una IP vieja, Android bloquea el
# trafico sin cifrar hacia el backend y la aplicacion falla al conectar aunque
# la URL base sea la correcta.
#
# Este script reescribe UNICAMENTE la linea marcada como HOST-DESARROLLO, de
# modo que la excepcion sigue acotada a un solo host.
#
# Uso:  .\herramientas\configurar-host.ps1              (detecta la IP)
#       .\herramientas\configurar-host.ps1 -Ip 10.0.0.5 (fuerza una IP)

param(
    [string]$Ip
)

$ErrorActionPreference = 'Stop'

$archivo = Join-Path $PSScriptRoot '..\android\app\src\main\res\xml\network_security_config.xml'
$archivo = (Resolve-Path $archivo).Path

if (-not $Ip) {
    $Ip = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.InterfaceAlias -notlike '*WSL*' -and
            $_.InterfaceAlias -notlike '*Hyper-V*' -and
            $_.InterfaceAlias -notlike '*Loopback*'
        } | Select-Object -First 1).IPAddress
}

if (-not $Ip) {
    Write-Host "No se pudo determinar la IP local. Conectate a la red Wi-Fi." -ForegroundColor Red
    exit 1
}

if ($Ip -notmatch '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)') {
    Write-Host "Aviso: '$Ip' no pertenece a un rango de red privada." -ForegroundColor Yellow
}

$contenido = Get-Content $archivo -Raw
$patron = '(?s)(<!-- HOST-DESARROLLO:INICIO -->).*?(<!-- HOST-DESARROLLO:FIN -->)'

if ($contenido -notmatch $patron) {
    Write-Host "No se encontraron los marcadores HOST-DESARROLLO en:" -ForegroundColor Red
    Write-Host "  $archivo"
    exit 1
}

$actual = if ($contenido -match '<!-- HOST-DESARROLLO:INICIO -->\s*<domain[^>]*>([^<]+)</domain>') {
    $Matches[1].Trim()
} else { '' }

if ($actual -eq $Ip) {
    Write-Host "La politica de red ya apunta a $Ip. Sin cambios." -ForegroundColor Green
    exit 0
}

$reemplazo = "`$1`r`n        <domain includeSubdomains=`"false`">$Ip</domain>`r`n        `$2"
$nuevo = [regex]::Replace($contenido, $patron, $reemplazo)
Set-Content -Path $archivo -Value $nuevo -Encoding UTF8 -NoNewline

Write-Host "Politica de red actualizada: $actual -> $Ip" -ForegroundColor Green
Write-Host "Es un recurso de Android: requiere recompilar (la recarga en caliente no basta)." -ForegroundColor Yellow
