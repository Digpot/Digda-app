import 'package:flutter/material.dart';

import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/animated_mochi_widget.dart';
import '../../features/character/widgets/diko_character_view.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import '../../theme/colors.dart';

/// 디코 최초 등장 컷씬.
///
/// `addExp`/퀴즈 응시 응답에서 `dikoJustUnlocked == true` 일 때 1회만 띄운다.
/// 일반 진화·레벨업 화면과 동일하게 fullscreenDialog 로 push.
class CharacterDikoIntroScreen extends StatelessWidget {
  const CharacterDikoIntroScreen({
    super.key,
    required this.character,
  });

  final CharacterState character;

  /// 호출 측 단축. 등장한 적이 없는 케이스에서만 fire-and-forget 으로 push.
  static Future<void> show(
    BuildContext context, {
    required CharacterState character,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CharacterDikoIntroScreen(character: character),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: AppColors.gray700),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Spacer(),
              const Text(
                '✨',
                style: TextStyle(fontSize: 38),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '모찌의 새로운 친구\n디코가 등장했어요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  height: 1.3,
                  color: AppColors.gray900,
                ),
              ),
              const SizedBox(height: 24),
              // 모찌(왼쪽) + 디코(오른쪽) 듀오 컷
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 20,
                      top: 8,
                      child: AnimatedMochiWidget(
                        appearance: MochiAppearance.fromState(character),
                        stage: character.stage,
                        size: 180,
                        happiness: 1.0,
                      ),
                    ),
                    const Positioned(
                      right: 4,
                      bottom: 12,
                      child: DikoCharacterView(
                        size: 112,
                        mood: DikoMood.happy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '디코는 모찌의 조력자예요.\n레벨업이나 성장 시스템은 없지만,\n모찌의 곁에서 늘 함께 해줄 거예요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.gray700,
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '디코와 인사하기',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
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
