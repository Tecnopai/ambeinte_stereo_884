# Títulos de las canciones sin depender del servidor de streaming

Cuando el servidor de streaming no envía los títulos dentro de la señal (por
ejemplo, con el Comrex conectado directo y sin AutoDJ), la app los lee de una
dirección web propia. No usa lecturas de Firebase.

## Cómo funciona

1. El script del computador de emisión (`convertir_metadata.ps1`) envía el
   título a `titulo.php` cada vez que cambia la canción.
2. `titulo.php` lo guarda en `ahora_suena.json` junto a la hora:
   `{"titulo": "Artista - Canción", "actualizado": 1763049600}`.
3. La app lo consulta cada 20 s mientras la radio suena y lo muestra en
   pantalla, en la notificación y en la pantalla de bloqueo.
   - Si la señal ya trae títulos, se usan esos.
   - Si el título tiene más de 60 minutos o está vacío, no se muestra nada.
4. El reproductor de WordPress puede leer la misma dirección.

## Instalación

1. Subir `titulo.php` a un hosting con PHP (p. ej. `radio/titulo.php`) y
   cambiar `CLAVE`.
2. En Firebase, `app_config/streaming`, agregar el campo de texto
   `titulos_url` con la dirección completa de `titulo.php`.
3. En el script, en la configuración:

   ```powershell
   $URL_TITULOS   = "https://TU-DOMINIO/radio/titulo.php"
   $CLAVE_TITULOS = "LA-MISMA-CLAVE-DEL-PHP"
   ```

   Agregar esta función debajo de `Enviar-AAzuraCast`:

   ```powershell
   function Enviar-TituloWeb {
       param([string]$texto)
       try {
           $json  = @{ titulo = $texto } | ConvertTo-Json -Compress
           $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
           Invoke-RestMethod -Uri $URL_TITULOS -Method Post -Headers @{ "X-Clave" = $CLAVE_TITULOS } `
               -ContentType "application/json; charset=utf-8" -Body $bytes -TimeoutSec 8 | Out-Null
           Write-Host "   OK enviado a la web: '$texto'" -ForegroundColor Cyan
       } catch {
           Write-Host "   ERROR al enviar a la web: $($_.Exception.Message)" -ForegroundColor Red
       }
   }
   ```

   Y llamarla solo cuando cambia la canción (no en el reenvío cada 15 s): en
   el paso `# 2)`, justo después de `$pendientes.RemoveAt(0)`:

   ```powershell
               Enviar-TituloWeb -texto $item.Titulo
   ```

4. Comprobar: abrir la dirección de `titulo.php` en el navegador. Antes del
   primer envío muestra `{"titulo":"","actualizado":0}`.

No guardar en este repositorio la clave real ni la clave de la API de
AzuraCast.
