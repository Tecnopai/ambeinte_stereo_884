# Reglas de R8 para la versión publicada (optimización activa).
# Flutter y los plugins traen sus propias reglas; aquí solo lo de la app.

# Código nativo de la app (despertador, canales con Dart): se usa desde el
# manifiesto y por nombre de canal; no renombrar ni quitar.
-keep class com.miltonbass.ambeintestereo884.** { *; }

# Reproductor de la radio (copia local de radio_player): servicio de medios
# que Android crea por nombre.
-keep class com.cheebeez.radio_player.** { *; }

# ExoPlayer / Media3 se carga en parte por reflexión.
-dontwarn androidx.media3.**
