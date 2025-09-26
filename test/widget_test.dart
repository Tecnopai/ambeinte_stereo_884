import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Importar la clase desde el archivo correcto
import 'package:ambeinte_stereo_884/core/app.dart';

void main() {
  testWidgets('App loads correctly smoke test', (WidgetTester tester) async {
    // Ahora sí puede encontrar AmbientStereoApp
    await tester.pumpWidget(const AmbientStereoApp());

    // Esperar a que termine el splash screen
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Test básico - verificar que la app carga
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('Splash screen appears', (WidgetTester tester) async {
    await tester.pumpWidget(const AmbientStereoApp());

    // Verificar que aparece el splash screen inicialmente
    expect(find.text('Ambient Stereo'), findsOneWidget);
    expect(find.text('88.4 FM'), findsOneWidget);
    expect(find.text('Cargando...'), findsOneWidget);
  });

  testWidgets('Navigation works after splash', (WidgetTester tester) async {
    await tester.pumpWidget(const AmbientStereoApp());

    // Esperar que termine el splash
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Verificar que llegamos al main screen con navegación
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
