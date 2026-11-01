# Lanza la app en el KM7 apuntando a la API local de esta laptop (puerto 8000).
# -Profile: modo profile, para medir el rendimiento real (debug va más lento).
param([switch]$Profile)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$env:Path += ";C:\Users\osori\AppData\Local\Android\Sdk\platform-tools"

# IP LAN: adaptador físico activo (wifi o ethernet) con gateway. Se excluyen
# los virtuales (VPN como ProTUN) y se prefiere la wifi, que es la red que
# comparte con el teléfono.
$cfg = Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' -and -not $_.NetAdapter.Virtual } |
    Sort-Object { $_.InterfaceAlias -notmatch 'Wi-?Fi|Wireless|WLAN' } |
    Select-Object -First 1
if (-not $cfg) { throw 'No se encontro un adaptador de red con gateway. Esta la laptop en la wifi?' }
$ip = $cfg.IPv4Address.IPAddress
$apiUrl = "http://${ip}:8000"
Write-Host "API_URL=$apiUrl"

# Llave de MapTiler desde .env (no se sube a git). Sin llave, el mapa usa OSM.
$mapTiler = ''
if (Test-Path "$PSScriptRoot\.env") {
    $linea = Get-Content "$PSScriptRoot\.env" | Where-Object { $_ -match '^MAPTILER_KEY=' } | Select-Object -First 1
    if ($linea) { $mapTiler = $linea.Substring('MAPTILER_KEY='.Length).Trim() }
}
Write-Host ("Mapa: " + $(if ($mapTiler) { 'MapTiler' } else { 'OSM (sin MAPTILER_KEY en .env)' }))

$opciones = @(
  '-d', '151983756N006106',
  "--dart-define=API_URL=$apiUrl",
  '--dart-define=GOOGLE_SERVER_CLIENT_ID=',
  "--dart-define=MAPTILER_KEY=$mapTiler"
)
if ($Profile) { $opciones += '--profile' }
flutter run @opciones
