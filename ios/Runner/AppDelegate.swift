import AVFoundation
import Flutter
import MediaPlayer
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // El plugin volume_controller pone la sesión en `.mixWithOthers` al escuchar el
    // volumen y al volver a primer plano. Con esa opción iOS no trata a la app como
    // "Now Playing" y oculta los controles de la pantalla de bloqueo. Este canal
    // permite a Dart restaurar la sesión de reproducción exclusiva.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AudioSessionFix") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.miltonbass.ambientestereo884/audio_session",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setExclusivePlayback" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let session = AVAudioSession.sharedInstance()
        // Devuelve true solo si hubo que cambiar la categoría: ese cambio puede
        // pausar el AVPlayer, y Dart lo reanuda.
        var changed = false
        if session.category != .playback || !session.categoryOptions.isEmpty {
          try session.setCategory(.playback, mode: .default, options: [])
          changed = true
        }
        try session.setActive(true)
        result(changed)
      } catch {
        result(FlutterError(code: "AUDIO_SESSION", message: error.localizedDescription, details: nil))
      }
    }

    // radio_player pausa el AVPlayer directamente desde la pantalla de bloqueo, sin
    // pasar por Dart, y AudioPlayerManager lo confundiría con una caída de red y
    // reconectaría. Se avisa a Dart que la pausa fue del usuario. (Los targets
    // adicionales se ejecutan junto con los del plugin.)
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.pauseCommand.addTarget { _ in
      channel.invokeMethod("remotePause", arguments: nil)
      return .success
    }
  }
}
