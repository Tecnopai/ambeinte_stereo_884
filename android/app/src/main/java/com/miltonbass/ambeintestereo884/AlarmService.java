package com.miltonbass.ambientestereo884;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.media3.common.AudioAttributes;
import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.exoplayer.ExoPlayer;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

/**
 * Suena el despertador: pone la emisora por su cuenta (sin necesitar la app
 * abierta), con el volumen de ALARMA del teléfono y subiendo poco a poco.
 *
 * Si en 20 s la radio no suena (sin internet, servidor caído), prueba el
 * siguiente servidor y al final un audio de respaldo (el de Firebase, si se
 * descargó, o el tono de la app), para que nadie se quede dormido.
 * Aviso con "Apagar", "5 min más" y "Seguir escuchando". Suena hasta que el
 * usuario lo apague (la prueba se apaga sola a los 30 s).
 */
public class AlarmService extends Service {
    static final String ACTION_START = "com.miltonbass.ambientestereo884.ALARM_START";
    static final String ACTION_STOP = "com.miltonbass.ambientestereo884.ALARM_STOP";
    static final String ACTION_SNOOZE = "com.miltonbass.ambientestereo884.ALARM_SNOOZE";
    static final String ACTION_TEST = "com.miltonbass.ambientestereo884.ALARM_TEST";

    private static final String CHANNEL = "despertador";
    private static final int NOTIFICATION_ID = 884;
    private static final long TRY_MS = 20_000;
    private static final float START_VOLUME = 0.15f;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private ExoPlayer player;
    private final List<String> urls = new ArrayList<>();
    private int urlIndex = 0;
    private boolean onFallback = false;
    private float volume = START_VOLUME;

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent != null ? intent.getAction() : null;
        if (ACTION_STOP.equals(action)) {
            finish(false);
            return START_NOT_STICKY;
        }
        if (ACTION_SNOOZE.equals(action)) {
            finish(true);
            return START_NOT_STICKY;
        }
        // ACTION_START (la alarma) o ACTION_TEST ("Probar ahora").
        boolean test = ACTION_TEST.equals(action);
        startForegroundNow(test);
        if (player == null) {
            // Alarma de verdad: se programa ya la siguiente (si repite), por
            // si algo falla. La prueba no toca la configuración y se apaga
            // sola a los 30 s, para que nadie quede con la radio sonando sin
            // saber por qué.
            if (!test) RadioAlarm.afterRing(this);
            startRinging();
            if (test) handler.postDelayed(() -> finish(false), TEST_MS);
        }
        return START_NOT_STICKY;
    }

    /** True mientras suena (la app muestra el aviso para apagarlo). */
    static volatile boolean ringing = false;

    private static final long TEST_MS = 30_000;

    private void startForegroundNow(boolean test) {
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm != null) {
            NotificationChannel ch = new NotificationChannel(CHANNEL, "Despertador",
                    NotificationManager.IMPORTANCE_HIGH);
            ch.setDescription("Despertador con la radio");
            ch.setSound(null, null); // el sonido es la radio
            nm.createNotificationChannel(ch);
        }
        Notification n = new NotificationCompat.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(test
                        ? "Prueba del despertador"
                        : "Buenos días · Ambiente Stereo 88.4")
                .setContentText(test
                        ? "Se apaga sola en 30 segundos"
                        : "Tu despertador con la radio")
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setOngoing(true)
                // Tocar el aviso = "Seguir escuchando": se quita el aviso y
                // queda solo la radio de la app (antes sonaban las dos).
                .setContentIntent(keepListeningIntent())
                .addAction(0, "Apagar", actionIntent(ACTION_STOP, 2))
                .addAction(0, "5 min más", actionIntent(ACTION_SNOOZE, 3))
                .addAction(0, "Seguir escuchando", keepListeningIntent())
                .build();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        } else {
            startForeground(NOTIFICATION_ID, n);
        }
    }

    /**
     * "Seguir escuchando": abre la app, que apaga el modo alarma y pone la
     * radio normal (volumen de multimedia, apagado programado, etc.).
     */
    private PendingIntent keepListeningIntent() {
        Intent i = new Intent(this, MainActivity.class)
                .setAction(MainActivity.ACTION_KEEP_LISTENING)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        return PendingIntent.getActivity(this, 4, i,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private PendingIntent actionIntent(String action, int code) {
        Intent i = new Intent(this, AlarmService.class).setAction(action);
        return PendingIntent.getService(this, code, i,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private void startRinging() {
        // Volumen elegido por el usuario: se pone el volumen de alarma del
        // teléfono en ese nivel y al apagar se deja como estaba (no cambia
        // sus otras alarmas). Nunca en cero: un despertador mudo no sirve.
        AudioManager am = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        if (am != null) {
            int max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM);
            int pct = RadioAlarm.prefs(this).getInt(RadioAlarm.KEY_VOLUME, RadioAlarm.DEFAULT_VOLUME);
            int target = Math.max(1, Math.round(max * pct / 100f));
            previousAlarmVolume = am.getStreamVolume(AudioManager.STREAM_ALARM);
            try {
                am.setStreamVolume(AudioManager.STREAM_ALARM, target, 0);
            } catch (SecurityException ignored) {
                // "No molestar" puede impedir cambiarlo: suena con el actual.
            }
        }

        ringing = true;
        String saved = RadioAlarm.prefs(this).getString(RadioAlarm.KEY_URLS, "");
        for (String u : saved.split("\n")) {
            if (!u.trim().isEmpty()) urls.add(u.trim());
        }

        player = new ExoPlayer.Builder(this).build();
        player.setAudioAttributes(new AudioAttributes.Builder()
                .setUsage(C.USAGE_ALARM)
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                .build(), false);
        player.setWakeMode(C.WAKE_MODE_NETWORK);
        player.setVolume(volume);
        player.addListener(new Player.Listener() {
            @Override
            public void onPlayerError(PlaybackException error) {
                handler.post(AlarmService.this::nextSource);
            }
        });

        if (urls.isEmpty()) {
            playFallback();
        } else {
            playUrl(0);
        }
        handler.postDelayed(rampUp, 1000);
        // Sigue sonando hasta que el usuario lo apague (decisión del usuario).
    }

    private void playUrl(int index) {
        urlIndex = index;
        player.setMediaItem(MediaItem.fromUri(urls.get(index)));
        player.setRepeatMode(Player.REPEAT_MODE_OFF);
        player.prepare();
        player.play();
        handler.removeCallbacks(checkPlaying);
        handler.postDelayed(checkPlaying, TRY_MS);
    }

    /** Si no está sonando a tiempo, se pasa a la siguiente opción. */
    private final Runnable checkPlaying = () -> {
        if (player == null || onFallback) return;
        if (!player.isPlaying()) nextSource();
    };

    private void nextSource() {
        if (player == null || onFallback) return;
        if (urlIndex + 1 < urls.size()) {
            playUrl(urlIndex + 1);
        } else {
            playFallback();
        }
    }

    private void playFallback() {
        onFallback = true;
        handler.removeCallbacks(checkPlaying);
        String path = RadioAlarm.prefs(this).getString(RadioAlarm.KEY_AUDIO, null);
        Uri uri = null;
        if (path != null && new File(path).exists()) uri = Uri.fromFile(new File(path));
        if (uri == null) {
            uri = Uri.parse("android.resource://" + getPackageName() + "/" + R.raw.alarma_tono);
        }
        player.setMediaItem(MediaItem.fromUri(uri));
        player.setRepeatMode(Player.REPEAT_MODE_ALL);
        player.prepare();
        player.play();
    }

    /** Sube el volumen poco a poco (unos 20 s hasta el 100 %). */
    private final Runnable rampUp = new Runnable() {
        @Override
        public void run() {
            if (player == null) return;
            volume = Math.min(1f, volume + 0.045f);
            player.setVolume(volume);
            if (volume < 1f) handler.postDelayed(this, 1000);
        }
    };

    /** Volumen de alarma que tenía el teléfono antes de sonar (-1 = no se cambió). */
    private int previousAlarmVolume = -1;

    private void restoreAlarmVolume() {
        if (previousAlarmVolume < 0) return;
        AudioManager am = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        try {
            if (am != null) am.setStreamVolume(AudioManager.STREAM_ALARM, previousAlarmVolume, 0);
        } catch (SecurityException ignored) {
        }
        previousAlarmVolume = -1;
    }

    private void finish(boolean snooze) {
        ringing = false;
        handler.removeCallbacksAndMessages(null);
        if (player != null) {
            player.release();
            player = null;
        }
        restoreAlarmVolume();
        if (snooze) RadioAlarm.snooze(this);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE);
        } else {
            stopForeground(true);
        }
        stopSelf();
    }

    @Override
    public void onDestroy() {
        ringing = false;
        handler.removeCallbacksAndMessages(null);
        if (player != null) {
            player.release();
            player = null;
        }
        restoreAlarmVolume();
        super.onDestroy();
    }
}
