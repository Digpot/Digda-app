import 'package:flutter/material.dart';

import '../core/di.dart';
import '../core/network/error_message.dart';
import '../features/block/models/block_models.dart';
import '../features/report/models/report_models.dart';
import '../theme/colors.dart';
import 'app_dialog.dart';

/// 신고/차단/숨김 액션을 화면 전반에서 재사용하기 위한 헬퍼 모음.
/// (일기 상세, 댓글, 일정 상세, 프로필 등에서 동일한 UX 로 호출한다.)

/// 신고 사유 선택 바텀시트 → 제출까지. 성공 시 true.
Future<bool> showReportSheet(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
  String? groupRoomId,
}) async {
  final reason = await showModalBottomSheet<ReportReason>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _ReportReasonSheet(),
  );
  if (reason == null) return false;
  if (!context.mounted) return false;

  try {
    await Di.reportRepository.submit(
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      groupRoomId: groupRoomId,
    );
    if (context.mounted) {
      showInfoDialog(
        context,
        '신고를 접수했어요',
        '검토 후 조치할게요.\n신고한 콘텐츠는 회원님께 숨김 처리됐어요.',
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) showErrorDialog(context, errorMessageOf(e));
    return false;
  }
}

/// 사용자 차단 확인 다이얼로그 → 차단. 성공 시 true.
Future<bool> confirmBlockUser(
  BuildContext context, {
  required String userId,
  required String userName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '이 사용자를 차단할까요?',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: AppColors.gray900,
        ),
      ),
      content: Text(
        "'$userName' 님의 모든 일기·댓글·일정이\n내 화면에서 보이지 않게 돼요.\n차단은 마이페이지에서 해제할 수 있어요.",
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: AppColors.gray700,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            '취소',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.gray500,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(
            '차단하기',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  if (!context.mounted) return false;

  try {
    await Di.blockRepository.blockUser(userId);
    if (context.mounted) {
      showInfoDialog(context, '차단했어요', "'$userName' 님의 콘텐츠가 더 이상 보이지 않아요.");
    }
    return true;
  } catch (e) {
    if (context.mounted) showErrorDialog(context, errorMessageOf(e));
    return false;
  }
}

/// 개별 콘텐츠 숨기기. 성공 시 true.
Future<bool> hideContentAction(
  BuildContext context, {
  required HideTargetType type,
  required String targetId,
  String noun = '콘텐츠',
}) async {
  try {
    await Di.blockRepository.hideContent(type, targetId);
    if (context.mounted) {
      showInfoDialog(context, '숨겼어요', '이 $noun(이/가) 더 이상 보이지 않아요.');
    }
    return true;
  } catch (e) {
    if (context.mounted) showErrorDialog(context, errorMessageOf(e));
    return false;
  }
}

/// 신고 사유 선택 바텀시트. 선택 시 해당 [ReportReason] 으로 pop.
class _ReportReasonSheet extends StatelessWidget {
  const _ReportReasonSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '신고 사유를 선택해주세요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '신고하면 검토 후 조치되며, 해당 콘텐츠는 회원님께 바로 숨겨져요.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 13,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 12),
          for (final reason in ReportReason.values)
            InkWell(
              onTap: () => Navigator.of(context).pop(reason),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        reason.label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: AppColors.gray900,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.gray400, size: 22),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
