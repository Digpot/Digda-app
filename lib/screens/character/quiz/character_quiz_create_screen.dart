import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/character/models/character_models.dart';
import '../../../features/upload/models/upload_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/image_pick_helper.dart';

/// 퀴즈 만들기 — 카테고리/문제/4지선다/정답/배수 입력 후 제출.
///
/// 와이어는 단계별 화면이지만, 입력 항목이 그리 많지 않아 1화면으로 통합해
/// 사용자가 전후 컨텍스트를 잃지 않도록 했다. (재설계)
///
/// [dikoUnlocked] = true 면 사진 퀴즈를 만들 수 있다. false 면 사진 슬롯이 잠금 상태로
/// 표시되며 안내 문구가 같이 노출된다. 호출 측이 현재 그룹의 캐릭터 상태에서 전달.
class CharacterQuizCreateScreen extends StatefulWidget {
  const CharacterQuizCreateScreen({
    super.key,
    this.dikoUnlocked = false,
  });

  final bool dikoUnlocked;

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
  File? _pickedImage;
  // 미리 업로드해 둔 이미지의 원격 URL. 등록 시 그대로 createQuiz 에 전달.
  // 이미지가 바뀌거나 제거되면 _uploadedImageUrl 도 함께 초기화한다.
  String? _uploadedImageUrl;
  bool _uploadingImage = false;

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
    // 이미지를 골라두고 업로드가 끝나지 않았으면 잠시 비활성.
    if (_pickedImage != null && _uploadedImageUrl == null) return false;
    return true;
  }

  Future<void> _pickAndUploadImage() async {
    if (_uploadingImage || _submitting) return;
    if (!widget.dikoUnlocked) {
      showErrorDialog(
        context,
        '사진 퀴즈는 디코가 등장한 그룹에서만 만들 수 있어요.\n'
        '모찌가 Lv.10 에 도달해 디코가 나타나면 활성화됩니다.',
      );
      return;
    }
    final file = await pickImage(context);
    if (file == null || !mounted) return;
    setState(() {
      _pickedImage = file;
      _uploadedImageUrl = null;
      _uploadingImage = true;
    });
    try {
      final uploaded = await Di.uploadRepository.uploadImage(
        filePath: file.path,
        purpose: UploadPurpose.quiz,
      );
      if (!mounted) return;
      setState(() {
        _uploadedImageUrl = uploaded.url;
        _uploadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pickedImage = null;
        _uploadedImageUrl = null;
        _uploadingImage = false;
      });
      showErrorDialog(context, '이미지 업로드에 실패했어요.\n${errorMessageOf(e)}');
    }
  }

  void _removeImage() {
    if (_uploadingImage || _submitting) return;
    setState(() {
      _pickedImage = null;
      _uploadedImageUrl = null;
    });
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
        imageUrl: _uploadedImageUrl,
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
          const SizedBox(height: 18),
          const _SectionLabel('사진 (선택)'),
          const SizedBox(height: 4),
          Text(
            widget.dikoUnlocked
                ? '사진을 첨부하면 이미지 퀴즈가 돼요. 비워두면 텍스트 퀴즈로 등록돼요.'
                : '사진 퀴즈는 디코가 등장한 후(모찌 Lv.10) 부터 만들 수 있어요.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 8),
          _QuizImagePicker(
            image: _pickedImage,
            uploading: _uploadingImage,
            uploaded: _uploadedImageUrl != null,
            locked: !widget.dikoUnlocked,
            onPick: _pickAndUploadImage,
            onRemove: _removeImage,
          ),
          const SizedBox(height: 24),
          const _SectionLabel('선택지 4개 — 정답을 선택해 주세요'),
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

class _QuizImagePicker extends StatelessWidget {
  const _QuizImagePicker({
    required this.image,
    required this.uploading,
    required this.uploaded,
    required this.locked,
    required this.onPick,
    required this.onRemove,
  });

  final File? image;
  final bool uploading;
  final bool uploaded;
  final bool locked;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: locked ? AppColors.gray200 : AppColors.gray200,
              width: 1.4,
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  locked
                      ? Icons.lock_outline
                      : Icons.add_photo_alternate_outlined,
                  color: AppColors.gray400,
                  size: 32,
                ),
                const SizedBox(height: 6),
                Text(
                  locked ? '디코 등장 후 사용 가능' : '사진 추가하기',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            image!,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
        if (uploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (!uploading)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        if (!uploading && uploaded)
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    '업로드 완료',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
