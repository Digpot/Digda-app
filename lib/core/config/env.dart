import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 환경 변수를 노출하는 얇은 래퍼.
///
/// 앱 부팅 시 [Env.load] 를 한 번만 호출하면 정적 getter 들로 접근할 수 있다.
class Env {
  Env._();

  static Future<void> load() => dotenv.load(fileName: '.env');

  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? 'https://api.digda.kro.kr';

  static String get kakaoNativeAppKey =>
      dotenv.maybeGet('KAKAO_NATIVE_APP_KEY') ?? '';

  static String get kakaoJavaScriptAppKey =>
      dotenv.maybeGet('KAKAO_JAVASCRIPT_APP_KEY') ?? '';

  static String get naverClientId => dotenv.maybeGet('NAVER_CLIENT_ID') ?? '';
  static String get naverClientSecret =>
      dotenv.maybeGet('NAVER_CLIENT_SECRET') ?? '';
  static String get naverClientName =>
      dotenv.maybeGet('NAVER_CLIENT_NAME') ?? '디그팟';

  static String get appleServiceId => dotenv.maybeGet('APPLE_SERVICE_ID') ?? '';
  static String get appleRedirectUri =>
      dotenv.maybeGet('APPLE_REDIRECT_URI') ?? '';
}
