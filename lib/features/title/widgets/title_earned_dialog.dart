import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import '../models/title_models.dart';
import '../title_catalog.dart';
import 'title_badge.dart';

/// 칭호 획득 축하 팝업 — 메달이 팝하며 등장하고 뒤에서 빛이 회전한다.
class TitleEarnedDialog extends StatefulWidget {
  const TitleEarnedDialog({super.key, required this.def, required this.earned});

  final TitleDef def;
  final EarnedTitle earned;

  @override
  State<TitleEarnedDialog> createState() => _TitleEarnedDialogState();
}

class _TitleEarnedDialogState extends State<TitleEarnedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  String get _earnedInfo {
    final e = widget.earned;
    final d = e.earnedAt;
    final date =
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    if (e.groupRoomName != null && e.groupRoomName!.isNotEmpty) {
      return '${e.groupRoomName} 그룹방에서 · $date';
    }
    return '$date 획득';
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 520),
        curve: Curves.elasticOut,
        tween: Tween(begin: 0.7, end: 1.0),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '칭호 획득!',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: def.accent,
                ),
              ),
              const SizedBox(height: 18),
              // 회전하는 빛 + 메달
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: _shine,
                      child: Container(
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              def.accent.withValues(alpha: 0.0),
                              def.accent.withValues(alpha: 0.28),
                              def.accent.withValues(alpha: 0.0),
                              def.accent.withValues(alpha: 0.28),
                              def.accent.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.2, 0.4, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                    TitleBadge(def: def, earned: true, size: 118),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                def.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.gray900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                def.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: def.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _earnedInfo,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    color: def.accent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: def.accent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    '확인',
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
      ),
    );
  }
}

/// 코드로 [TitleEarnedDialog] 를 띄운다. 카탈로그에 없는 코드면 무시.
Future<void> showTitleEarnedDialog(
  BuildContext context,
  EarnedTitle earned,
) {
  final def = TitleCatalog.defOf(earned.code);
  if (def == null) return Future.value();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => TitleEarnedDialog(def: def, earned: earned),
  );
}
