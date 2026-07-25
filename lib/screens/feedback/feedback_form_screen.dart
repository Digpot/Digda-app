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

  static const LinearGradient _heroGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF9E7D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
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
                  style:
                      const TextStyle(color: AppColors.gray700, fontSize: 14)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      children: [
        _buildHero(),
        if (_questions.isEmpty)
          _buildEmpty()
        else ...[
          const SizedBox(height: 8),
          ..._questions.map(_buildQuestion),
          const SizedBox(height: 24),
          _buildSubmitButton(),
        ],
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: _heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text('💬', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '당신의 의견을 들려주세요',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppColors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '더 좋은 디그팟을 만드는 데 큰 힘이 돼요. 1~2분이면 충분해요 🙏',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12.5,
                    height: 1.5,
                    color: Color(0xFFFFF0EC),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Text('🕊️', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text(
            '아직 준비된 피드백 문항이 없어요.\n곧 열릴 예정입니다!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.5,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _submitting ? null : _heroGradient,
        color: _submitting ? AppColors.gray300 : null,
        boxShadow: _submitting
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _submitting ? null : _submit,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : const Text(
                    '피드백 보내기',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(FeedbackQuestion q) {
    switch (q.type) {
      case FeedbackQuestionType.section:
        return _buildSection(q);
      case FeedbackQuestionType.shortText:
        return _buildCard(q, _buildTextInput(q, maxLines: 1));
      case FeedbackQuestionType.paragraph:
        return _buildCard(q, _buildTextInput(q, maxLines: 4));
      case FeedbackQuestionType.singleChoice:
        return _buildCard(q, _buildSingleChoice(q));
      case FeedbackQuestionType.scale:
        return _buildCard(q, _buildScale(q));
      case FeedbackQuestionType.grid:
        return _buildCard(q, _buildGrid(q));
      case FeedbackQuestionType.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSection(FeedbackQuestion q) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 20,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              gradient: _heroGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 개별 문항 카드 — 흰 배경 + 부드러운 그림자.
  Widget _buildCard(FeedbackQuestion q, Widget child) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gray100),
        boxShadow: [
          BoxShadow(
            color: AppColors.gray900.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionLabel(q),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildQuestionLabel(FeedbackQuestion q) {
    return RichText(
      text: TextSpan(
        text: q.title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 15.5,
          height: 1.4,
          color: AppColors.gray900,
        ),
        children: [
          if (q.required)
            const TextSpan(
              text: '  *',
              style: TextStyle(color: AppColors.primary, fontSize: 15.5),
            ),
        ],
      ),
    );
  }

  Widget _buildTextInput(FeedbackQuestion q, {required int maxLines}) {
    return Container(
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
          isCollapsed: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSingleChoice(FeedbackQuestion q) {
    final selected = _answers[q.id] as String?;
    return Column(
      children: [
        for (var i = 0; i < q.choices.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == q.choices.length - 1 ? 0 : 8),
            child: _selectableTile(
              label: q.choices[i],
              selected: selected == q.choices[i],
              onTap: () => setState(() => _answers[q.id] = q.choices[i]),
            ),
          ),
      ],
    );
  }

  Widget _selectableTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.gray100,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 21,
              color: selected ? AppColors.primary : AppColors.gray300,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                  color: selected ? AppColors.gray900 : AppColors.gray700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScale(FeedbackQuestion q) {
    final selected = _answers[q.id] as int?;
    final values = [for (var i = q.scaleMin; i <= q.scaleMax; i++) i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: values.map((v) {
            final isSelected = selected == v;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _answers[q.id] = v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected ? _heroGradient : null,
                  color: isSelected ? null : AppColors.gray50,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.transparent : AppColors.gray200,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '$v',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isSelected ? AppColors.white : AppColors.gray600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('낮음',
                style: TextStyle(
                    fontFamily: 'Inter', fontSize: 11.5, color: AppColors.gray400)),
            Text('높음',
                style: TextStyle(
                    fontFamily: 'Inter', fontSize: 11.5, color: AppColors.gray400)),
          ],
        ),
      ],
    );
  }

  Widget _buildGrid(FeedbackQuestion q) {
    final map = (_answers[q.id] as Map<String, String>?) ?? <String, String>{};
    return Column(
      children: [
        for (var r = 0; r < q.gridRows.length; r++)
          Container(
            margin: EdgeInsets.only(bottom: r == q.gridRows.length - 1 ? 0 : 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.gridRows[r],
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.gray800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: q.gridCols.map((col) {
                    final isSelected = map[q.gridRows[r]] == col;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        final next = Map<String, String>.from(map);
                        next[q.gridRows[r]] = col;
                        _answers[q.id] = next;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected ? _heroGradient : null,
                          color: isSelected ? null : AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : AppColors.gray200,
                          ),
                        ),
                        child: Text(
                          col,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                            color:
                                isSelected ? AppColors.white : AppColors.gray600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
