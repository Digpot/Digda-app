import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'di.dart';

/// 서버 점검(업데이트) 게이트.
///
/// 서버 app-config 의 `maintenanceEnabled` 가 켜져 있으면 로그인 여부와 무관하게
/// 닫을 수 없는 팝업을 띄워 앱 전 기능을 차단한다. 앱 시작 시(스플래시 이후)와
/// 그룹홈 진입 시 검사한다. 조회 실패 시에는 게이트를 켜지 않는다(네트워크
/// 문제로 앱을 잠그지 않기 위함 — UpdateGate 와 동일 정책).
class MaintenanceGate {
  MaintenanceGate._();

  static bool _showing = false;

  static const _defaultMessage =
      '더 나은 디그팟을 위해 서버를 업데이트하고 있어요.\n잠시 후 다시 이용해 주세요!';

  /// 점검 여부를 서버에서 새로 받아 검사한다. 점검 중이면 차단 팝업을 띄우고
  /// true 를 반환한다(호출부가 후속 게이트를 건너뛰도록).
  static Future<bool> check(GlobalKey<NavigatorState> navigatorKey) async {
    if (_showing) return true;
    try {
      final config = await Di.appConfigRepository.get(forceRefresh: true);
      if (!config.maintenanceEnabled) return false;
      show(navigatorKey, config.maintenanceMessage);
      return true;
    } catch (e) {
      debugPrint('[maintenance-gate] 검사 실패(무시): $e');
      return false;
    }
  }

  /// 이미 받은 설정으로 즉시 차단 팝업을 띄운다(그룹홈 진입 차단용).
  static void show(GlobalKey<NavigatorState> navigatorKey, String message) {
    if (_showing) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    _showing = true;
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: _MaintenanceDialog(
          message: message.trim().isEmpty ? _defaultMessage : message.trim(),
        ),
      ),
    ).whenComplete(() => _showing = false);
  }
}

/// 점검 안내 다이얼로그 — "다시 확인" 으로 점검 종료를 재검사해 스스로 닫힌다.
class _MaintenanceDialog extends StatefulWidget {
  const _MaintenanceDialog({required this.message});

  final String message;

  @override
  State<_MaintenanceDialog> createState() => _MaintenanceDialogState();
}

class _MaintenanceDialogState extends State<_MaintenanceDialog> {
  bool _checking = false;

  Future<void> _recheck() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final config = await Di.appConfigRepository.get(forceRefresh: true);
      if (!mounted) return;
      if (!config.maintenanceEnabled) {
        Navigator.of(context).pop();
        return;
      }
    } catch (_) {/* 실패하면 점검 유지 — 아래에서 버튼만 복구 */}
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.construction_rounded, color: AppColors.primary, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '서버 업데이트 중이에요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.gray900,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        widget.message,
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
            onPressed: _checking ? null : _recheck,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.white,
                    ),
                  )
                : const Text(
                    '다시 확인',
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
    );
  }
}
