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

Al actualizar a una versión nueva de `radio_player`, volver a aplicar estos
cambios o comprobar si la versión nueva ya permite configurarlo.
