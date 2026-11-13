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
      // Tras una interrupción sin aviso de fin (típico de Siri): indica si otro
      // audio del sistema sigue sonando, para saber cuándo reanudar la radio.
      if call.method == "isOtherAudioPlaying" {
        let session = AVAudioSession.sharedInstance()
        result(session.isOtherAudioPlaying || session.secondaryAudioShouldBeSilencedHint)
        return
      }
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

    // Al reanudar desde la pantalla de bloqueo, radio_player reutiliza la
    // conexión anterior al stream, que el servidor ya cerró tras la pausa, y
    // queda "conectando" sin fin. Se avisa a Dart para que abra una conexión
    // nueva y vigile la carga igual que con el botón de play de la app.
    commandCenter.playCommand.addTarget { _ in
      channel.invokeMethod("remotePlay", arguments: nil)
      return .success
    }

    // Interrupciones del sistema (Siri, llamadas, notas de voz, alarmas): iOS
    // pausa el audio y al terminar solo lo reanuda si marca "shouldResume", lo
    // que Siri a veces no hace. Se avisa a Dart, que decide reanudar la radio.
    NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { notification in
      guard let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
        return
      }
      switch type {
      case .began:
        channel.invokeMethod("interruptionBegan", arguments: nil)
      case .ended:
        let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
          .contains(.shouldResume)
        channel.invokeMethod("interruptionEnded", arguments: ["shouldResume": shouldResume])
      @unknown default:
        break
      }
    }
  }
}
