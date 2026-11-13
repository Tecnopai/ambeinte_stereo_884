# config.ps1 - Claves del actualizador de titulos (NO compartir este archivo).
#
# Copiar este archivo como config.ps1 en la misma carpeta que
# convertir_metadata.ps1 y llenar los valores. Usar comillas SIMPLES.

# Web (titulo.php): lo leen la app y el reproductor de WordPress.
$URL_TITULOS   = 'https://TU-DOMINIO/radio/titulo.php'
$CLAVE_TITULOS = 'SoloLetrasYNumerosMinimo16Caracteres'   # la misma de titulo.php

# AzuraCast (opcional, solo sirve con el AutoDJ activo). Dejar vacio para no usarlo.
$URL_AZURACAST = ''   # p. ej. 'https://a10.asurahosting.com/api/station/702/nowplaying/update'
$API_KEY       = ''

# Tambien se puede cambiar aqui cualquier otro valor del script, por ejemplo:
# $RETARDO_ENVIO = 1
