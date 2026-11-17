import Flutter
import Foundation
import SwiftUI
import UIKit
import UserNotifications

#if canImport(AlarmKit)
  import AlarmKit
  import AppIntents
#endif

/// Despertador con la radio en iOS. Atiende el mismo canal que la parte de
/// Android (RadioAlarm.java), así la pantalla del despertador es la misma.
///
/// Apple no deja que una app empiece a sonar sola, así que en iPhone el
/// despertador avisa y el usuario toca "Escuchar la radio", que abre la app y
/// pone la emisora:
/// - iOS 26 o superior: AlarmKit. Suena como el reloj del teléfono, aunque
///   esté en silencio o en "No molestar", con los botones "Apagar" y
///   "Escuchar la radio".
/// - iOS 15 a 25: una notificación con sonido y el mismo botón.
///
/// La configuración se guarda solo en el teléfono (UserDefaults).
final class RadioAlarmIOS: NSObject, UNUserNotificationCenterDelegate {
  static let shared = RadioAlarmIOS()

  /// Lo marca el botón "Escuchar la radio"; Dart lo lee con takeKeepListening.
  static let keepListeningKey = "despertador.seguirEscuchando"

  private let defaults = UserDefaults.standard
  private let kEnabled = "despertador.encendido"
  private let kHour = "despertador.hora"
  private let kMinute = "despertador.minuto"
  private let kDays = "despertador.dias"  // bits: lunes 1 … domingo 64
  private let kVolume = "despertador.volumen"
  private let kAlarmID = "despertador.alarmID"
  private let kTestID = "despertador.pruebaID"

  private let notificationPrefix = "despertador-"
  private let categoryID = "DESPERTADOR_RADIO"
  private let listenActionID = "ESCUCHAR_RADIO"

  private var channel: FlutterMethodChannel?

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.miltonbass.ambientestereo884/alarm", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel

    let center = UNUserNotificationCenter.current()
    center.delegate = self
    let listen = UNNotificationAction(
      identifier: listenActionID, title: "Escuchar la radio", options: [.foreground])
    center.setNotificationCategories([
      UNNotificationCategory(
        identifier: categoryID, actions: [listen], intentIdentifiers: [], options: [])
    ])
  }

  /// Avisa a Dart que se tocó "Escuchar la radio" (si la app ya estaba
  /// abierta; si no, Dart lo lee al abrir con takeKeepListening).
  func notifyKeepListening() {
    channel?.invokeMethod("keepListeningNow", arguments: nil)
  }

  // MARK: - Canal

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getConfig":
      Task { @MainActor in result(await self.configMap()) }
    case "setConfig":
      let args = call.arguments as? [String: Any] ?? [:]
      defaults.set(args["enabled"] as? Bool ?? false, forKey: kEnabled)
      defaults.set(args["hour"] as? Int ?? 6, forKey: kHour)
      defaults.set(args["minute"] as? Int ?? 0, forKey: kMinute)
      defaults.set(args["days"] as? Int ?? 0, forKey: kDays)
      defaults.set(args["volume"] as? Int ?? 70, forKey: kVolume)
      Task { @MainActor in
        await self.reschedule()
        result(nil)
      }
    case "requestNotifications":
      Task { @MainActor in
        await self.requestAuthorization()
        result(nil)
      }
    case "test":
      Task { @MainActor in
        await self.scheduleTest()
        result(nil)
      }
    case "stop":
      stopRinging()
      result(nil)
    case "isRinging":
      result(isRinging())
    case "takeKeepListening":
      let pending = defaults.bool(forKey: RadioAlarmIOS.keepListeningKey)
      defaults.set(false, forKey: RadioAlarmIOS.keepListeningKey)
      result(pending)
    case "openExactAlarmSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    case "snooze", "setStreams", "setFallbackAudio":
      // En iPhone no aplican: el sonido es el de la alarma del sistema y la
      // radio la pone la app al tocar "Escuchar la radio".
      result(nil)
    case "otherAlarm":
      // iOS no informa las alarmas de otras apps.
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Configuración

  private var enabled: Bool { defaults.bool(forKey: kEnabled) }
  private var hour: Int { defaults.object(forKey: kHour) as? Int ?? 6 }
  private var minute: Int { defaults.object(forKey: kMinute) as? Int ?? 0 }
  private var daysMask: Int { defaults.integer(forKey: kDays) }

  @MainActor
  private func configMap() async -> [String: Any] {
    // Una alarma de una sola vez que ya sonó queda apagada (como en Android).
    let exists = await scheduledAlarmExists()
    if enabled && daysMask == 0 && !exists {
      defaults.set(false, forKey: kEnabled)
    }
    let next = enabled ? nextFireDate() : nil
    return [
      "enabled": enabled,
      "hour": hour,
      "minute": minute,
      "days": daysMask,
      "volume": defaults.object(forKey: kVolume) as? Int ?? 70,
      "next": next.map { Int($0.timeIntervalSince1970 * 1000) } ?? -1,
      "canSchedule": await isAuthorized(),
    ]
  }

  /// Próxima vez que suena según la configuración (hora local).
  private func nextFireDate() -> Date? {
    let calendar = Calendar.current
    let now = Date()
    for offset in 0..<8 {
      guard let day = calendar.date(byAdding: .day, value: offset, to: now),
        let candidate = calendar.date(
          bySettingHour: hour, minute: minute, second: 0, of: day),
        candidate > now
      else { continue }
      if daysMask == 0 { return candidate }
      // weekday: domingo = 1 … sábado = 7 -> bit: lunes 0 … domingo 6
      let weekday = calendar.component(.weekday, from: candidate)
      let bit = (weekday + 5) % 7
      if daysMask & (1 << bit) != 0 { return candidate }
    }
    return nil
  }

  // MARK: - Permisos

  @MainActor
  private func requestAuthorization() async {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        _ = try? await AlarmManager.shared.requestAuthorization()
        return
      }
    #endif
    _ = try? await UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound])
  }

  @MainActor
  private func isAuthorized() async -> Bool {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        return AlarmManager.shared.authorizationState != .denied
      }
    #endif
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    return settings.authorizationStatus != .denied
  }

  // MARK: - Programar

  @MainActor
  private func reschedule() async {
    cancelScheduled()
    guard enabled else { return }
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        await scheduleWithAlarmKit()
        return
      }
    #endif
    scheduleNotifications()
  }

  private func cancelScheduled() {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *),
        let raw = defaults.string(forKey: kAlarmID), let id = UUID(uuidString: raw)
      {
        try? AlarmManager.shared.cancel(id: id)
        defaults.removeObject(forKey: kAlarmID)
      }
    #endif
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.notificationPrefix) }
      center.removePendingNotificationRequests(withIdentifiers: ids)
    }
  }

  @MainActor
  private func scheduledAlarmExists() async -> Bool {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        guard let raw = defaults.string(forKey: kAlarmID), let id = UUID(uuidString: raw)
        else { return false }
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        return alarms.contains { $0.id == id }
      }
    #endif
    let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
    return pending.contains { $0.identifier.hasPrefix(notificationPrefix) }
  }

  /// iOS 15 a 25: una notificación por día marcado (o una sola vez).
  private func scheduleNotifications() {
    let content = UNMutableNotificationContent()
    content.title = "Ambiente Stereo 88.4"
    content.body = "Buenos días. Toca \"Escuchar la radio\" para poner la emisora."
    content.sound = .default
    content.categoryIdentifier = categoryID

    let center = UNUserNotificationCenter.current()
    var weekdays: [Int?] = []
    if daysMask == 0 {
      weekdays = [nil]
    } else {
      for bit in 0..<7 where daysMask & (1 << bit) != 0 {
        weekdays.append((bit + 1) % 7 + 1)  // lunes(0) -> 2 … domingo(6) -> 1
      }
    }
    for weekday in weekdays {
      var date = DateComponents()
      date.hour = hour
      date.minute = minute
      date.weekday = weekday
      let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: weekday != nil)
      let id = notificationPrefix + (weekday.map { String($0) } ?? "una-vez")
      center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
  }

  // MARK: - AlarmKit (iOS 26+)

  #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func alarmAttributes() -> AlarmAttributes<RadioAlarmMetadata> {
      let alert = AlarmPresentation.Alert(
        title: "Ambiente Stereo 88.4",
        stopButton: AlarmButton(
          text: "Apagar", textColor: .white, systemImageName: "stop.circle"),
        secondaryButton: AlarmButton(
          text: "Escuchar la radio", textColor: .white, systemImageName: "radio"),
        secondaryButtonBehavior: .custom)
      return AlarmAttributes(
        presentation: AlarmPresentation(alert: alert),
        metadata: RadioAlarmMetadata(),
        tintColor: Color(red: 0.235, green: 0.686, blue: 0.235))
    }

    @available(iOS 26.0, *)
    @MainActor
    private func scheduleWithAlarmKit() async {
      var weekdays: [Locale.Weekday] = []
      let all: [Locale.Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
      ]
      for (bit, day) in all.enumerated() where daysMask & (1 << bit) != 0 {
        weekdays.append(day)
      }
      let relative = Alarm.Schedule.Relative(
        time: .init(hour: hour, minute: minute),
        repeats: weekdays.isEmpty ? .never : .weekly(weekdays))
      let id = UUID()
      do {
        _ = try await AlarmManager.shared.schedule(
          id: id,
          configuration: .alarm(
            schedule: .relative(relative),
            attributes: alarmAttributes(),
            secondaryIntent: EscucharRadioIntent(alarmID: id.uuidString)))
        defaults.set(id.uuidString, forKey: kAlarmID)
      } catch {
        NSLog("Despertador: no se pudo programar con AlarmKit: \(error)")
      }
    }
  #endif

  // MARK: - Prueba, sonando y detener

  /// Suena en 5 segundos, para probar (no cambia la configuración).
  @MainActor
  private func scheduleTest() async {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        let id = UUID()
        do {
          _ = try await AlarmManager.shared.schedule(
            id: id,
            configuration: .alarm(
              schedule: .fixed(Date().addingTimeInterval(5)),
              attributes: alarmAttributes(),
              secondaryIntent: EscucharRadioIntent(alarmID: id.uuidString)))
          defaults.set(id.uuidString, forKey: kTestID)
        } catch {
          NSLog("Despertador: no se pudo programar la prueba: \(error)")
        }
        return
      }
    #endif
    let content = UNMutableNotificationContent()
    content.title = "Ambiente Stereo 88.4"
    content.body = "Prueba del despertador. Toca \"Escuchar la radio\"."
    content.sound = .default
    content.categoryIdentifier = categoryID
    try? await UNUserNotificationCenter.current().add(
      UNNotificationRequest(
        identifier: notificationPrefix + "prueba", content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
  }

  private func isRinging() -> Bool {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        return alarms.contains { $0.state == .alerting }
      }
    #endif
    return false
  }

  private func stopRinging() {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        for alarm in alarms where alarm.state == .alerting {
          try? AlarmManager.shared.stop(id: alarm.id)
        }
        if let raw = defaults.string(forKey: kTestID), let id = UUID(uuidString: raw) {
          try? AlarmManager.shared.cancel(id: id)
          defaults.removeObject(forKey: kTestID)
        }
      }
    #endif
    UNUserNotificationCenter.current().removeDeliveredNotifications(
      withIdentifiers: [notificationPrefix + "prueba"])
  }

  // MARK: - Notificaciones (iOS 15 a 25)

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // El botón "Escuchar la radio" o tocar el aviso: se pone la radio.
    if response.notification.request.identifier.hasPrefix(notificationPrefix) {
      defaults.set(true, forKey: RadioAlarmIOS.keepListeningKey)
      notifyKeepListening()
    }
    completionHandler()
  }
}

#if canImport(AlarmKit)
  @available(iOS 26.0, *)
  struct RadioAlarmMetadata: AlarmMetadata {}

  /// Botón "Escuchar la radio" de la alarma: abre la app y marca que hay que
  /// poner la emisora.
  @available(iOS 26.0, *)
  struct EscucharRadioIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Escuchar la radio"
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Alarma")
    var alarmID: String

    init() { self.alarmID = "" }
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
      UserDefaults.standard.set(true, forKey: RadioAlarmIOS.keepListeningKey)
      await MainActor.run { RadioAlarmIOS.shared.notifyKeepListening() }
      return .result()
    }
  }
#endif
