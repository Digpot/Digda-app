import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/diary/models/diary_models.dart';
import '../../features/place/data/kakao_place_search.dart';
import '../../features/place/models/place_models.dart';
import '../../features/upload/models/upload_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/diary_paper.dart';
import '../../widgets/image_pick_helper.dart';

enum DiaryFormMode { create, edit }

/// 일기 작성/수정 공용 화면 — docs/re/reDiary_insert.png 스펙.
class DiaryFormScreen extends StatefulWidget {
  const DiaryFormScreen({
    super.key,
    required this.mode,
    this.diaryId,
    this.initialDate,
  });

  final DiaryFormMode mode;

  /// edit 모드일 때만 사용.
  final String? diaryId;

  /// create 모드일 때 초기 선택 날짜 (옵션).
  final DateTime? initialDate;

  @override
  State<DiaryFormScreen> createState() => _DiaryFormScreenState();
}

class _DiaryFormScreenState extends State<DiaryFormScreen> {
  static const Color _coral = Color(0xFFFF6B6B);
  static const Color _coralSoft = Color(0xFFFFEDED);
  static const Color _ink = Color(0xFF191F28);
  static const Color _sub = Color(0xFF4E5968);
  static const Color _muted = Color(0xFF8B95A1);
  static const Color _line = Color(0xFFF2F4F6);
  static const Color _fieldBg = Color(0xFFF2F4F6);
  static const Color _chipBg = Color(0xFFF6F7F9);

  static const int _maxImages = 5;
  static const int _maxTitle = 30;
  static const int _maxContent = 1000;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final FocusNode _contentFocus = FocusNode();

  bool _hydrated = false;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;

  DateTime _date = DateTime.now();
  int _weather = 0;
  int _mood = 0;

  /// 이미 업로드되어 있는 원본 URL (수정 모드 초기값).
  /// new로 추가된 이미지는 [_newFiles] 에서 별도 관리.
  final List<String> _existingUrls = <String>[];
  final List<File> _newFiles = <File>[];
  /// 원본 다이어리 (수정 모드에서 dirty 비교용).
  Diary? _original;

  @override
  void initState() {
    super.initState();
    if (widget.mode == DiaryFormMode.create) {
      _date = widget.initialDate ?? DateTime.now();
      _hydrated = true;
    }
    _titleController.addListener(_markDirty);
    _contentController.addListener(_markDirty);
    _locationController.addListener(_markDirty);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.mode == DiaryFormMode.edit && !_hydrated && _loadError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_hydrated) return;
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _hydrate() async {
    final groupId = Di.activeGroup.groupRoomId;
    final diaryId = widget.diaryId;
    if (groupId == null || diaryId == null) {
      setState(() => _loadError = '일기 정보를 불러올 수 없어요');
      return;
    }
    try {
      final detail = await Di.diaryRepository.detail(groupId, diaryId);
      if (!mounted) return;
      final d = detail.diary;
      setState(() {
        _original = d;
        _titleController.text = d.title;
        _contentController.text = d.content;
        _locationController.text = d.location ?? '';
        _date = d.date;
        _weather = d.weather;
        _mood = d.mood;
        _existingUrls
          ..clear()
          ..addAll(d.imageUrls);
        _hydrated = true;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = errorMessageOf(e));
    }
  }

  int get _totalImages => _existingUrls.length + _newFiles.length;
  bool get _canAddImage => _totalImages < _maxImages;

  bool get _canSave =>
      _hydrated &&
      !_saving &&
      _titleController.text.trim().isNotEmpty &&
      _contentController.text.trim().isNotEmpty &&
      (widget.mode == DiaryFormMode.create || _dirty);

  Future<void> _pickPhoto() async {
    if (!_canAddImage) return;
    final remaining = _maxImages - _totalImages;
    final files = await pickImages(context, limit: remaining);
    if (files.isEmpty || !mounted) return;
    setState(() {
      _newFiles.addAll(files.take(remaining));
      _dirty = true;
    });
  }

  void _removeExistingAt(int index) {
    setState(() {
      _existingUrls.removeAt(index);
      _dirty = true;
    });
  }

  void _removeNewAt(int index) {
    setState(() {
      _newFiles.removeAt(index);
      _dirty = true;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _coral,
            onPrimary: AppColors.white,
            surface: AppColors.white,
            onSurface: _ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    // create 모드에서 이미 일기가 있는 날짜인지 확인
    if (widget.mode == DiaryFormMode.create) {
      final groupId = Di.activeGroup.groupRoomId;
      if (groupId != null) {
        try {
          final diaryDates = await Di.diaryRepository.calendar(groupId, picked);
          final pickedUtc =
              DateTime.utc(picked.year, picked.month, picked.day);
          final hasDuplicate = diaryDates.any(
            (d) => DateTime.utc(d.year, d.month, d.day) == pickedUtc,
          );
          if (hasDuplicate) {
            if (!mounted) return;
            showErrorDialog(
              context,
              '해당 날짜에 이미 작성된 일기가 있어요.\n다른 날짜를 선택해주세요.',
            );
            return;
          }
        } catch (_) {
          // 확인 실패 시 저장 시점에서 재검사
        }
      }
    }

    setState(() {
      _date = picked;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;

    setState(() => _saving = true);
    try {
      // create 모드: 저장 직전 중복 날짜 최종 확인 (날짜 변경 후 저장하는 경우 대비)
      if (widget.mode == DiaryFormMode.create) {
        final diaryDates =
            await Di.diaryRepository.calendar(groupId, _date);
        final dateUtc = DateTime.utc(_date.year, _date.month, _date.day);
        final hasDuplicate = diaryDates.any(
          (d) => DateTime.utc(d.year, d.month, d.day) == dateUtc,
        );
        if (hasDuplicate) {
          if (!mounted) return;
          setState(() => _saving = false);
          showErrorDialog(
            context,
            '해당 날짜에 이미 작성된 일기가 있어요.\n다른 날짜를 선택해주세요.',
          );
          return;
        }
      }

      // 1. 새로 첨부된 파일들 업로드 → upload id 수집
      final newIds = <String>[];
      for (final file in _newFiles) {
        final uploaded = await Di.uploadRepository.uploadImage(
          filePath: file.path,
          purpose: UploadPurpose.diary,
        );
        newIds.add(uploaded.id);
      }

      // 2. imageIds 빌드.
      //    서버(DiaryServiceImpl.resolveImageUrls)는 항목별로 판별:
      //      · "http(s)://..." → 기존 사진 URL 그대로 보존
      //      · 숫자 → UploadedImage lookup
      //    그래서 클라는 _existingUrls(현재 화면에 남아있는 기존 사진들의 URL)
      //    + newIds(새로 업로드한 id) 를 *그대로 순서대로* 합쳐 보내면 된다.
      final isEdit = widget.mode == DiaryFormMode.edit;
      final combined = <String>[..._existingUrls, ...newIds];

      Object? imageIdsField;
      if (isEdit) {
        final originalUrls = _original?.imageUrls ?? const <String>[];
        final unchanged =
            newIds.isEmpty && _listEquals(originalUrls, _existingUrls);
        imageIdsField =
            unchanged ? DiaryWriteRequest.unset : combined;
      } else {
        imageIdsField = combined;
      }

      // location
      final loc = _locationController.text.trim();
      final Object? locField = loc.isEmpty ? null : loc;

      if (isEdit) {
        await Di.diaryRepository.update(
          groupId,
          widget.diaryId!,
          DiaryWriteRequest(
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            date: _date,
            weather: _weather,
            mood: _mood,
            location: locField,
            imageIds: imageIdsField,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        final created = await Di.diaryRepository.create(
          groupId,
          DiaryWriteRequest.create(
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            date: _date,
            weather: _weather,
            mood: _mood,
            location: loc.isEmpty ? null : loc,
            imageIds: combined,
          ),
        );
        Di.characterRepository
            .addExp(amount: 15, source: 'diary_create')
            .ignore();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/diary-detail',
          arguments: created.id,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '변경사항이 저장되지 않아요',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: _ink,
          ),
        ),
        content: const Text(
          '편집을 중단하고 나갈까요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: _sub,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('계속 작성'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '나가기',
              style: TextStyle(color: _coral, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: _muted, size: 40),
                const SizedBox(height: 8),
                Text(_loadError!,
                    style: const TextStyle(color: _sub, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _hydrated ? _buildBody() : _buildSkeleton(),
              ),
              _buildBottomToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() => const Center(
        child: CircularProgressIndicator(color: _coral),
      );

  Widget _buildHeader() {
    final title = widget.mode == DiaryFormMode.create ? '일기 쓰기' : '일기 수정';
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (await _onWillPop() && mounted) Navigator.of(context).pop();
            },
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Text(
                '취소',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: _sub,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.3,
                  color: _ink,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: _canSave ? _save : null,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _coral,
                      ),
                    )
                  : Text(
                      '저장',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _canSave ? _coral : _muted,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhotoStrip(),
          const SizedBox(height: 16),
          _buildMetaRow(
            icon: Icons.calendar_today_rounded,
            label: '날짜',
            value: _formatDate(_date),
            onTap: _pickDate,
          ),
          _buildMetaRow(
            icon: Icons.place_outlined,
            label: '장소',
            value: _locationController.text.isEmpty
                ? '추가하기'
                : _locationController.text,
            valueColor: _locationController.text.isEmpty ? _muted : _ink,
            onTap: _openLocationSheet,
          ),
          const SizedBox(height: 12),
          _buildSectionLabel('오늘의 날씨'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < diaryWeatherOptions.length; i++)
                _selectChip(
                  emoji: diaryWeatherOptions[i].emoji,
                  label: diaryWeatherOptions[i].label,
                  selected: _weather == i,
                  onTap: () => setState(() {
                    _weather = i;
                    _dirty = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionLabel('오늘의 기분'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < diaryMoodOptions.length; i++)
                _selectChip(
                  emoji: diaryMoodOptions[i].emoji,
                  label: diaryMoodOptions[i].label,
                  selected: _mood == i,
                  onTap: () => setState(() {
                    _mood = i;
                    _dirty = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionLabel('제목'),
          const SizedBox(height: 10),
          _buildTitleField(),
          const SizedBox(height: 18),
          _buildSectionLabel('오늘의 이야기'),
          const SizedBox(height: 10),
          _buildContentField(),
        ],
      ),
    );
  }

  Widget _buildPhotoStrip() {
    const itemSize = 96.0;
    return SizedBox(
      height: itemSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _existingUrls.length + _newFiles.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          if (index == 0) return _photoAddSlot(itemSize);
          final i = index - 1;
          if (i < _existingUrls.length) {
            return _photoSlotNetwork(
              url: _existingUrls[i],
              size: itemSize,
              onRemove: () => _removeExistingAt(i),
            );
          }
          final fileIndex = i - _existingUrls.length;
          return _photoSlotFile(
            file: _newFiles[fileIndex],
            size: itemSize,
            onRemove: () => _removeNewAt(fileIndex),
          );
        },
      ),
    );
  }

  Widget _photoAddSlot(double size) {
    final disabled = !_canAddImage;
    return GestureDetector(
      onTap: disabled ? null : _pickPhoto,
      child: DottedBox(
        size: size,
        color: disabled ? _muted : const Color(0xFFD1D6DB),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 22,
              color: disabled ? _muted : _sub,
            ),
            const SizedBox(height: 4),
            Text(
              '$_totalImages/$_maxImages',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: disabled ? _muted : _sub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoSlotNetwork({
    required String url,
    required double size,
    required VoidCallback onRemove,
  }) {
    return _photoSlot(
      size: size,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: _chipBg,
          alignment: Alignment.center,
          child: const Icon(Icons.image_outlined, color: _muted),
        ),
      ),
      onRemove: onRemove,
    );
  }

  Widget _photoSlotFile({
    required File file,
    required double size,
    required VoidCallback onRemove,
  }) {
    return _photoSlot(
      size: size,
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
      onRemove: onRemove,
    );
  }

  Widget _photoSlot({
    required double size,
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(width: size, height: size, child: child),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    Color valueColor = _ink,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _coralSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _coral, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: _muted,
        ),
      );

  Widget _selectChip({
    required String emoji,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _coralSoft : _chipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _coral : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? _coral : _sub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    final len = _titleController.text.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _titleController,
              maxLength: _maxTitle,
              cursorColor: _coral,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_maxTitle),
              ],
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: _ink,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '오늘의 제목을 적어주세요',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: _muted,
                ),
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Text(
            '$len/$_maxTitle',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 11,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentField() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
      ),
      constraints: const BoxConstraints(minHeight: 260),
      child: TextField(
        controller: _contentController,
        focusNode: _contentFocus,
        maxLength: _maxContent,
        maxLines: null,
        cursorColor: _coral,
        cursorWidth: 2.5,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 15,
          height: 1.7,
          color: _ink,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          counterText: '',
          hintText: '오늘의 소중한 순간을 기록해보세요...',
          hintStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 15,
            height: 1.7,
            color: _muted,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    final len = _contentController.text.length;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 10, 16, 10 + MediaQuery.of(context).padding.bottom * 0.5,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          _toolbarButton(
            icon: Icons.add_photo_alternate_outlined,
            onTap: _canAddImage ? _pickPhoto : null,
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: _line),
          const SizedBox(width: 8),
          _toolbarButton(
            icon: Icons.emoji_emotions_outlined,
            onTap: () => FocusScope.of(context).requestFocus(_contentFocus),
          ),
          const Spacer(),
          Text(
            '$len자',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({required IconData icon, VoidCallback? onTap}) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: disabled ? _muted : _sub,
        ),
      ),
    );
  }

  Future<void> _openLocationSheet() async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationSearchSheet(
        initialQuery: _locationController.text,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _locationController.text = picked;
      _dirty = true;
    });
  }

  static String _formatDate(DateTime d) {
    return DateFormat('yyyy년 M월 d일').format(d) +
        ' (${['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1]})';
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class DottedBox extends StatelessWidget {
  const DottedBox({
    super.key,
    required this.size,
    required this.color,
    required this.child,
  });
  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedPainter(color: color, radius: 14),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _DottedPainter extends CustomPainter {
  _DottedPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedPainter old) =>
      old.color != color || old.radius != radius;
}

// ──────────────────────────────────────────────────────────────────────
// 장소 검색 시트 — 카카오 로컬 키워드 검색
// ──────────────────────────────────────────────────────────────────────

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet({required this.initialQuery});
  final String initialQuery;

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  static const Color _coral = Color(0xFFFF6B6B);
  static const Color _ink = Color(0xFF191F28);
  static const Color _sub = Color(0xFF4E5968);
  static const Color _muted = Color(0xFF8B95A1);
  static const Color _line = Color(0xFFF2F4F6);
  static const Color _chipBg = Color(0xFFF6F7F9);

  final KakaoPlaceSearch _search = KakaoPlaceSearch();
  late final TextEditingController _queryController =
      TextEditingController(text: widget.initialQuery);
  List<PlaceSummary> _results = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch());
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _queryController.text.trim();
    if (q.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final list = await _search.search(q);
      if (!mounted) return;
      setState(() {
        _results = list;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '검색에 실패했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  void _pickFreeText() {
    final q = _queryController.text.trim();
    if (q.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(q);
  }

  void _pickPlace(PlaceSummary p) {
    Navigator.of(context).pop(p.name);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboard = mediaQuery.viewInsets.bottom;
    final sheetHeight = mediaQuery.size.height * 0.78;
    final isConfigured = _search.isConfigured;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D6DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '장소 검색',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.3,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      controller: _queryController,
                      cursorColor: _coral,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _ink,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _chipBg,
                        prefixIcon: const Icon(Icons.search, color: _muted),
                        hintText: isConfigured
                            ? '장소 또는 주소를 검색해보세요'
                            : '검색 키 미설정 — 직접 입력만 가능',
                        hintStyle: const TextStyle(color: _muted),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: isConfigured ? _runSearch : null,
                    child: Container(
                      height: 48,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: isConfigured ? _coral : _line,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '검색',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isConfigured ? AppColors.white : _muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody(isConfigured)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16, 8, 16, 12 + mediaQuery.padding.bottom * 0.5,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _pickFreeText,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD1D6DB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '입력한 그대로 저장',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _sub,
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

  Widget _buildBody(bool isConfigured) {
    if (!isConfigured) {
      return const _SheetHint(
        icon: Icons.vpn_key_outlined,
        title: '카카오 검색 키가 설정돼 있지 않아요',
        message: '직접 입력 후 "입력한 그대로 저장"으로 사용해주세요.',
      );
    }
    if (_busy) {
      return const Center(child: CircularProgressIndicator(color: _coral));
    }
    if (_error != null) {
      return _SheetHint(
        icon: Icons.error_outline,
        title: '검색 실패',
        message: _error!,
      );
    }
    if (_results.isEmpty) {
      return const _SheetHint(
        icon: Icons.search_off,
        title: '검색 결과가 없어요',
        message: '키워드를 다르게 입력하거나 직접 저장해보세요.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: _line),
      itemBuilder: (_, index) {
        final p = _results[index];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: const Icon(Icons.place_outlined, color: _coral),
          title: Text(
            p.name,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: _ink,
            ),
          ),
          subtitle: Text(
            p.roadAddressName.isNotEmpty
                ? p.roadAddressName
                : p.addressName,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: _muted,
            ),
          ),
          onTap: () => _pickPlace(p),
        );
      },
    );
  }
}

class _SheetHint extends StatelessWidget {
  const _SheetHint({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: const Color(0xFF8B95A1)),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF4E5968),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Color(0xFF8B95A1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
