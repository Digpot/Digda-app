import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/feedback/models/feedback_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

/// 앱 자체 피드백 폼 — 어드민이 구성한 문항을 동적으로 렌더링하고 응답을 서버에 제출한다.
class FeedbackFormScreen extends StatefulWidget {
  const FeedbackFormScreen({super.key});

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<FeedbackQuestion> _questions = const [];

  /// 문항 id → 응답. 유형별로 String / int / Map<String,String>(grid) 를 담는다.
  final Map<int, dynamic> _answers = {};
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Di.feedbackRepository.getQuestions();
      if (!mounted) return;
      setState(() => _questions = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TextEditingController _controllerFor(int id) =>
      _textControllers.putIfAbsent(id, () => TextEditingController());

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    // 필수 문항 검증 + 응답 payload 구성.
    final payload = <Map<String, dynamic>>[];
    for (final q in _questions) {
      final answer = _answerString(q);
      if (q.required && (answer == null || answer.trim().isEmpty)) {
        showErrorDialog(context, '"${q.title}" 문항에 응답해주세요.');
        return;
      }
      if (answer != null && answer.trim().isNotEmpty) {
        payload.add({'questionId': q.id, 'answer': answer});
      }
    }

    if (payload.isEmpty) {
      showErrorDialog(context, '응답을 하나 이상 입력해주세요.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await Di.feedbackRepository.submit(payload);
      if (!mounted) return;
      await showInfoDialog(
        context,
        '피드백을 보냈어요',
        '소중한 의견 감사합니다. 더 좋은 디그팟을 만드는 데 큰 힘이 돼요! 🙏',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 문항 유형별 응답을 표시용 문자열로 직렬화. 미응답이면 null.
  String? _answerString(FeedbackQuestion q) {
    switch (q.type) {
      case FeedbackQuestionType.shortText:
      case FeedbackQuestionType.paragraph:
        return _controllerFor(q.id).text.trim();
      case FeedbackQuestionType.singleChoice:
        return _answers[q.id] as String?;
      case FeedbackQuestionType.scale:
        final v = _answers[q.id];
        return v == null ? null : '$v';
      case FeedbackQuestionType.grid:
        final map = _answers[q.id] as Map<String, String>?;
        if (map == null || map.isEmpty) return null;
        // 필수인데 일부 행만 응답한 경우도 미완으로 간주.
        if (q.required && map.length < q.gridRows.length) return null;
        return q.gridRows
            .where((r) => map[r] != null)
            .map((r) => '$r: ${map[r]}')
            .join(', ');
      case FeedbackQuestionType.section:
      case FeedbackQuestionType.unknown:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 20, color: AppColors.gray900),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '피드백 보내기',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.gray700, fontSize: 14)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }
    if (_questions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '아직 준비된 피드백 문항이 없어요.\n곧 열릴 예정입니다!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.gray500,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        const Text(
          '디그팟을 써주셔서 감사해요! 더 좋은 앱을 만들기 위해 여러분의 솔직한 의견이 필요해요. 1~2분이면 충분합니다 🙏',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 13,
            height: 1.5,
            color: AppColors.gray500,
          ),
        ),
        const SizedBox(height: 8),
        ..._questions.map(_buildQuestion),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : const Text(
                    '보내기',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(FeedbackQuestion q) {
    switch (q.type) {
      case FeedbackQuestionType.section:
        return _buildSection(q);
      case FeedbackQuestionType.shortText:
        return _buildTextField(q, maxLines: 1);
      case FeedbackQuestionType.paragraph:
        return _buildTextField(q, maxLines: 4);
      case FeedbackQuestionType.singleChoice:
        return _buildSingleChoice(q);
      case FeedbackQuestionType.scale:
        return _buildScale(q);
      case FeedbackQuestionType.grid:
        return _buildGrid(q);
      case FeedbackQuestionType.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSection(FeedbackQuestion q) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppColors.gray900,
            ),
          ),
          if (q.description != null && q.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              q.description!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.gray500,
              ),
            ),
          ],
          const SizedBox(height: 4),
          const Divider(color: AppColors.gray100, height: 12),
        ],
      ),
    );
  }

  Widget _buildQuestionLabel(FeedbackQuestion q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              q.title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.gray900,
              ),
            ),
          ),
          if (q.required)
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 2),
              child: Text('*',
                  style: TextStyle(color: AppColors.primary, fontSize: 15)),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldWrap(FeedbackQuestion q, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionLabel(q),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(FeedbackQuestion q, {required int maxLines}) {
    return _buildFieldWrap(
      q,
      Container(
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextField(
          controller: _controllerFor(q.id),
          maxLines: maxLines,
          minLines: maxLines,
          maxLength: maxLines == 1 ? 200 : 1000,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.5,
            color: AppColors.gray900,
          ),
          decoration: const InputDecoration(
            hintText: '내용을 입력하세요',
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.gray400,
            ),
            border: InputBorder.none,
            counterText: '',
          ),
        ),
      ),
    );
  }

  Widget _buildSingleChoice(FeedbackQuestion q) {
    final selected = _answers[q.id] as String?;
    return _buildFieldWrap(
      q,
      Column(
        children: q.choices.map((opt) {
          final isSelected = selected == opt;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _answers[q.id] = opt),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : AppColors.gray50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.gray100,
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color:
                          isSelected ? AppColors.primary : AppColors.gray300,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                          fontSize: 14,
                          color: isSelected
                              ? AppColors.gray900
                              : AppColors.gray700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScale(FeedbackQuestion q) {
    final selected = _answers[q.id] as int?;
    final values = [for (var i = q.scaleMin; i <= q.scaleMax; i++) i];
    return _buildFieldWrap(
      q,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values.map((v) {
          final isSelected = selected == v;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _answers[q.id] = v),
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.gray50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.gray200,
                ),
              ),
              child: Text(
                '$v',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isSelected ? AppColors.white : AppColors.gray700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid(FeedbackQuestion q) {
    final map = (_answers[q.id] as Map<String, String>?) ?? <String, String>{};
    return _buildFieldWrap(
      q,
      Column(
        children: q.gridRows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: AppColors.gray800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: q.gridCols.map((col) {
                    final isSelected = map[row] == col;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        final next = Map<String, String>.from(map);
                        next[row] = col;
                        _answers[q.id] = next;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.gray50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.gray200,
                          ),
                        ),
                        child: Text(
                          col,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: 13,
                            color: isSelected
                                ? AppColors.white
                                : AppColors.gray700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
