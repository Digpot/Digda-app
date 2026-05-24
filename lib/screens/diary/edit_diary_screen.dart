import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/diary/models/diary_models.dart';
import '../../features/upload/models/upload_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/diary_paper.dart';
import '../../widgets/image_pick_helper.dart';

class EditDiaryScreen extends StatefulWidget {
  const EditDiaryScreen({super.key});

  @override
  State<EditDiaryScreen> createState() => _EditDiaryScreenState();
}

class _EditDiaryScreenState extends State<EditDiaryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocus = FocusNode();

  static const int _maxTitleLength = 20;
  static const int _maxContentLength = 300;

  int _selectedWeather = 0;
  int _selectedMood = 0;
  File? _pickedImage;
  String? _existingImageUrl;
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;
  bool _argsConsumed = false;
  bool _hydrated = false;
  String? _diaryId;
  DateTime _originalDateValue = DateTime.now();
  Set<DateTime> _existingDiaryDates = const <DateTime>{};

  DateTime get _originalDate => _originalDateValue;

  bool get _canSave =>
      _hydrated &&
      _titleController.text.trim().isNotEmpty &&
      _contentController.text.trim().isNotEmpty &&
      !_saving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsConsumed) return;
    _argsConsumed = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) _diaryId = args;
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final groupId = Di.activeGroup.groupRoomId;
    final diaryId = _diaryId;
    if (groupId == null || diaryId == null) return;
    try {
      final detail = await Di.diaryRepository.detail(groupId, diaryId);
      final dates =
          await Di.diaryRepository.calendar(groupId, detail.diary.date);
      if (!mounted) return;
      setState(() {
        _titleController.text = detail.diary.title;
        _contentController.text = detail.diary.content;
        _selectedWeather = detail.diary.weather;
        _selectedMood = detail.diary.mood;
        _selectedDate = detail.diary.date;
        _originalDateValue = DateTime.utc(
          detail.diary.date.year,
          detail.diary.date.month,
          detail.diary.date.day,
        );
        _existingImageUrl = detail.diary.imageUrl;
        _existingDiaryDates =
            dates.map((d) => DateTime.utc(d.year, d.month, d.day)).toSet();
        _hydrated = true;
      });
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  Future<void> _save() async {
    final groupId = Di.activeGroup.groupRoomId;
    final diaryId = _diaryId;
    if (groupId == null || diaryId == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      Object? imageIdField = DiaryWriteRequest.unset;
      if (_pickedImage != null) {
        final uploaded = await Di.uploadRepository.uploadImage(
          filePath: _pickedImage!.path,
          purpose: UploadPurpose.diary,
        );
        imageIdField = uploaded.id;
      } else if (_existingImageUrl == null) {
        // 기존 이미지를 사용자가 제거한 경우 — null 전송으로 서버에서 이미지 해제.
        imageIdField = null;
      }
      await Di.diaryRepository.update(
        groupId,
        diaryId,
        DiaryWriteRequest(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          date: _selectedDate,
          weather: _selectedWeather,
          mood: _selectedMood,
          imageId: imageIdField,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(today) ? today : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: today,
      selectableDayPredicate: (day) => !day.isAfter(today),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.white,
            surface: AppColors.white,
            onSurface: AppColors.gray900,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final pickedUtc = DateTime.utc(picked.year, picked.month, picked.day);
    // 원래 날짜는 중복 체크에서 제외
    if (pickedUtc != _originalDate &&
        _existingDiaryDates.contains(pickedUtc)) {
      if (!mounted) return;
      _showDuplicateDialog();
    } else {
      setState(() => _selectedDate = picked);
    }
  }

  void _showDuplicateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '일기가 이미 있어요',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: const Text(
          '해당 날짜에 이미 작성된 일기가 있어요.\n다른 날짜를 선택해주세요.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '확인',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onPickImage() async {
    final file = await pickImage(context);
    if (file != null) {
      setState(() {
        _pickedImage = file;
        _existingImageUrl = null;
      });
    }
  }

  void _openCropSheet() {
    if (_pickedImage == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiaryImageCropSheet(
        imageFile: _pickedImage!,
        onCropped: (file) => setState(() => _pickedImage = file),
        onReplace: () async {
          Navigator.of(context).pop();
          await _onPickImage();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DiaryStyle.pageBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _DiaryAppBar(
              title: '일기 수정',
              actionLabel: _saving ? '저장 중...' : '저장',
              actionEnabled: _canSave,
              onAction: _canSave ? _save : null,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: !_hydrated
                  ? const Center(
                      child: CircularProgressIndicator(color: DiaryStyle.accent),
                    )
                  : GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      behavior: HitTestBehavior.opaque,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          DiaryStyle.pagePadding,
                          8,
                          DiaryStyle.pagePadding,
                          24 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          children: [
                            _buildHeaderCard(),
                            const SizedBox(height: DiaryStyle.sectionGap),
                            _buildPhotoCard(),
                            const SizedBox(height: DiaryStyle.sectionGap),
                            _buildContentCard(),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 헤더 카드 ────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    final weather = diaryWeatherOf(_selectedWeather);
    final mood = diaryMoodOf(_selectedMood);
    return DiaryPaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DiaryCardAccentBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '날짜',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color: DiaryStyle.labelBrown,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                formatDiaryDate(_selectedDate),
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: DiaryStyle.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.edit_calendar_outlined,
                              size: 14,
                              color: DiaryStyle.labelBrown,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _buildChip(
                  icon: weather.icon,
                  iconColor: weather.color,
                  label: weather.label,
                  onTap: _showWeatherSheet,
                ),
                const SizedBox(width: 8),
                _buildChip(
                  emoji: mood.emoji,
                  label: mood.label,
                  onTap: _showMoodSheet,
                ),
              ],
            ),
          ),
          Container(height: 1, color: DiaryStyle.cardBorder),
          Container(
            color: AppColors.gray50,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 40,
                  child: Text(
                    '제목',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: DiaryStyle.labelBrown,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 18,
                  color: DiaryStyle.cardBorder,
                  margin: const EdgeInsets.only(right: 12),
                ),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    maxLength: _maxTitleLength,
                    cursorColor: DiaryStyle.accent,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      height: 1.3,
                      color: DiaryStyle.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: '오늘의 제목을 적어주세요',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        color: DiaryStyle.textPlaceholder,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_titleController.text.length}/$_maxTitleLength',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: DiaryStyle.labelBrown,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    IconData? icon,
    Color? iconColor,
    String? emoji,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: DiaryStyle.accentSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 14, color: iconColor)
            else if (emoji != null)
              Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: DiaryStyle.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeatherSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionSheet(
        title: '오늘의 날씨',
        children: [
          for (int i = 0; i < diaryWeatherOptions.length; i++)
            _OptionTile(
              selected: _selectedWeather == i,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: diaryWeatherOptions[i].color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      diaryWeatherOptions[i].icon,
                      size: 20,
                      color: diaryWeatherOptions[i].color,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    diaryWeatherOptions[i].label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: DiaryStyle.textPrimary,
                    ),
                  ),
                ],
              ),
              onTap: () {
                setState(() => _selectedWeather = i);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  void _showMoodSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionSheet(
        title: '오늘의 기분',
        children: [
          for (int i = 0; i < diaryMoodOptions.length; i++)
            _OptionTile(
              selected: _selectedMood == i,
              child: Row(
                children: [
                  Text(diaryMoodOptions[i].emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Text(
                    diaryMoodOptions[i].label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: DiaryStyle.textPrimary,
                    ),
                  ),
                ],
              ),
              onTap: () {
                setState(() => _selectedMood = i);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  // ── 사진 카드 ────────────────────────────────────────────────
  Widget _buildPhotoCard() {
    final hasLocal = _pickedImage != null;
    final hasExisting =
        _existingImageUrl != null && _existingImageUrl!.isNotEmpty;
    if (!hasLocal && !hasExisting) {
      return DiaryPaperCard(child: _photoEmpty());
    }
    return DiaryPaperCard(
      child: _photoWithImage(
        hasLocal
            ? Image.file(_pickedImage!,
                width: double.infinity, fit: BoxFit.cover)
            : Image.network(_existingImageUrl!,
                width: double.infinity, fit: BoxFit.cover),
        canCrop: hasLocal,
      ),
    );
  }

  Widget _photoWithImage(Widget image, {required bool canCrop}) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: SizedBox(width: double.infinity, child: image),
        ),
        if (canCrop)
          Positioned(
            top: 10,
            left: 10,
            child: _photoOverlayButton(
              icon: Icons.crop,
              label: '편집',
              onTap: _openCropSheet,
            ),
          ),
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: () => setState(() {
              _pickedImage = null;
              _existingImageUrl = null;
            }),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.white,
              ),
            ),
          ),
        ),
        // 사진 변경 버튼 (좌하단)
        Positioned(
          bottom: 10,
          right: 10,
          child: _photoOverlayButton(
            icon: Icons.photo_library_outlined,
            label: '다른 사진',
            onTap: _onPickImage,
          ),
        ),
      ],
    );
  }

  Widget _photoOverlayButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoEmpty() {
    return GestureDetector(
      onTap: _onPickImage,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 200,
        decoration: const BoxDecoration(color: AppColors.gray50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: DiaryStyle.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 26,
                color: DiaryStyle.accent,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '사진을 추가해보세요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: DiaryStyle.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '추억을 남길 한 장의 사진',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: DiaryStyle.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 본문 카드 ────────────────────────────────────────────────
  Widget _buildContentCard() {
    return DiaryPaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DiaryCardAccentBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: DiaryStyle.labelBrown,
                ),
                const SizedBox(width: 6),
                const Text(
                  '오늘의 이야기',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: DiaryStyle.labelBrown,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_contentController.text.length}/$_maxContentLength',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: DiaryStyle.labelBrown,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: _RuledTextField(
              controller: _contentController,
              focusNode: _contentFocus,
              maxLength: _maxContentLength,
              onChanged: () => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 공용 서브 위젯 (write 와 동일한 동작)
// ─────────────────────────────────────────────────────────────

class _DiaryAppBar extends StatelessWidget {
  const _DiaryAppBar({
    required this.title,
    required this.onBack,
    this.actionLabel,
    this.actionEnabled = false,
    this.onAction,
  });

  final String title;
  final VoidCallback onBack;
  final String? actionLabel;
  final bool actionEnabled;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DiaryStyle.pageBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                size: 18,
                color: DiaryStyle.textPrimary,
              ),
              splashRadius: 22,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: DiaryStyle.textPrimary,
              ),
            ),
            const Spacer(),
            if (actionLabel != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: onAction,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: actionEnabled
                          ? DiaryStyle.accent
                          : DiaryStyle.accent.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RuledTextField extends StatelessWidget {
  const _RuledTextField({
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLength;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
      fontSize: DiaryStyle.contentFontSize,
      height: DiaryStyle.contentLineHeight,
      color: DiaryStyle.textPrimary,
    );
    // strut 에 fontFamily 가 비면 플랫폼 기본 폰트로 baseline 이 계산되어
    // Inter 와 어긋날 수 있다. 명시적으로 'Inter' 동기화 + 균등 leading.
    const strut = StrutStyle(
      fontFamily: 'Inter',
      fontSize: DiaryStyle.contentFontSize,
      height: DiaryStyle.contentLineHeight,
      forceStrutHeight: true,
      leading: 0,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return Stack(
      children: [
        const DiaryRuledBackground(),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: DiaryStyle.rowHeight * 8,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLength: maxLength,
            maxLines: null,
            cursorColor: DiaryStyle.accent,
            style: style,
            strutStyle: strut,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: '오늘의 소중한 순간을 기록해보세요...',
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: DiaryStyle.contentFontSize,
                height: DiaryStyle.contentLineHeight,
                color: DiaryStyle.textPlaceholder,
              ),
              hintMaxLines: 1,
              border: InputBorder.none,
              isCollapsed: true,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              counterText: '',
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
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
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: DiaryStyle.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.child,
    required this.onTap,
  });

  final bool selected;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? DiaryStyle.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? DiaryStyle.accent : AppColors.gray100,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: child),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: DiaryStyle.accent,
              ),
          ],
        ),
      ),
    );
  }
}
