import 'package:flutter/material.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/character/models/character_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/app_dialog.dart';

/// 퀴즈 만들기 — 카테고리/문제/4지선다/정답/배수 입력 후 제출.
///
/// 와이어는 단계별 화면이지만, 입력 항목이 그리 많지 않아 1화면으로 통합해
/// 사용자가 전후 컨텍스트를 잃지 않도록 했다. (재설계)
class CharacterQuizCreateScreen extends StatefulWidget {
  const CharacterQuizCreateScreen({super.key});

  @override
  State<CharacterQuizCreateScreen> createState() =>
      _CharacterQuizCreateScreenState();
}

class _CharacterQuizCreateScreenState extends State<CharacterQuizCreateScreen> {
  QuizCategory _category = QuizCategory.personal;
  final TextEditingController _question = TextEditingController();
  final List<TextEditingController> _options =
      List.generate(4, (_) => TextEditingController());
  int _correctIndex = 1;
  int _multiplier = 1;
  bool _submitting = false;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid {
    if (_question.text.trim().isEmpty || _question.text.length > 200) {
      return false;
    }
    for (final c in _options) {
      if (c.text.trim().isEmpty || c.text.length > 100) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    final groupRoomIdStr = Di.activeGroup.groupRoomId;
    if (groupRoomIdStr == null) {
      showErrorDialog(context, '그룹에 들어간 뒤 퀴즈를 만들 수 있어요.');
      return;
    }
    final groupRoomId = int.tryParse(groupRoomIdStr);
    if (groupRoomId == null) {
      showErrorDialog(context, '활성 그룹을 확인할 수 없어요.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await Di.characterRepository.createQuiz(
        groupRoomId: groupRoomId,
        category: _category,
        question: _question.text.trim(),
        options: _options.map((c) => c.text.trim()).toList(),
        correctIndex: _correctIndex,
        expMultiplier: _multiplier,
      );
      if (!mounted) return;
      showAppSnackBar(context, '퀴즈가 등록됐어요!');
      Navigator.of(context).pop(true);
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
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '퀴즈 만들기',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_valid && !_submitting) ? _submit : null,
            child: Text(
              _submitting ? '등록 중...' : '등록',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: (_valid && !_submitting)
                    ? AppColors.primary
                    : AppColors.gray400,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          const _SectionLabel('카테고리'),
          const SizedBox(height: 8),
          _CategorySelector(
            value: _category,
            onChange: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('문제'),
          const SizedBox(height: 8),
          _BoxedField(
            controller: _question,
            hint: '예) 내가 제일 좋아하는 음식은?',
            maxLength: 200,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('선택지 4개 — 정답 라디오 선택'),
          const SizedBox(height: 8),
          Column(
            children: [
              for (int i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: i + 1,
                        groupValue: _correctIndex,
                        activeColor: AppColors.primary,
                        onChanged: (v) =>
                            setState(() => _correctIndex = v ?? 1),
                      ),
                      Expanded(
                        child: _BoxedField(
                          controller: _options[i],
                          hint: '선택지 ${i + 1}',
                          maxLength: 100,
                          maxLines: 1,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionLabel('EXP 배수 (난이도)'),
          const SizedBox(height: 8),
          _MultiplierSelector(
            value: _multiplier,
            onChange: (v) => setState(() => _multiplier = v),
          ),
          const SizedBox(height: 4),
          const Text(
            '높을수록 정답 시 더 많은 EXP·코인을 줍니다. (1x · 2x · 3x)',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: AppColors.gray700,
      ),
    );
  }
}

class _BoxedField extends StatelessWidget {
  const _BoxedField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.maxLines,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        fontSize: 15,
        color: AppColors.gray900,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: AppColors.gray400,
        ),
        filled: true,
        fillColor: AppColors.gray50,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.value, required this.onChange});
  final QuizCategory value;
  final ValueChanged<QuizCategory> onChange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: QuizCategory.values.map((c) {
        final selected = c == value;
        return GestureDetector(
          onTap: () => onChange(c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.gray50,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.gray200,
              ),
            ),
            child: Text(
              c.displayName,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.gray700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MultiplierSelector extends StatelessWidget {
  const _MultiplierSelector({required this.value, required this.onChange});
  final int value;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 1; i <= 3; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
              child: GestureDetector(
                onTap: () => onChange(i),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == i ? AppColors.primary : AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: value == i ? AppColors.primary : AppColors.gray200,
                    ),
                  ),
                  child: Text(
                    '${i}x',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: value == i ? Colors.white : AppColors.gray700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
