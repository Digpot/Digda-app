import 'package:flutter/material.dart';

import '../../../features/character/models/character_models.dart';
import '../../../features/character/widgets/animated_mochi_widget.dart';
import '../../../theme/colors.dart';

/// 퀴즈 결과 화면 — 정답 여부 + 보상 + 레벨업/진화 연출.
class CharacterQuizResultScreen extends StatefulWidget {
  const CharacterQuizResultScreen({
    super.key,
    required this.quiz,
    required this.result,
  });

  final CharacterQuiz quiz;
  final QuizAttemptResult result;

  @override
  State<CharacterQuizResultScreen> createState() =>
      _CharacterQuizResultScreenState();
}

class _CharacterQuizResultScreenState extends State<CharacterQuizResultScreen>
    with SingleTickerProviderStateMixin {
  final _mochiCtrl = MochiAnimationController();
  late final AnimationController _enterCtrl;
  late final Animation<double> _scaleFade;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
    _scaleFade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutBack);

    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      if (widget.result.stageChanged) {
        _mochiCtrl.triggerProud();
      } else if (widget.result.correct) {
        _mochiCtrl.triggerHappy();
      }
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  String _stageName(CharacterStage stage) => switch (stage) {
        CharacterStage.egg => '알',
        CharacterStage.sprout => '새싹',
        CharacterStage.bloom => '꽃봄',
        CharacterStage.blossom => '만개',
        CharacterStage.glow => '빛남',
      };

  @override
  Widget build(BuildContext context) {
    final correct = widget.result.correct;
    final correctOptionLabel =
        widget.quiz.options[widget.result.correctIndex - 1];

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    _Verdict(correct: correct),
                    const SizedBox(height: 20),
                    Center(
                      child: ScaleTransition(
                        scale: _scaleFade,
                        child: FadeTransition(
                          opacity: _enterCtrl,
                          child: AnimatedMochiWidget(
                            color: widget.result.character.color,
                            colorHex: widget.result.character.colorHex,
                            stage: widget.result.character.stage,
                            size: 160,
                            controller: _mochiCtrl,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.result.stageChanged)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7E2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: const Color(0xFFFCD34D)),
                          ),
                          child: Text(
                            '진화! ${_stageName(widget.result.stageBefore)} → ${widget.result.character.stageDisplayName} 🌟',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.gray900,
                            ),
                          ),
                        ),
                      )
                    else if (widget.result.levelGained > 0)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '레벨업! Lv. ${widget.result.character.level}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    _Question(quiz: widget.quiz, result: widget.result),
                    const SizedBox(height: 20),
                    _RewardBoard(result: widget.result),
                    if (!correct) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb_outline,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '정답: $correctOptionLabel',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.gray900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
                    '확인',
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

class _Verdict extends StatelessWidget {
  const _Verdict({required this.correct});
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final bg = correct ? AppColors.primary : AppColors.gray500;
    final label = correct ? '정답!' : '아쉬워요';
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              correct ? Icons.check_circle : Icons.cancel,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.quiz, required this.result});
  final CharacterQuiz quiz;
  final QuizAttemptResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quiz.question,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.5,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '내 답: ${result.selectedIndex}번 · ${quiz.options[result.selectedIndex - 1]}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: AppColors.gray700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardBoard extends StatelessWidget {
  const _RewardBoard({required this.result});
  final QuizAttemptResult result;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RewardChip(
            label: 'EXP',
            value: '+${result.earnedExp}',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RewardChip(
            label: '코인',
            value: '+${result.earnedCoin}',
            color: const Color(0xFFFCD34D),
          ),
        ),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color == const Color(0xFFFCD34D)
                  ? AppColors.gray900
                  : color,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.gray900,
            ),
          ),
        ],
      ),
    );
  }
}
