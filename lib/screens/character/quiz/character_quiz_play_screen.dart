import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/di.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/error_message.dart';
import '../../../features/character/models/character_models.dart';
import '../../../features/character/widgets/animated_mochi_widget.dart';
import '../../../theme/colors.dart';
import '../../../widgets/app_dialog.dart';
import 'character_quiz_result_screen.dart';

/// 퀴즈 풀기 화면 — 진입 시 서버에서 랜덤 1건 fetch → 4지선다 → 응시.
class CharacterQuizPlayScreen extends StatefulWidget {
  const CharacterQuizPlayScreen({super.key});

  @override
  State<CharacterQuizPlayScreen> createState() =>
      _CharacterQuizPlayScreenState();
}

class _CharacterQuizPlayScreenState extends State<CharacterQuizPlayScreen> {
  CharacterQuiz? _quiz;
  CharacterState? _character;
  int? _selected;
  bool _loading = true;
  bool _submitting = false;
  String? _emptyMessage;
  String? _errorMessage;
  final _mochiCtrl = MochiAnimationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final groupRoomIdStr = Di.activeGroup.groupRoomId;
    if (groupRoomIdStr == null) {
      setState(() {
        _loading = false;
        _emptyMessage = '그룹에 들어간 뒤 퀴즈를 풀 수 있어요.';
      });
      return;
    }
    final groupRoomId = int.tryParse(groupRoomIdStr);
    if (groupRoomId == null) {
      setState(() {
        _loading = false;
        _emptyMessage = '활성 그룹을 확인할 수 없어요.';
      });
      return;
    }
    try {
      // 캐릭터 상태는 best-effort — 실패해도 퀴즈는 풀 수 있게 fallback.
      CharacterState? character;
      try {
        character = await Di.characterRepository
            .getMyState(groupRoomId: groupRoomId);
      } catch (_) {
        character = null;
      }
      final quiz = await Di.characterRepository.pickRandomQuiz(groupRoomId);
      if (!mounted) return;
      setState(() {
        _character = character;
        _quiz = quiz;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // QUIZ_NO_AVAILABLE 은 에러가 아닌 빈 상태로 처리.
      final apiError = e is DioException ? e.error : null;
      if (apiError is ApiException && apiError.code == 'QUIZ_NO_AVAILABLE') {
        setState(() {
          _loading = false;
          _emptyMessage = '아직 풀 수 있는 퀴즈가 없어요.\n그룹원이 퀴즈를 만들면 여기에 나타나요.';
        });
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = errorMessageOf(e);
      });
    }
  }

  Future<void> _submit() async {
    if (_quiz == null || _selected == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await Di.characterRepository.attemptQuiz(
        quizId: _quiz!.id,
        selectedIndex: _selected!,
      );
      if (!mounted) return;
      // 결과 화면으로 대체 push — 풀기 화면이 백스택에 남지 않게 (재진입 시 새 퀴즈 fetch).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CharacterQuizResultScreen(
            quiz: _quiz!,
            result: result,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.gray900),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '퀴즈 풀기',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _ErrorRetry(message: _errorMessage!, onRetry: _fetch)
              : _emptyMessage != null
                  ? _Empty(message: _emptyMessage!)
                  : _buildBody(),
    );
  }

  Widget _buildBody() {
    final q = _quiz!;
    final c = _character;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              children: [
                if (c != null)
                  Center(
                    child: AnimatedMochiWidget(
                      color: c.color,
                      colorHex: c.colorHex,
                      stage: c.stage,
                      size: 120,
                      happiness: c.progress,
                      controller: _mochiCtrl,
                    ),
                  ),
                if (c != null) const SizedBox(height: 12),
                _CategoryChip(
                    text: q.categoryDisplayName, multiplier: q.expMultiplier),
                const SizedBox(height: 16),
                Text(
                  q.question,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    height: 1.4,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${q.authorName} 님이 출제',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: 24),
                for (int i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionTile(
                      index: i + 1,
                      label: q.options[i],
                      selected: _selected == i + 1,
                      onTap: _submitting
                          ? null
                          : () {
                              setState(() => _selected = i + 1);
                              _mochiCtrl.triggerExcited();
                            },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_selected == null || _submitting) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.gray200,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _submitting ? '제출 중...' : '제출하기',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.text, required this.multiplier});
  final String text;
  final int multiplier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: Text(
            'EXP x$multiplier',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.gray900,
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.gray50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.gray300,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected ? Colors.white : AppColors.gray700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: AppColors.gray900,
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

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 56, color: AppColors.gray400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 1.6,
                color: AppColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.gray400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                '다시 시도',
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
      ),
    );
  }
}
