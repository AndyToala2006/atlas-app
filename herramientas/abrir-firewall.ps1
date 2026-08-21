# Autoriza el trafico entrante al backend de desarrollo (puerto 8000)
# unicamente desde la subred local, para que el telefono fisico pueda
# alcanzar la API que corre en este computador.
#
# REQUIERE ejecutarse en una consola de PowerShell como ADMINISTRADOR.
#
# Uso:      powershell -ExecutionPolicy Bypass -File .\herramientas\abrir-firewall.ps1
# Revertir: powershell -ExecutionPolicy Bypass -File .\herramientas\abrir-firewall.ps1 -Quitar

param(
    [switch]$Quitar,
    [string]$Subred,
    [int]$Puerto = 8000
)

$nombre = 'Atlas backend (desarrollo) - puerto 8000'

$esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
          ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Host "Este script necesita permisos de administrador." -ForegroundColor Red
    Write-Host "Abre PowerShell con 'Ejecutar como administrador' y vuelve a lanzarlo."
    exit 1
}

if ($Quitar) {
    Remove-NetFirewallRule -DisplayName $nombre -ErrorAction SilentlyContinue
    Write-Host "Regla eliminada: $nombre" -ForegroundColor Yellow
    exit 0
}

# La subred se deduce de la IP que el router asigno a este computador. Fijarla
# a mano es fragil: al pasar a otra red (192.168.100.x en vez de 192.168.1.x)
# la regla queda acotada a un rango donde el telefono no esta, y Windows sigue
# bloqueando el puerto 8000 sin dar ninguna senal clara.
if (-not $Subred) {
    $red = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.InterfaceAlias -notlike '*WSL*' -and
            $_.InterfaceAlias -notlike '*Hyper-V*' -and
            $_.InterfaceAlias -notlike '*Loopback*'
        } | Select-Object -First 1

    if (-not $red) {
        Write-Host "No se pudo determinar la red local. Conectate a la red Wi-Fi." -ForegroundColor Red
        exit 1
    }

    if ($red.PrefixLength -ne 24) {
        Write-Host ("Aviso: la interfaz '{0}' usa mascara /{1}, no /24." -f $red.InterfaceAlias, $red.PrefixLength) -ForegroundColor Yellow
        Write-Host "Si la regla no surte efecto, indica la subred a mano con -Subred." -ForegroundColor Yellow
    }

    $o = $red.IPAddress.Split('.')
    $Subred = '{0}.{1}.{2}.0/24' -f $o[0], $o[1], $o[2]
    Write-Host ("IP de este computador : {0}  ({1})" -f $red.IPAddress, $red.InterfaceAlias)
}

Write-Host "Subred autorizada     : $Subred"
Write-Host ""

Remove-NetFirewallRule -DisplayName $nombre -ErrorAction SilentlyContinue

New-NetFirewallRule `
    -DisplayName $nombre `
    -Description 'Permite que el dispositivo movil de desarrollo consuma la API de Atlas. Regla temporal, eliminar al terminar.' `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort $Puerto `
    -RemoteAddress $Subred `
    -Profile Private | Out-Null

Write-Host "Regla creada correctamente." -ForegroundColor Green
$regla = Get-NetFirewallRule -DisplayName $nombre
$regla | Format-List DisplayName, Enabled, Direction, Action, Profile
# El alcance real no vive en el objeto de la regla sino en su filtro de
# direcciones: es la prueba de que el puerto no quedo abierto a cualquier origen.
$regla | Get-NetFirewallAddressFilter | Format-List RemoteAddress
