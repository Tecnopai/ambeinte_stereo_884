# Títulos de las canciones sin depender del servidor de streaming

Cuando el servidor de streaming no envía los títulos dentro de la señal (por
ejemplo, con el Comrex conectado directo y sin AutoDJ), la app los lee de una
dirección web propia. No usa lecturas de Firebase.

## Cómo funciona

1. El script del computador de emisión (`convertir_metadata.ps1`) envía el
   título a `titulo.php` cada vez que cambia la canción, y lo reenvía cada
   minuto aunque no cambie (`$REENVIO_WEB`): así `actualizado` sirve de señal
   de vida del computador de emisión.
2. `titulo.php` lo guarda en `ahora_suena.json` junto a la hora:
   `{"titulo": "Artista - Canción", "actualizado": 1763049600}`.
3. La app lo consulta cada 20 s mientras la radio suena y lo muestra en
   pantalla, en la notificación y en la pantalla de bloqueo.
   - Si la señal ya trae títulos, se usan esos.
   - Si el título tiene más de 60 minutos o está vacío, no se muestra nada.
     Con el reenvío cada minuto, esto pasa solo si el computador de emisión
     deja de enviar (no por un audio largo, como las conferencias).
4. El reproductor de WordPress puede leer la misma dirección.

## Instalación

1. Subir `titulo.php` a un hosting con PHP (p. ej. `radio/titulo.php`) y
   cambiar `CLAVE`.
2. En Firebase, `app_config/streaming`, agregar el campo de texto
   `titulos_url` con la dirección completa de `titulo.php`.
3. En el computador de emisión, en la misma carpeta:
   - `convertir_metadata.ps1` (este repositorio; guardado como UTF-8 con BOM).
   - `config.ps1`: copia de `config.ejemplo.ps1` con la dirección de
     `titulo.php` y la clave (solo letras y números, mínimo 16). Si se usa
     AzuraCast (solo con AutoDJ activo), también su URL y clave de API.
4. Ejecutar `convertir_metadata.ps1`. Al cambiar la canción debe mostrar
   `OK web: '...'`.
5. Comprobar: abrir la dirección de `titulo.php` en el navegador. Antes del
   primer envío muestra `{"titulo":"","actualizado":0}`.

## El script

- Envía a la web cuando cambia la canción; si falla, reintenta cada vez más
  espaciado (máx. 60 s) con el título más reciente.
- Reenvía el último título a la web cada `$REENVIO_WEB` segundos (60 por
  defecto; 0 = solo al cambiar). El reenvío no escribe en la consola si sale
  bien.
- Servidores de streaming opcionales: AzuraCast (API, con AutoDJ) e
  Icecast/Shoutcast directo (`/admin/metadata`). Se pueden dejar
  configurados aunque hoy no acepten títulos: si uno falla 3 veces seguidas
  se pausa 5 minutos y vuelve a probar, así que empieza a funcionar solo al
  encender el AutoDJ, cambiar de servidor o cuando el proveedor lo habilite.
- Revisa la configuración al arrancar (clave inválida, sin destinos).
- Si la carpeta compartida de SARA no está disponible, avisa y sigue.

## Aviso de silencio

Los servidores pueden seguir "transmitiendo" aunque la emisora esté muda
(SARA detenido, consola apagada, Comrex sin audio). Para detectarlo, el
script escucha el stream público como un oyente:

- Cada `$INTERVALO_MEDICION` s (60) lanza ffmpeg en segundo plano, graba
  `$SEGUNDOS_MUESTRA` s (10) y mide el volumen máximo. Por debajo de
  `$UMBRAL_SILENCIO_DB` (-50 dB) cuenta como silencio. No frena los títulos.
- Mide en los servidores de Firebase (`stream_urls`), en orden; si uno no
  responde, la próxima vez prueba el siguiente. `$URL_STREAM_SILENCIO` fija
  uno.
- El resultado viaja con cada envío a `titulo.php`, que guarda `audio`
  (`ok`, `silencio` o `sin_dato`), `audio_nivel`, `audio_medido` y
  `silencio_desde` con la hora del hosting. La app ignora esos campos.
- Requiere ffmpeg: `winget install Gyan.FFmpeg` y abrir una ventana nueva. Al
  arrancar, el script debe decir `Silencio: se mide cada 60 s`. Si no lo
  encuentra, lo avisa y sigue sin medir. Con otra ruta: `$FFMPEG` en
  `config.ps1`. `$MEDIR_SILENCIO = $false` lo apaga.

El registro de oyentes avisa por Telegram tras 2 minutos de silencio, cuando
vuelve el audio y si pasan 10 minutos sin poder medir.

## Aviso si el computador de emisión se cae

El registro de oyentes de la emisora (Google Sheets + Apps Script, fuera de
este repositorio) revisa `titulo.php` cada minuto. Si `actualizado` lleva 3
minutos sin cambiar, avisa por Telegram que el computador de emisión, el
script de títulos o el internet de las instalaciones dejó de funcionar, y otra
vez cuando vuelve. Depende del reenvío cada minuto: con `$REENVIO_WEB = 0`
daría avisos falsos en audios largos.

`config.ps1` tiene claves: está en `.gitignore` y no se debe compartir ni
pegar en chats.
