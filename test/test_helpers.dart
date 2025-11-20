// test/test_helpers.dart - SOLUCIÓN SIMPLIFICADA
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

// Mock básico para evitar inicialización de Firebase
class MockFirebase {
  static Future<void> initializeApp() async {
    // Simular inicialización exitosa
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

void setupTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Configuración global para todos los tests
    debugPrint("🛠️ Configurando entorno de tests...");
  });

  setUp(() {
    // Configuración antes de cada test
  });

  tearDown(() {
    // Limpieza después de cada test
  });
}
