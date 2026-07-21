import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ads/ad_config.dart';

/// 인라인 배너 광고. 스크롤 콘텐츠 흐름 안에 놓아 레이아웃을 깨지 않는다.
///
/// 로드 전/실패 시엔 아무 공간도 차지하지 않아([SizedBox.shrink]) 화면이 흔들리지
/// 않는다. 로드 성공 시에만 배너 높이만큼 자리를 잡는다.
class AdBanner extends StatefulWidget {
  const AdBanner({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  final EdgeInsetsGeometry padding;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ad = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _ad = ad;
    // 플러그인이 없는 환경(위젯 테스트 등)에선 load()가 비동기 예외를 던진다.
    // 실제 로드 실패는 onAdFailedToLoad 콜백으로 처리되므로, 여기서 던져지는
    // 예외는 삼켜 화면이 깨지지 않게 한다.
    ad.load().catchError((Object _) {});
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Padding(
      padding: widget.padding,
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
