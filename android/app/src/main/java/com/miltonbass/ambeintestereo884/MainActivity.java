package com.miltonbass.ambientestereo884;

import android.Manifest;
import android.app.AlarmManager;
import android.app.UiModeManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String DEVICE_CHANNEL = "com.miltonbass.ambientestereo884/device";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        // Indica a Flutter si la app corre en un televisor (Android TV /
        // Google TV), para mostrar la interfaz pensada para el control remoto.
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), DEVICE_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("isTv".equals(call.method)) {
                        result.success(isTv());
                    } else if ("keepScreenOn".equals(call.method)) {
                        // En TV, mientras suena el audio, que el televisor no
                        // ponga el protector de pantalla ni se apague.
                        boolean on = Boolean.TRUE.equals(call.arguments);
                        runOnUiThread(() -> {
                            if (on) {
                                getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                            } else {
                                getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                            }
                        });
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), ALARM_CHANNEL)
                .setMethodCallHandler(this::onAlarmCall);
    }

    // ===== Despertador con la radio (ver RadioAlarm / AlarmService) =====

    private static final String ALARM_CHANNEL = "com.miltonbass.ambientestereo884/alarm";

    /** Botón "Seguir escuchando" del aviso del despertador. */
    static final String ACTION_KEEP_LISTENING = "com.miltonbass.ambientestereo884.KEEP_LISTENING";

    /** Pendiente para Dart: poner la radio normal al abrir la app. */
    private static boolean keepListening = false;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        handleAlarmIntent(getIntent());
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        handleAlarmIntent(intent);
    }

    /**
     * "Seguir escuchando": la app pone la radio y, cuando ya suena, apaga el
     * despertador (así no queda un silencio mientras la app se conecta).
     */
    private void handleAlarmIntent(@Nullable Intent intent) {
        if (intent == null || !ACTION_KEEP_LISTENING.equals(intent.getAction())) return;
        keepListening = true;
    }

    private void onAlarmCall(MethodCall call, MethodChannel.Result result) {
        SharedPreferences p = RadioAlarm.prefs(this);
        switch (call.method) {
            case "getConfig": {
                Map<String, Object> m = new HashMap<>();
                m.put("enabled", p.getBoolean(RadioAlarm.KEY_ENABLED, false));
                m.put("hour", p.getInt(RadioAlarm.KEY_HOUR, 6));
                m.put("minute", p.getInt(RadioAlarm.KEY_MINUTE, 0));
                m.put("days", p.getInt(RadioAlarm.KEY_DAYS, 0));
                m.put("volume", p.getInt(RadioAlarm.KEY_VOLUME, RadioAlarm.DEFAULT_VOLUME));
                m.put("next", RadioAlarm.nextTrigger(this));
                m.put("canSchedule", RadioAlarm.canSchedule(this));
                result.success(m);
                break;
            }
            case "setConfig": {
                Boolean enabled = call.argument("enabled");
                Integer hour = call.argument("hour");
                Integer minute = call.argument("minute");
                Integer days = call.argument("days");
                Integer volume = call.argument("volume");
                p.edit()
                        .putInt(RadioAlarm.KEY_VOLUME,
                                volume != null ? volume : RadioAlarm.DEFAULT_VOLUME)
                        .putBoolean(RadioAlarm.KEY_ENABLED, Boolean.TRUE.equals(enabled))
                        .putInt(RadioAlarm.KEY_HOUR, hour != null ? hour : 6)
                        .putInt(RadioAlarm.KEY_MINUTE, minute != null ? minute : 0)
                        .putInt(RadioAlarm.KEY_DAYS, days != null ? days : 0)
                        .remove(RadioAlarm.KEY_SNOOZE)
                        .apply();
                boolean ok = RadioAlarm.schedule(this);
                Map<String, Object> r = new HashMap<>();
                r.put("ok", ok);
                r.put("next", RadioAlarm.nextTrigger(this));
                result.success(r);
                break;
            }
            case "setStreams": {
                List<String> urls = call.argument("urls");
                p.edit().putString(RadioAlarm.KEY_URLS,
                        urls == null ? "" : TextUtils.join("\n", urls)).apply();
                result.success(null);
                break;
            }
            case "setFallbackAudio": {
                String path = call.argument("path");
                SharedPreferences.Editor e = p.edit();
                if (path == null) e.remove(RadioAlarm.KEY_AUDIO);
                else e.putString(RadioAlarm.KEY_AUDIO, path);
                e.apply();
                result.success(null);
                break;
            }
            case "openExactAlarmSettings": {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    Intent i = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:" + getPackageName()));
                    startActivity(i);
                }
                result.success(null);
                break;
            }
            case "requestNotifications": {
                // Android 13+: sin este permiso no se ve el aviso con "Apagar".
                if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(
                        Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 884);
                }
                result.success(null);
                break;
            }
            case "test": {
                Intent i = new Intent(this, AlarmService.class).setAction(AlarmService.ACTION_TEST);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i);
                else startService(i);
                result.success(null);
                break;
            }
            case "stop": {
                Intent i = new Intent(this, AlarmService.class).setAction(AlarmService.ACTION_STOP);
                startService(i);
                result.success(null);
                break;
            }
            case "snooze": {
                Intent i = new Intent(this, AlarmService.class).setAction(AlarmService.ACTION_SNOOZE);
                startService(i);
                result.success(null);
                break;
            }
            case "isRinging":
                result.success(AlarmService.ringing);
                break;
            case "otherAlarm": {
                // Próxima alarma del teléfono si es de OTRA app (por ejemplo,
                // el reloj), para avisar que sonarían las dos. Android solo
                // informa la próxima, no todas.
                AlarmManager am = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
                AlarmManager.AlarmClockInfo next = am != null ? am.getNextAlarmClock() : null;
                if (next == null) {
                    result.success(null);
                    break;
                }
                String owner = next.getShowIntent() != null
                        ? next.getShowIntent().getCreatorPackage() : null;
                if (getPackageName().equals(owner)) {
                    result.success(null);
                    break;
                }
                Map<String, Object> m = new HashMap<>();
                m.put("time", next.getTriggerTime());
                result.success(m);
                break;
            }
            case "takeKeepListening": {
                boolean v = keepListening;
                keepListening = false;
                result.success(v);
                break;
            }
            default:
                result.notImplemented();
        }
    }

    /** True en Android TV / Google TV (modo televisión o sistema "leanback"). */
    private boolean isTv() {
        UiModeManager uiMode = (UiModeManager) getSystemService(Context.UI_MODE_SERVICE);
        boolean television = uiMode != null
                && uiMode.getCurrentModeType() == Configuration.UI_MODE_TYPE_TELEVISION;
        return television || getPackageManager().hasSystemFeature(PackageManager.FEATURE_LEANBACK);
    }
}
