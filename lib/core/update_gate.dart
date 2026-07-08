import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/colors.dart';
import 'di.dart';

/// 강제 업데이트 게이트 (2.0.0).
///
/// 서버 app-config 의 `minAppVersion` 보다 현재 앱 버전이 낮으면 닫을 수 없는
/// 다이얼로그를 띄워 스토어(Play/App Store)로 보낸다. 버전 비교는 semver
/// major.minor.patch 숫자 비교(빌드번호 무시). 설정이 비었거나 조회에 실패하면
/// 게이트를 켜지 않는다(네트워크 문제로 앱을 잠그지 않기 위함).
class UpdateGate {
  UpdateGate._();

  static bool _shown = false;

  /// Play 스토어 기본 URL — storeUrlAndroid 미설정 시 폴백.
  static const _playUrl =
      'https://play.google.com/store/apps/details?id=com.digda.app';

  /// 로그인된 상태에서 호출 — 필요 시 강제 업데이트 다이얼로그를 띄운다.
  static Future<void> check(GlobalKey<NavigatorState> navigatorKey) async {
    if (_shown) return;
    try {
      final config = await Di.appConfigRepository.get();
      final min = config.minAppVersion.trim();
      if (min.isEmpty) return;
      final info = await PackageInfo.fromPlatform();
      if (!_isLower(info.version, min)) return;

      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      _shown = true;
      final storeUrl = Platform.isIOS
          ? config.storeUrlIos.trim()
          : (config.storeUrlAndroid.trim().isNotEmpty
              ? config.storeUrlAndroid.trim()
              : _playUrl);
      await _showForceUpdateDialog(ctx, min, storeUrl);
    } catch (e) {
      // 조회 실패로 앱 사용을 막지 않는다 — 다음 기회에 다시 검사.
      debugPrint('[update-gate] 검사 실패(무시): $e');
    }
  }

  /// [current] 가 [minimum] 보다 낮은 semver 인지. 파싱 불가 세그먼트는 0 취급.
  static bool _isLower(String current, String minimum) {
    List<int> parse(String v) => v
        .split('.')
        .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final cur = parse(current);
    final min = parse(minimum);
    for (var i = 0; i < 3; i++) {
      final c = i < cur.length ? cur[i] : 0;
      final m = i < min.length ? min[i] : 0;
      if (c != m) return c < m;
    }
    return false;
  }

  static Future<void> _showForceUpdateDialog(
    BuildContext context,
    String minVersion,
    String storeUrl,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update_alt_rounded,
                  color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                '업데이트가 필요해요',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AppColors.gray900,
                ),
              ),
            ],
          ),
          content: Text(
            '새로운 디그팟(v$minVersion 이상)으로 업데이트해야 계속 사용할 수 있어요.\n스토어에서 최신 버전을 받아주세요!',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.5,
              color: AppColors.gray700,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _openStore(storeUrl),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '지금 업데이트',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openStore(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[update-gate] 스토어 열기 실패: $e');
    }
  }
}
