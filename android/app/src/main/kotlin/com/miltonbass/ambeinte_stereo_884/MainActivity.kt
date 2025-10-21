package com.miltonbass.ambeinte_stereo_884

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.os.PowerManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.os.Build

class MainActivity: AudioServiceActivity() {
    private var wakeLock: PowerManager.WakeLock? = null
    private val CHANNEL = "com.miltonbass.ambeinte_stereo_884/wakelock"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // ✅ Adquirir wake lock para mantener CPU activa durante streaming
        acquireWakeLock()
        
        // ✅ Solicitar ignorar optimizaciones de batería
        requestIgnoreBatteryOptimizations()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Canal para controlar wake lock desde Flutter (opcional)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireWakeLock" -> {
                    acquireWakeLock()
                    result.success(true)
                }
                "releaseWakeLock" -> {
                    releaseWakeLock()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Adquiere un PARTIAL_WAKE_LOCK para mantener la CPU activa
     * durante la reproducción de streaming en segundo plano
     */
    private fun acquireWakeLock() {
        if (wakeLock == null || wakeLock?.isHeld == false) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "AmbienteStereo::StreamingWakeLock"
            )
            // ✅ Acquire indefinidamente (se libera manualmente)
            wakeLock?.acquire()
        }
    }

    /**
     * Libera el wake lock
     */
    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }

    /**
     * Solicita al usuario que ignore las optimizaciones de batería
     * Esto evita que Android mate la app en Doze Mode
     */
    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = packageName
            
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    val intent = Intent().apply {
                        action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                } catch (e: Exception) {
                    // Si falla, no es crítico
                    e.printStackTrace()
                }
            }
        }
    }

    override fun onDestroy() {
        // Liberar wake lock solo cuando se destruye completamente la app
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onPause() {
        super.onPause()
        // ✅ IMPORTANTE: NO liberar el wake lock aquí
        // Queremos que el audio siga en segundo plano
    }

    override fun onResume() {
        super.onResume()
        // Asegurar que el wake lock sigue activo al volver
        acquireWakeLock()
    }
}