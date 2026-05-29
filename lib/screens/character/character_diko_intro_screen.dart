import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/animated_mochi_widget.dart';
import '../../features/character/widgets/diko_character_view.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import '../../theme/colors.dart';

const _kDikoIntroSeenPrefix = 'digda.dikoIntroSeen.';
const _storage = FlutterSecureStorage();

/// 디코 최초 등장 컷씬.
///
/// 트리거는 두 갈래다.
/// 1) Lv.9 → Lv.10 으로 처음 넘는 순간: 서버 응답 `dikoJustUnlocked=true` → 호출 측에서 즉시 push.
/// 2) 디코가 풀린 줄 모르고 들어온 기존 Lv.10+ 그룹: 메인 화면 load 시 `dikoUnlocked=true`
///    이지만 [isAlreadySeen(groupId)] 가 false 면 push. ([show] 호출 후 [markSeen] 으로 기록)
///
/// 키는 그룹 단위 — 같은 사용자라도 그룹마다 한 번씩 인사하는 게 자연스럽다.
class CharacterDikoIntroScreen extends StatelessWidget {
  const CharacterDikoIntroScreen({
    super.key,
    required this.character,
  });

  final CharacterState character;

  /// 호출 측 단축. 표시 후 [groupId] 를 인자로 받으면 자동 markSeen 까지 처리한다.
  /// dikoJustUnlocked 경로처럼 markSeen 을 호출 측이 직접 다루고 싶을 땐 [groupId] 생략.
  static Future<void> show(
    BuildContext context, {
    required CharacterState character,
    int? groupId,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CharacterDikoIntroScreen(character: character),
        fullscreenDialog: true,
      ),
    );
    if (groupId != null) {
      await markSeen(groupId);
    }
  }

  /// 해당 그룹에서 이미 디코 등장 컷씬을 본 적이 있는지.
  static Future<bool> isAlreadySeen(int groupId) async {
    try {
      final v = await _storage.read(key: '$_kDikoIntroSeenPrefix$groupId');
      return v == 'true';
    } catch (_) {
      // secure storage 가 막혀 있으면 보수적으로 false — 한 번 더 보여주는 쪽이 안전.
      return false;
    }
  }

  /// 컷씬을 봤다고 기록. 실패는 무시 (다음 진입에서 한 번 더 봐도 큰 문제 아님).
  static Future<void> markSeen(int groupId) async {
    try {
      await _storage.write(
        key: '$_kDikoIntroSeenPrefix$groupId',
        value: 'true',
      );
    } catch (_) {}
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
