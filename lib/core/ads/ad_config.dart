import 'dart:io';

/// AdMob 광고 단위 ID 모음.
///
/// 실제(prod) 광고 단위 ID 는 **레포에 커밋하지 않는다.** 빌드 시
/// `--dart-define-from-file=admob.local.json` 으로 주입하며(파일은 .gitignore),
/// 주입값이 없으면 구글 공식 "테스트" 광고 단위 ID 로 안전하게 폴백한다.
///
/// 네이티브 앱 ID(`ca-app-pub-...~...`) 는 Dart 가 아니라
/// AndroidManifest( `android/admob.properties` manifestPlaceholder ) /
/// ios Info.plist 에서 교체한다.
///
/// admob.local.json 예시(레포 루트, git 제외):
/// {
///   "ADMOB_BANNER_ANDROID": "ca-app-pub-XXXX/YYYY",
///   "ADMOB_REWARDED_ANDROID": "ca-app-pub-XXXX/ZZZZ"
/// }
class AdConfig {
  AdConfig._();

  // ── 구글 공식 테스트 광고 단위 ID (폴백) ──
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  // ── 실제 광고 단위 ID — 빌드 시 dart-define 으로 주입(레포 미커밋) ──
  // iOS 는 아직 실제 ID 미발급 → 테스트 유지(Android 만 교체).
  static const String _prodBannerAndroid =
      String.fromEnvironment('ADMOB_BANNER_ANDROID');
  static const String _prodRewardedAndroid =
      String.fromEnvironment('ADMOB_REWARDED_ANDROID');

  static String get bannerUnitId =>
      Platform.isAndroid ? _orTest(_prodBannerAndroid, _testBannerAndroid) : _testBannerIos;

  static String get rewardedUnitId => Platform.isAndroid
      ? _orTest(_prodRewardedAndroid, _testRewardedAndroid)
      : _testRewardedIos;

  /// 실제 ID 가 주입돼 있으면 그것을, 비어 있으면 테스트 ID 를 쓴다.
  static String _orTest(String prod, String test) =>
      prod.isNotEmpty ? prod : test;
}
