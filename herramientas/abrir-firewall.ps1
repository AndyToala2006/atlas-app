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
    [string]$Subred = '192.168.1.0/24',
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
Get-NetFirewallRule -DisplayName $nombre |
    Format-List DisplayName, Enabled, Direction, Action, Profile
