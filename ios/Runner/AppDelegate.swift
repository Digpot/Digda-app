import Flutter
import UIKit
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
