import Flutter
import UIKit

/// iOS 가 UIScene 생명주기로 전환된 뒤, 소셜 로그인(카카오/네이버) OAuth 콜백 URL 은
/// AppDelegate 의 `application(_:open:options:)` 가 아니라 SceneDelegate 의
/// `scene(_:openURLContexts:)` 로 들어온다. Flutter 의 기본 포워딩(super)이
/// 이 implicit-engine 환경에선 콜백 URL 을 카카오/네이버 플러그인까지 닿게 하지
/// 못해, 카카오톡 앱 전환 로그인(`kakao{앱키}://oauth?code=...`) 후 되돌아온
/// 인증 코드가 플러그인에 전달되지 못하고 유실됐다(증상: "경로를 찾을 수 없어요:
/// /?code=..." 가 뜨고, 카카오 계정 웹 폴백으로 재시도해야만 로그인 성공).
///
/// 카카오/네이버 플러그인은 `addApplicationDelegate` 로 자신을 FlutterAppDelegate 의
/// openURL 체인에 등록해 둔다(FlutterEngine.addApplicationDelegate → AppDelegate 의
/// lifeCycleDelegate). 따라서 여기서 들어온 URL 을 그 체인으로 직접 넘겨주면
/// 플러그인의 `application(_:open:options:)` 가 호출돼 로그인 콜백이 완료된다.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    // Flutter 기본 처리(딥링크/스킴 채택 플러그인 등)를 먼저 유지한다.
    super.scene(scene, openURLContexts: URLContexts)

    // 그리고 AppDelegate openURL 체인으로 직접 포워딩해 카카오/네이버 플러그인이
    // 콜백 URL 을 받도록 한다. 플러그인 핸들러는 URL 문자열만 읽으므로 options 는
    // 비워서 넘겨도 무방하다.
    guard let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate else { return }
    for context in URLContexts {
      _ = appDelegate.application(UIApplication.shared, open: context.url, options: [:])
    }
  }
}
