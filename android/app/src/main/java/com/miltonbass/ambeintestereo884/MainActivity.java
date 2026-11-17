package com.miltonbass.ambientestereo884;

import android.app.UiModeManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Configuration;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
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
                    } else {
                        result.notImplemented();
                    }
                });
    }

    /** True en Android TV / Google TV (modo televisión o sistema "leanback"). */
    private boolean isTv() {
        UiModeManager uiMode = (UiModeManager) getSystemService(Context.UI_MODE_SERVICE);
        boolean television = uiMode != null
                && uiMode.getCurrentModeType() == Configuration.UI_MODE_TYPE_TELEVISION;
        return television || getPackageManager().hasSystemFeature(PackageManager.FEATURE_LEANBACK);
    }
}
