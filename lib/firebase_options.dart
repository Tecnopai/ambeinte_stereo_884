// Archivo generado por FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones de configuración de Firebase por defecto para la aplicación
///
/// Este archivo es generado automáticamente por FlutterFire CLI y contiene
/// las credenciales necesarias para inicializar Firebase en diferentes plataformas.
///
/// Ejemplo de uso:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  /// Obtiene las opciones de Firebase según la plataforma actual
  ///
  /// Retorna automáticamente la configuración correcta para Android o iOS.
  /// Lanza un error si se intenta usar en plataformas no configuradas.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Configuración de Firebase para Android
  ///
  /// Contiene las credenciales del proyecto Firebase para la plataforma Android
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDlsrmITnkoNNs8ELokRJRNo2X9zQjo63I',
    appId: '1:690975362924:android:ff40ef4354b8a7ec782d49',
    messagingSenderId: '690975362924',
    projectId: 'as884-b3934',
    storageBucket: 'as884-b3934.firebasestorage.app',
  );

  /// Configuración de Firebase para iOS
  ///
  /// Contiene las credenciales del proyecto Firebase para la plataforma iOS
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDXxt8pWMxhMU6UvGMJy4ZJgwexYYS49kI',
    appId: '1:690975362924:ios:d9966473406f0c20782d49',
    messagingSenderId: '690975362924',
    projectId: 'as884-b3934',
    storageBucket: 'as884-b3934.firebasestorage.app',
    iosBundleId: 'com.miltonbass.ambeintestereo884.ambeinteStereo884',
  );
}
