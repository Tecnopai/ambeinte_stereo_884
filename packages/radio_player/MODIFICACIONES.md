# Modificaciones locales

Copia de `radio_player` 2.2.1 (pub.dev, © Ilia Chirkunov, licencia
CC BY-NC-SA 4.0, ver `LICENSE`) incluida en el proyecto para poder ajustar la
reserva de audio en Android. Se quitaron la app de ejemplo y las pruebas.

## Cambios

- `android/.../service/RadioPlayerService.kt`: el ExoPlayer usa un
  `DefaultLoadControl` propio:
  - arranque con 2,5 s de audio (igual que antes, rápido);
  - tras un corte, junta 8 s antes de seguir sonando, para que las fallas
    cortas del internet móvil no vuelvan a cortar el audio;
  - reserva máxima de 60 s.

- `setVolume(volume)` (Dart, `RadioPlayerPlugin.kt`, `RadioPlayerPlugin.swift`
  y `RadioPlayerService.swift`): volumen del reproductor de 0 a 1, sin tocar el
  volumen del teléfono. Lo usa el apagado programado para bajar suave. En iOS
  falta probarlo en la Mac.

- Modo conexión lenta (`setSlowMode(enabled)` y `bufferedAhead()`, Dart y
  Android: `RadioPlayerPlugin.kt`, `RadioPlayerService.kt`):
  - el control de reserva es `RadioLoadControl`, una subclase de
    `DefaultLoadControl` con los mismos valores de arriba; con
    `slowMode` activo exige 10 s de audio guardado antes de sonar (al
    arrancar y tras un corte);
  - `bufferedAhead()` devuelve el audio guardado por delante
    (`totalBufferedDuration`), para que la app sepa si sigue llegando audio
    aunque sea lento y no reconecte tirando la reserva.
  - iOS (`RadioPlayerPlugin.swift`, `RadioPlayerService.swift`):
    `setSlowMode` pone `preferredForwardBufferDuration` = 10 s en el audio
    actual y en cada conexión nueva (0 = automático al desactivar), con
    `automaticallyWaitsToMinimizeStalling` activo como siempre. AVPlayer
    lo toma como sugerencia: no garantiza esperar 10 s antes de sonar como
    Android. `bufferedAhead` = final del último `loadedTimeRanges` menos
    `currentTime()`, en ms (-1 sin conexión).

Al actualizar a una versión nueva de `radio_player`, volver a aplicar estos
cambios o comprobar si la versión nueva ya permite configurarlo.
