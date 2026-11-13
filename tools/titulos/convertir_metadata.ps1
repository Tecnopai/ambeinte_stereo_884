# convertir_metadata.ps1 - Publica el titulo que suena en Ambiente Stereo 88.4
#
# Lee el titulo que escribe SARA en un archivo, aplica los reemplazos y lo envia a:
#   1. La web (titulo.php)  -> lo leen la app y el reproductor de WordPress  [principal]
#   2. AzuraCast (API)      -> solo sirve si el AutoDJ esta activo            [opcional]
#
# Las claves NO van en este archivo: van en config.ps1, en la misma carpeta
# (copiar config.ejemplo.ps1 como config.ps1 y llenarlo).
#
# IMPORTANTE: guardar este archivo como "UTF-8 con BOM" (por las tildes y la Ñ
# de los reemplazos); si no, Windows PowerShell los lee mal.

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# === CONFIGURACION POR DEFECTO (config.ps1 puede cambiar cualquiera) ===
$ARCHIVO_ORIGINAL   = "\\MASTERN-PC\Compartido\CurrentSong.txt"
$ARCHIVO_DESTINO    = "\\MASTERN-PC\Compartido\CurrentSong_iso.txt"
$INTERVALO_SEGUNDOS = 1     # cada cuanto se revisa el archivo de SARA
$RETARDO_ENVIO      = 1     # segundos entre detectar un titulo y enviarlo

$URL_TITULOS        = ""    # direccion completa de titulo.php
$CLAVE_TITULOS      = ""    # la misma clave de titulo.php (solo letras y numeros)

$URL_AZURACAST      = ""    # vacio = no enviar a AzuraCast
$API_KEY            = ""
$REENVIO_AZURACAST  = 15    # AzuraCast necesita reenvio periodico (0 = no reenviar)

# === REEMPLAZOS ===
# Si el titulo CONTIENE la palabra de la izquierda (palabra completa, sin importar
# mayusculas), se reemplaza TODO el titulo por el texto de la derecha.
# Se revisan en orden: gana la primera que coincida.
$REEMPLAZOS = [ordered]@{
    "PDP"               = "Estás Escuchando Punto de Partida"
    "CUÑA"              = "Espacio Promocional"
    "SEPARADOR"         = "Espacio Promocional"
    "PISADOR"           = "Espacio Promocional"
    "BREAK"             = "Espacio Promocional"
    "Promo"             = "Espacio Promocional"
    "Festivo"           = "Espacio Promocional"
    "DRA"               = "Espacio Promocional"
    "Reuniones"         = "Espacio Promocional"
    "IDENTIFICACIÓN"    = "Espacio Promocional"
    "EMPANADAS"         = "Espacio Promocional"
    "GLOSA"             = "Espacio Promocional"
    "INGENIA"           = "Espacio Promocional"
    "SEÑAL"             = "Espacio Promocional"
    "Promocional"       = "Espacio Promocional"
    "ESLOGAN"           = "Espacio Promocional"
    "AMBIENTESTEREO"    = "Espacio Promocional"
    "ESTACIÓN MUSICAL"  = "Estás Escuchando Estación Musical"
    "PISTA"             = "Estación Musical"
    "SONIDOS DEL CIELO" = "Estás Escuchando Sonidos del Cielo"
    "VERDE TIERRA"      = "Verde Tierra"
    "SI ESTE MENSAJE"   = "Palabra de Vida"
    "PALABRA DE VIDA"   = "Palabra de Vida"
    "FONDO REFLEXION"   = "Reflexión"
    "MI REFUGIO"        = "Mi Refugio"
    "MUSICA ORACIÓN 02" = "Mi Refugio"
    "EN LAS TARDES"     = "En las Tardes"
}

# === CARGAR CLAVES (config.ps1) ===
$archivoConfig = Join-Path $PSScriptRoot 'config.ps1'
if (Test-Path $archivoConfig) {
    . $archivoConfig
} else {
    Write-Host "AVISO: no se encontro $archivoConfig (copie config.ejemplo.ps1 como config.ps1)" -ForegroundColor Yellow
}

# =====================================================================

function Log {
    param([string]$texto, [string]$color = 'Gray')
    Write-Host ("[" + (Get-Date -Format 'HH:mm:ss') + "] " + $texto) -ForegroundColor $color
}

function Contar-CaracteresRaros {
    param([string]$texto)
    $count = 0
    foreach ($c in $texto.ToCharArray()) {
        $code = [int]$c
        if ($code -gt 0 -and $code -lt 32) { $count++ }
    }
    return $count
}

function Leer-ArchivoRespetandoTildes {
    param([string]$ruta)
    $bytes = [System.IO.File]::ReadAllBytes($ruta)
    if ($bytes.Length -eq 0) { return $null }

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3).Trim()
    }

    $utf8Estricto = New-Object System.Text.UTF8Encoding($false, $true)
    try { return $utf8Estricto.GetString($bytes).Trim() } catch { }

    $texto1252   = [System.Text.Encoding]::GetEncoding(1252).GetString($bytes)
    $textoLatin1 = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)
    if ((Contar-CaracteresRaros $texto1252) -le (Contar-CaracteresRaros $textoLatin1)) {
        return $texto1252.Trim()
    }
    return $textoLatin1.Trim()
}

function Aplicar-Reemplazos {
    param([string]$texto)
    foreach ($clave in $REEMPLAZOS.Keys) {
        $patron = '(?<![\p{L}\p{N}])' + [regex]::Escape($clave) + '(?![\p{L}\p{N}])'
        if ([regex]::IsMatch($texto, $patron, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            return $REEMPLAZOS[$clave]
        }
    }
    return $texto
}

function Guardar-ConAcentos {
    param([string]$texto, [string]$ruta)
    try {
        $utf8SinBOM = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllBytes($ruta, $utf8SinBOM.GetBytes($texto))
    } catch {
        Log "AVISO: no se pudo escribir $ruta : $($_.Exception.Message)" 'DarkYellow'
    }
}

# Codigo HTTP de un error de Invoke-RestMethod (o $null si no hubo respuesta).
function Codigo-HTTP {
    param($errorRegistro)
    try { return [int]$errorRegistro.Exception.Response.StatusCode } catch { return $null }
}

# --- Envio a la web (titulo.php) ---------------------------------------
function Enviar-TituloWeb {
    param([string]$texto)
    try {
        $json  = @{ titulo = $texto } | ConvertTo-Json -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        Invoke-RestMethod -Uri $URL_TITULOS -Method Post -Headers @{ "X-Clave" = $CLAVE_TITULOS } `
            -ContentType "application/json; charset=utf-8" -Body $bytes -TimeoutSec 8 | Out-Null
        Log "OK web: '$texto'" 'Cyan'
        return $true
    } catch {
        $codigo = Codigo-HTTP $_
        if ($codigo -eq 403) {
            Log "ERROR web: clave incorrecta (403). Revise CLAVE_TITULOS y la CLAVE de titulo.php" 'Red'
        } elseif ($codigo) {
            Log "ERROR web: el servidor respondio $codigo" 'Red'
        } else {
            Log "ERROR web: $($_.Exception.Message)" 'Red'
        }
        return $false
    }
}

# --- Envio a AzuraCast (opcional) --------------------------------------
function Enviar-AAzuraCast {
    param([string]$texto)
    try {
        $json  = @{ title = $texto; artist = "" } | ConvertTo-Json -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        Invoke-RestMethod -Uri $URL_AZURACAST -Method Post -Headers @{ "X-API-Key" = $API_KEY } `
            -ContentType "application/json; charset=utf-8" -Body $bytes -TimeoutSec 8 | Out-Null
        return $true
    } catch {
        return $false
    }
}

# === REVISAR CONFIGURACION ===
$URL_TITULOS   = $URL_TITULOS.Trim()
$CLAVE_TITULOS = $CLAVE_TITULOS.Trim()
$URL_AZURACAST = $URL_AZURACAST.Trim()
$API_KEY       = $API_KEY.Trim()

$usarWeb       = $URL_TITULOS -ne ""
$usarAzuraCast = ($URL_AZURACAST -ne "") -and ($API_KEY -ne "")

if ($usarWeb -and $CLAVE_TITULOS -notmatch '^[A-Za-z0-9]{16,}$') {
    Write-Host "ERROR: CLAVE_TITULOS debe tener solo letras y numeros (minimo 16)." -ForegroundColor Red
    Write-Host "       Los simbolos y tildes no viajan bien. Use la misma en titulo.php." -ForegroundColor Red
    exit 1
}
if (-not $usarWeb -and -not $usarAzuraCast) {
    Write-Host "ERROR: no hay ningun destino configurado (URL_TITULOS o URL_AZURACAST)." -ForegroundColor Red
    exit 1
}

Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "  ACTUALIZADOR DE TITULOS EN VIVO - Ambiente Stereo 88.4" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "Archivo vigilado: $ARCHIVO_ORIGINAL"
Write-Host ("Web (app):        " + $(if ($usarWeb) { $URL_TITULOS } else { "desactivado" }))
Write-Host ("AzuraCast:        " + $(if ($usarAzuraCast) { $URL_AZURACAST } else { "desactivado" }))
Write-Host "Reemplazos:       $($REEMPLAZOS.Count) reglas"
Write-Host "Retardo de envio: $RETARDO_ENVIO s"
Write-Host "Ctrl+C para detener"
Write-Host "-------------------------------------------------------------" -ForegroundColor Gray

# === ESTADO ===
$ultimoContenido = ""
$pendientes      = New-Object System.Collections.Generic.List[object]   # titulos esperando su retardo
$archivoFallando = $false

# Web: solo importa el titulo mas reciente; si falla se reintenta cada vez mas espaciado.
$webPendiente    = $null
$webProximo      = [datetime]::MinValue
$webFallos       = 0

# AzuraCast: si falla varias veces seguidas se pausa un rato (p. ej. AutoDJ apagado).
$azTitulo        = ""
$azUltimoEnvio   = [datetime]::MinValue
$azFallos        = 0
$azPausaHasta    = [datetime]::MinValue

try {
    while ($true) {
        Start-Sleep -Seconds $INTERVALO_SEGUNDOS
        $ahora = Get-Date

        # 1) Detectar titulo nuevo
        $contenido = $null
        try {
            $contenido = Leer-ArchivoRespetandoTildes -ruta $ARCHIVO_ORIGINAL
            if ($archivoFallando) { Log "El archivo de SARA vuelve a estar disponible" 'Green'; $archivoFallando = $false }
        } catch {
            if (-not $archivoFallando) {
                Log "AVISO: no se puede leer $ARCHIVO_ORIGINAL ($($_.Exception.Message)). Se sigue intentando." 'DarkYellow'
                $archivoFallando = $true
            }
        }

        if ($contenido -and $contenido -ne $ultimoContenido) {
            $ultimoContenido = $contenido
            $titulo = Aplicar-Reemplazos -texto $contenido
            Write-Host ""
            Log "Titulo detectado: '$contenido'" 'Yellow'
            if ($titulo -ne $contenido) { Log "  -> reemplazado por: '$titulo'" 'Magenta' }
            Guardar-ConAcentos -texto $titulo -ruta $ARCHIVO_DESTINO
            $pendientes.Add([pscustomobject]@{ Hora = $ahora.AddSeconds($RETARDO_ENVIO); Titulo = $titulo })
        }

        # 2) Titulos cuyo retardo ya se cumplio
        while ($pendientes.Count -gt 0 -and $pendientes[0].Hora -le (Get-Date)) {
            $titulo = $pendientes[0].Titulo
            $pendientes.RemoveAt(0)
            if ($usarWeb) {
                $webPendiente = $titulo
                $webProximo   = [datetime]::MinValue
                $webFallos    = 0
            }
            if ($usarAzuraCast) {
                $azTitulo      = $titulo
                $azUltimoEnvio = [datetime]::MinValue   # enviar ya
            }
        }

        # 3) Web: enviar (o reintentar) el titulo pendiente
        if ($usarWeb -and $webPendiente -and (Get-Date) -ge $webProximo) {
            if (Enviar-TituloWeb -texto $webPendiente) {
                $webPendiente = $null
                $webFallos    = 0
            } else {
                $webFallos++
                $espera = [Math]::Min(60, 5 * $webFallos)
                $webProximo = (Get-Date).AddSeconds($espera)
                Log "  se reintenta en $espera s" 'DarkGray'
            }
        }

        # 4) AzuraCast: enviar al cambiar y reenviar periodicamente
        if ($usarAzuraCast -and $azTitulo -and (Get-Date) -ge $azPausaHasta) {
            $toca = ($azUltimoEnvio -eq [datetime]::MinValue) -or
                    ($REENVIO_AZURACAST -gt 0 -and ((Get-Date) - $azUltimoEnvio).TotalSeconds -ge $REENVIO_AZURACAST)
            if ($toca) {
                $esNuevo = $azUltimoEnvio -eq [datetime]::MinValue
                $azUltimoEnvio = Get-Date
                if (Enviar-AAzuraCast -texto $azTitulo) {
                    if ($esNuevo) { Log "OK AzuraCast: '$azTitulo'" 'Cyan' }
                    $azFallos = 0
                } else {
                    $azFallos++
                    if ($azFallos -ge 3) {
                        Log "AzuraCast no acepta titulos (3 fallos; ¿AutoDJ apagado?). Pausa de 5 min." 'DarkYellow'
                        $azPausaHasta = (Get-Date).AddMinutes(5)
                        $azFallos = 0
                    }
                }
            }
        }
    }
}
finally {
    Write-Host ""
    Write-Host "Script detenido" -ForegroundColor Yellow
}
