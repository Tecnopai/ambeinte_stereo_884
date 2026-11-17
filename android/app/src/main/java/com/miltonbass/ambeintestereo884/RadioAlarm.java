package com.miltonbass.ambientestereo884;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import java.util.Calendar;

/**
 * Despertador con la radio: guarda la configuración y programa la alarma.
 *
 * Usa AlarmManager.setAlarmClock (la misma función de las apps de reloj):
 * suena aunque la app esté cerrada o el teléfono ahorrando batería, y muestra
 * el ícono de alarma en la barra. A la hora arranca AlarmService, que pone la
 * emisora sin necesitar la app abierta.
 *
 * Días: bits de lunes (1) a domingo (64). Sin días = una sola vez.
 * Todo queda en el teléfono; no se envía nada.
 */
final class RadioAlarm {
    private RadioAlarm() {}

    static final String PREFS = "radio_alarm";
    static final String KEY_ENABLED = "enabled";
    static final String KEY_HOUR = "hour";
    static final String KEY_MINUTE = "minute";
    static final String KEY_DAYS = "days";
    static final String KEY_URLS = "urls";
    static final String KEY_AUDIO = "fallback_audio";
    static final String KEY_SNOOZE = "snooze_at";
    /** Volumen del despertador, en % del volumen máximo de alarma. */
    static final String KEY_VOLUME = "volume";
    static final int DEFAULT_VOLUME = 70;

    static final long SNOOZE_MS = 5 * 60 * 1000L;

    static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    /** True si Android deja programar alarmas exactas (Android 12+ lo pide). */
    static boolean canSchedule(Context c) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true;
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        return am != null && am.canScheduleExactAlarms();
    }

    /** Próxima hora en que debe sonar (milisegundos), o -1 si está apagada. */
    static long nextTrigger(Context c) {
        SharedPreferences p = prefs(c);
        long now = System.currentTimeMillis();
        long snooze = p.getLong(KEY_SNOOZE, 0);
        long regular = -1;
        if (p.getBoolean(KEY_ENABLED, false)) {
            regular = nextRegular(p.getInt(KEY_HOUR, 6), p.getInt(KEY_MINUTE, 0),
                    p.getInt(KEY_DAYS, 0), now);
        }
        if (snooze > now && (regular < 0 || snooze < regular)) return snooze;
        return regular;
    }

    static long nextRegular(int hour, int minute, int days, long now) {
        Calendar cal = Calendar.getInstance();
        cal.setTimeInMillis(now);
        cal.set(Calendar.HOUR_OF_DAY, hour);
        cal.set(Calendar.MINUTE, minute);
        cal.set(Calendar.SECOND, 0);
        cal.set(Calendar.MILLISECOND, 0);
        if (cal.getTimeInMillis() <= now) cal.add(Calendar.DAY_OF_MONTH, 1);
        if (days == 0) return cal.getTimeInMillis();
        for (int i = 0; i < 7; i++) {
            if ((days & dayBit(cal)) != 0) return cal.getTimeInMillis();
            cal.add(Calendar.DAY_OF_MONTH, 1);
        }
        return cal.getTimeInMillis();
    }

    /** Bit del día: lunes = 1 … domingo = 64. */
    static int dayBit(Calendar cal) {
        int d = cal.get(Calendar.DAY_OF_WEEK); // domingo = 1 … sábado = 7
        int monFirst = (d + 5) % 7; // lunes = 0 … domingo = 6
        return 1 << monFirst;
    }

    /**
     * Programa (o quita) la próxima alarma según la configuración guardada.
     * Devuelve false si Android no da permiso para alarmas exactas.
     */
    static boolean schedule(Context c) {
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return false;
        PendingIntent operation = alarmIntent(c);
        long trigger = nextTrigger(c);
        if (trigger < 0) {
            am.cancel(operation);
            return true;
        }
        if (!canSchedule(c)) return false;
        AlarmManager.AlarmClockInfo info =
                new AlarmManager.AlarmClockInfo(trigger, openAppIntent(c));
        am.setAlarmClock(info, operation);
        return true;
    }

    /** Lo que se ejecuta a la hora: el servicio que pone la radio. */
    static PendingIntent alarmIntent(Context c) {
        Intent i = new Intent(c, AlarmService.class).setAction(AlarmService.ACTION_START);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return PendingIntent.getForegroundService(c, 0, i, flags);
        }
        return PendingIntent.getService(c, 0, i, flags);
    }

    /** Abrir la app (al tocar el ícono de alarma o el aviso). */
    static PendingIntent openAppIntent(Context c) {
        Intent i = new Intent(c, MainActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        return PendingIntent.getActivity(c, 1, i,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    /** "5 minutos más": vuelve a sonar en 5 minutos. */
    static void snooze(Context c) {
        prefs(c).edit().putLong(KEY_SNOOZE, System.currentTimeMillis() + SNOOZE_MS).apply();
        schedule(c);
    }

    /** Sonó: si era una sola vez, se apaga; si repite, se programa la siguiente. */
    static void afterRing(Context c) {
        SharedPreferences p = prefs(c);
        SharedPreferences.Editor e = p.edit().remove(KEY_SNOOZE);
        if (p.getInt(KEY_DAYS, 0) == 0) e.putBoolean(KEY_ENABLED, false);
        e.apply();
        schedule(c);
    }
}
