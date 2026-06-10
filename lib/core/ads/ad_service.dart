import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// 광고 SDK 초기화 + 보상형 광고 로드/노출 헬퍼.
///
/// 보상형은 "시청 완료(보상 획득) 여부"만 [showRewarded] 로 알려주고, 실제 보상
/// (코인) 지급은 호출자가 서버에 위임한다 — 클라에서 직접 재화를 더하지 않는다.
class AdService {
  AdService._();

  static bool _initialized = false;

  /// main() 에서 1회 호출. 실패해도 앱 부팅을 막지 않는다.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('AdService.init failed: $e');
    }
  }

  /// iOS ATT(앱 추적 투명성) 동의 요청. iOS 14+ 에서 아직 결정되지 않았을 때만
  /// 실제 팝업이 뜨고, 그 외(안드로이드/이전 iOS/이미 결정)는 아무 동작도 하지 않는다.
  /// **앱이 foreground(active) 일 때** 호출해야 팝업이 정상 노출되므로, 첫 프레임
  /// 이후에 부른다.
  static Future<void> requestTrackingAuthorization() async {
    try {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('AdService.requestTrackingAuthorization failed: $e');
    }
  }

  /// 보상형 광고를 로드해 보여준다. 사용자가 끝까지 시청해 보상 조건을 충족하면
  /// true, 로드 실패/중도 닫음이면 false 를 반환한다.
  static Future<bool> showRewarded() async {
    final completer = Completer<bool>();
    var earned = false;
    try {
      await RewardedAd.load(
        adUnitId: AdConfig.rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(earned);
              },
              onAdFailedToShowFullScreenContent: (ad, err) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
            );
            ad.show(onUserEarnedReward: (_, __) => earned = true);
          },
          onAdFailedToLoad: (err) {
            debugPrint('RewardedAd failed to load: $err');
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (e) {
      debugPrint('AdService.showRewarded error: $e');
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }
}
