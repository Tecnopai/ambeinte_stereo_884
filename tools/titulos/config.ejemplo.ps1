# config.ps1 - Claves del actualizador de titulos (NO compartir este archivo).
#
# Copiar este archivo como config.ps1 en la misma carpeta que
# convertir_metadata.ps1 y llenar los valores. Usar comillas SIMPLES.

# Web (titulo.php): lo leen la app y el reproductor de WordPress.
$URL_TITULOS   = 'https://TU-DOMINIO/radio/titulo.php'
$CLAVE_TITULOS = 'SoloLetrasYNumerosMinimo16Caracteres'   # la misma de titulo.php

# Servidores de streaming (opcionales). Se pueden dejar configurados aunque hoy
# no acepten titulos: el script vuelve a probar cada 5 minutos y empieza a
# enviar solo cuando el servidor lo permita. Dejar vacio para no usarlos.

# AzuraCast (sirve cuando el AutoDJ esta activo).
$URL_AZURACAST = ''   # p. ej. 'https://a10.asurahosting.com/api/station/702/nowplaying/update'
$API_KEY       = ''

# Icecast/Shoutcast directo (sirve si el servidor acepta titulos por URL).
$URL_ICECAST     = ''   # p. ej. 'https://a10.asurahosting.com:8870/admin/metadata'
$MOUNT_ICECAST   = '/radio.mp3'
$USUARIO_ICECAST = 'source'
$CLAVE_ICECAST   = ''   # la contrasena de la fuente (la del Comrex)

# Tambien se puede cambiar aqui cualquier otro valor del script, por ejemplo:
# $RETARDO_ENVIO = 1
