import 'dart:io';

/// AdMob 광고 단위 ID 모음.
///
/// **현재는 전부 구글 공식 "테스트" 광고 단위 ID 라 실제 노출/수익이 없다.**
/// 출시 전 AdMob 콘솔에서 발급한 실제 광고 단위 ID 로 `_prod*` 값을 채우고
/// [useTestAds] 를 false 로 바꾸면 실제 광고가 나간다.
/// (네이티브 앱 ID 도 AndroidManifest.xml / ios Info.plist 에서 함께 교체할 것.)
class AdConfig {
  AdConfig._();

  /// true 면 항상 테스트 광고. 실제 단위 ID 를 넣기 전까지는 true 로 둔다.
  static const bool useTestAds = true;

  // ── 구글 공식 테스트 광고 단위 ID ──
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  // ── 실제 광고 단위 ID (출시 전 교체) ──
  static const String _prodBannerAndroid = '';
  static const String _prodBannerIos = '';
  static const String _prodRewardedAndroid = '';
  static const String _prodRewardedIos = '';

  static String get bannerUnitId => _pick(
        _testBannerAndroid,
        _testBannerIos,
        _prodBannerAndroid,
        _prodBannerIos,
      );

  static String get rewardedUnitId => _pick(
        _testRewardedAndroid,
        _testRewardedIos,
        _prodRewardedAndroid,
        _prodRewardedIos,
      );

  static String _pick(
    String testAndroid,
    String testIos,
    String prodAndroid,
    String prodIos,
  ) {
    final android = Platform.isAndroid;
    if (useTestAds) return android ? testAndroid : testIos;
    final prod = android ? prodAndroid : prodIos;
    // 실제 ID 가 비어 있으면 안전하게 테스트 ID 폴백.
    if (prod.isEmpty) return android ? testAndroid : testIos;
    return prod;
  }
}
