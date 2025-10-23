import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// Este Widget ejecuta una prueba de conexión a Firebase Analytics.
class FirebaseConnectionCheckScreen extends StatelessWidget {
  const FirebaseConnectionCheckScreen({super.key});

  // Función que envía un evento de prueba a Firebase Analytics
  void _sendTestEvent() {
    try {
      // 1. Enviamos el evento de prueba
      FirebaseAnalytics.instance.logEvent(
        name: 'flutter_app_connected',
        parameters: {
          'test_type': 'initial_setup',
          'success_time': DateTime.now().toIso8601String(),
        },
      );
      // 2. Imprimimos el resultado en la consola local (para depuración)
      debugPrint(
        "✅ Evento 'flutter_app_connected' enviado a Firebase Analytics.",
      );
    } catch (e) {
      // 3. Manejamos errores si algo falla
      debugPrint("❌ ERROR al intentar enviar el evento de Analytics: $e");
    }
  }

  // Función que muestra una notificación en pantalla (sustituto de alert())
  void _showSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Evento de prueba enviado. Revisa Firebase Console -> DebugView.',
        ),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prueba de Conexión Firebase"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.cloud_done, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text(
                "Verifica la conexión con Firebase Console",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  _sendTestEvent();
                  _showSnackbar(context);
                },
                icon: const Icon(Icons.send),
                label: const Text(
                  "Enviar Evento de Prueba a Analytics",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "Instrucciones:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                "1. Ejecuta la app y presiona el botón.\n2. Abre Firebase Console.\n3. Ve a Analytics -> DebugView.\n4. Si la conexión funciona, verás el evento 'flutter_app_connected'.",
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
