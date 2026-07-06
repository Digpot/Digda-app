import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // APNs 등록 결과를 보관해 Dart 진단/재적용에 노출한다.
  // didRegister 가 끝내 안 불리면 둘 다 nil → "APNs 미응답", error 가 차 있으면
  // "등록 실패(사유)" 로 서버에서 구분할 수 있다.
  private var apnsDeviceToken: Data?
  private var apnsError: String?
  // Dart 와 통신할 채널을 강하게 잡아 둔다(미보유 시 즉시 해제됨).
  private var apnsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // APNs 등록을 명시적으로 시작한다. firebase_messaging 의 requestPermission 이
    // 내부적으로 호출하도록 돼 있지만, 신형 implicit-engine AppDelegate 에선 그 경로가
    // 빗나가 registerForRemoteNotifications 자체가 호출되지 않아 APNs 토큰이 끝까지
    // 안 오는 경우가 있다(안드로이드는 정상, iOS 만 /devices 미등록). 여기서 직접
    // 호출해 APNs 왕복을 보장하면 아래 didRegister... 가 토큰을 받아 FCM 에 넘긴다.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APNs 디바이스 토큰을 FCM 으로 직접 전달한다.
  // 신형 implicit-engine AppDelegate 환경에선 firebase_messaging 이 의존하는
  // Firebase 의 AppDelegate 프록시 스위즐링이 빗나가, APNs 토큰이 Messaging 에
  // 닿지 않아 getAPNSToken()/getToken() 이 끝까지 null → iOS 가 /devices 등록을
  // 못 했다(안드로이드만 devices 테이블에 들어오던 원인). 여기서 명시적으로 넘겨
  // 토큰 발급을 보장한다. super 호출로 다른 플러그인 포워딩도 유지한다.
  //
  // 단, 이 콜백이 Dart 의 Firebase.initializeApp 완료 전에 불리면
  // Messaging.messaging() 이 아직 구성 전이라 apnsToken 적용이 유실될 수 있다.
  // 그래서 토큰을 보관해 두고, Dart 가 초기화 완료 후 "sync" 를 호출할 때 다시
  // 적용한다(아래 채널 핸들러). 기기/콜드스타트 타이밍 편차로 일부 기기만
  // apns=NULL 이 되던 레이스를 차단한다.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    NSLog("[APNs] 디바이스 토큰 수신 성공 — \(deviceToken.count) bytes")
    apnsDeviceToken = deviceToken
    apnsError = nil
    // ⚠️ 흰 화면 근본원인: didFinishLaunching 에서 registerForRemoteNotifications() 를
    // 강제 호출하므로, 이 콜백이 Dart 의 Firebase.initializeApp 완료 '전에' 불릴 수
    // 있다(콜드스타트·기기 타이밍 편차). 그 시점에 Messaging.messaging() 을 만지면
    // "The default Firebase app has not yet been configured." 예외로 앱이 첫 프레임
    // 전에 죽어 흰 화면이 된다. Firebase 구성 여부를 확인하고, 아직이면 토큰만
    // 보관한다 — Dart 초기화 완료 후 auth_session 이 "sync" 채널로 재적용하므로
    // 토큰 유실은 없다.
    if FirebaseApp.app() != nil {
      Messaging.messaging().apnsToken = deviceToken
    } else {
      NSLog("[APNs] Firebase 미구성 상태 — 토큰 보관 후 sync 에서 재적용")
    }
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // APNs 등록 실패 시 "왜" 를 남긴다. apns=NULL 의 실제 원인(네트워크 실패 /
  // 프로파일 aps-environment 누락 / capability 미반영 등)이 여기 error 로 드러난다.
  // 이 핸들러가 호출되면 키·서버와 무관한 "기기↔애플 등록" 자체의 실패다.
  // 사유를 보관해 Dart→서버 진단으로 노출한다(기기 콘솔을 못 보는 TestFlight 대응).
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[APNs] 등록 실패 — registerForRemoteNotifications error: \(error.localizedDescription)")
    apnsError = error.localizedDescription
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Dart 진단/재적용 채널. Dart 가 Firebase 초기화 완료 후 "sync" 를 부르면
    // (1) 보관해 둔 APNs 토큰을 Messaging 에 다시 적용하고
    // (2) 현재 등록 상태(hasToken / error)를 돌려준다.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DigdaApnsDiag") {
      let channel = FlutterMethodChannel(
        name: "com.digda.app/apns",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "sync":
          // Firebase 가 구성된 지금 시점에 토큰을 재적용해 유실 레이스를 차단.
          // (Dart 의 Firebase.initializeApp 완료 후 호출되므로 정상 구성 상태지만,
          //  구성 전 오호출에도 크래시가 없도록 방어적으로 확인한다.)
          if let token = self?.apnsDeviceToken, FirebaseApp.app() != nil {
            Messaging.messaging().apnsToken = token
          }
          result([
            "hasToken": self?.apnsDeviceToken != nil,
            "error": self?.apnsError as Any,
          ])
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      apnsChannel = channel
    }
  }
}
