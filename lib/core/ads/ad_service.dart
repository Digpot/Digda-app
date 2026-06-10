import 'dart:async';

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
