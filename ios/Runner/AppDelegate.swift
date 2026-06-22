import Flutter
import UIKit
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    NSLog("[APNs] 디바이스 토큰 수신 성공 — \(deviceToken.count) bytes")
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // APNs 등록 실패 시 "왜" 를 남긴다. apns=NULL 의 실제 원인(네트워크 실패 /
  // 프로파일 aps-environment 누락 / capability 미반영 등)이 여기 error 로 드러난다.
  // 이 핸들러가 호출되면 키·서버와 무관한 "기기↔애플 등록" 자체의 실패다.
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[APNs] 등록 실패 — registerForRemoteNotifications error: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
