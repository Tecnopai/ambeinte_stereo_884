package com.miltonbass.ambeinte_stereo_884

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.os.PowerManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.os.Build

/**
 * Actividad principal de Android que extiende FlutterActivity.
 *
 * Esta clase gestiona configuraciones nativas críticas para el streaming de audio en segundo plano:
 * 1. Mantiene un [PowerManager.WakeLock] para asegurar que la CPU no duerma.
 * 2. Solicita al usuario que ignore las optimizaciones de batería (Doze Mode).
 * 3. Expone métodos nativos a Flutter (vía MethodChannel) para el control del Wake Lock.
 */
class MainActivity: FlutterActivity() {
    // Variable para mantener una referencia al Wake Lock de la CPU.
    private var wakeLock: PowerManager.WakeLock? = null
    // Nombre del canal de comunicación usado para interactuar con Dart/Flutter.
    private val CHANNEL = "com.miltonbass.ambeinte_stereo_884/wakelock"

    /**
     * Llamado cuando la actividad es creada.
     * @param savedInstanceState Datos de estado previamente guardados.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Adquirir wake lock para mantener CPU activa durante streaming y evitar que el sistema la suspenda.
        acquireWakeLock()
        
        // Solicitar ignorar optimizaciones de batería para asegurar la continuidad del audio en segundo plano.
        requestIgnoreBatteryOptimizations()
    }

    /**
     * Configura el motor de Flutter y establece el canal de comunicación nativo.
     * @param flutterEngine El motor de Flutter asociado a esta actividad.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // super DEBE ser lo primero para que audio_service funcione
        super.configureFlutterEngine(flutterEngine)
        
        // Configuración del MethodChannel para que Flutter pueda solicitar la gestión del Wake Lock.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Llama al método nativo para adquirir el bloqueo de activación.
                "acquireWakeLock" -> {
                    acquireWakeLock()
                    result.success(true)
                }
                // Llama al método nativo para liberar el bloqueo de activación.
                "releaseWakeLock" -> {
                    releaseWakeLock()
                    result.success(true)
                }
                // Maneja llamadas a métodos no implementados.
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Adquiere un PowerManager.PARTIAL_WAKE_LOCK para mantener la CPU despierta.
     * Esto es fundamental para que el streaming de audio no se corte cuando el dispositivo está inactivo.
     */
    private fun acquireWakeLock() {
        if (wakeLock == null || wakeLock?.isHeld == false) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            // PARTIAL_WAKE_LOCK mantiene la CPU encendida, pero permite que la pantalla se apague.
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "AmbienteStereo::StreamingWakeLock" // Etiqueta para el log del sistema.
            )
            wakeLock?.acquire()
        }
    }

    /**
     * Libera el Wake Lock si está actualmente retenido.
     * Esto debe hacerse para evitar el consumo innecesario de batería.
     */
    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release() // Libera el bloqueo.
            }
        }
        wakeLock = null // Limpia la referencia.
    }

    /**
     * Solicita la exclusión de las optimizaciones de batería (Doze Mode) al usuario.
     * Esto previene que Android detenga la app en segundo plano debido al ahorro de energía.
     */
    private fun requestIgnoreBatteryOptimizations() {
        // Solo aplica para Android Marshmallow (6.0) o superior.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = packageName
            
            // Verifica si la app ya ha sido excluida.
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    // Crea un Intent para abrir la configuración de exclusión.
                    val intent = Intent().apply {
                        action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                } catch (e: Exception) {
                    }
            }
        }
    }

    /**
     * Llamado cuando la actividad está a punto de ser destruida.
     */
    override fun onDestroy() {
        // Asegura que el wake lock se libere para evitar el drenaje de batería al cerrar la app.
        releaseWakeLock()
        super.onDestroy()
    }

    /**
     * Llamado cuando la actividad entra en pausa.
     */
    override fun onPause() {
        super.onPause()
        // NOTA: No liberamos el wake lock aquí, ya que queremos que el audio se siga reproduciendo en segundo plano.
    }

    /**
     * Llamado cuando la actividad vuelve al primer plano.
     */
    override fun onResume() {
        super.onResume()
        // Asegura que el wake lock esté activo cuando la app vuelve al frente.
        acquireWakeLock()
    }
}
