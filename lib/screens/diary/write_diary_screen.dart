import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/diary/models/diary_models.dart';
import '../../features/upload/models/upload_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/image_pick_helper.dart';

class WriteDiaryScreen extends StatefulWidget {
  const WriteDiaryScreen({super.key});

  @override
  State<WriteDiaryScreen> createState() => _WriteDiaryScreenState();
}

class _WriteDiaryScreenState extends State<WriteDiaryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  static const int _maxTitleLength = 20;
  static const int _maxContentLength = 300;

  int _selectedWeather = 0;
  int _selectedMood = 1;
  File? _pickedImage;
  DateTime _selectedDate = DateTime.now();
  bool _dateInitialized = false;
  bool _saving = false;

  /// 서버에서 받아온, 이미 일기가 있는 날짜.
  Set<DateTime> _existingDiaryDates = const <DateTime>{};

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty &&
      _contentController.text.trim().isNotEmpty &&
      !_saving;

  Future<void> _save() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    setState(() => _saving = true);
    try {
      String? imageId;
      if (_pickedImage != null) {
        final uploaded = await Di.uploadRepository.uploadImage(
          filePath: _pickedImage!.path,
          purpose: UploadPurpose.diary,
        );
        imageId = uploaded.id;
      }
      await Di.diaryRepository.create(
        groupId,
        DiaryWriteRequest.create(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          date: _selectedDate,
          weather: _selectedWeather,
          mood: _selectedMood,
          imageId: imageId,
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dateInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is DateTime) {
        _selectedDate = args;
      }
      _dateInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingDates());
    }
  }

  Future<void> _loadExistingDates() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    try {
      final dates = await Di.diaryRepository.calendar(groupId, _selectedDate);
      if (!mounted) return;
      setState(() {
        _existingDiaryDates = dates
            .map((d) => DateTime.utc(d.year, d.month, d.day))
            .toSet();
      });
    } catch (_) {
      // 기존 일기 정보를 못 받아도 작성 자체는 가능 — 무시.
    }
  }

  final List<_WeatherOption> _weatherOptions = const [
    _WeatherOption(icon: Icons.wb_sunny_outlined, color: Color(0xFFFBBF24)),
    _WeatherOption(icon: Icons.wb_cloudy_outlined, color: AppColors.gray400),
    _WeatherOption(icon: Icons.grain, color: AppColors.blue),
    _WeatherOption(icon: Icons.ac_unit, color: AppColors.saturdayBlue),
  ];

  final List<String> _moodEmojis = ['😊', '😍', '😂', '🥰'];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _showImageCropSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImageCropSheet(
        imageFile: _pickedImage!,
        onCropped: (file) {
          setState(() => _pickedImage = file);
        },
        onReplace: () async {
          Navigator.of(context).pop();
          final file = await pickImage(this.context);
          if (file != null) {
            setState(() => _pickedImage = file);
          }
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.year}년 ${date.month}월 ${date.day}일 ${weekday}요일';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: SafeArea(
        child: Column(
          children: [
            // ── 헤더: < 일기 쓰기 저장(우) ──
            Container(
              color: const Color(0xFFFFFDF5),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '일기 쓰기',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: _canSave ? AppColors.primary : AppColors.gray200,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: _canSave ? _save : null,
                      borderRadius: BorderRadius.circular(8),
                      splashColor: AppColors.white.withValues(alpha: 0.3),
                      highlightColor: AppColors.white.withValues(alpha: 0.15),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Text(
                          '저장',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _canSave
                                ? AppColors.white
                                : AppColors.gray400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── 날씨 + 기분 선택 바 ──
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAF9F4),
                border: Border(
                  bottom: BorderSide(color: AppColors.gray100),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      '날씨',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...List.generate(_weatherOptions.length, (i) {
                      final opt = _weatherOptions[i];
                      final isSelected = _selectedWeather == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedWeather = i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? opt.color.withValues(alpha: 0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            opt.icon,
                            size: 18,
                            color: isSelected ? opt.color : AppColors.gray400,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 12),
                    const Text(
                      '기분',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...List.generate(_moodEmojis.length, (i) {
                      final isSelected = _selectedMood == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMood = i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _moodEmojis[i],
                              style: TextStyle(
                                fontSize: isSelected ? 18 : 16,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            // ── 본문 영역 ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    // 날짜 + 제목 + 이미지 카드
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius:
                                  BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                          ),
                          // 날짜 (클릭하여 변경)
                          GestureDetector(
                            onTap: () => _showDateChangeDialog(),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 10),
                              child: Row(
                                children: [
                                  Text(
                                    _formatDate(_selectedDate),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 13,
                                      color: AppColors.gray400,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.edit_calendar_outlined,
                                    size: 14,
                                    color: AppColors.gray400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(
                              color: AppColors.gray100, height: 1),
                          // 제목 입력
                          Container(
                            color: const Color(0xFFFFF8F0),
                            child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right:
                                        BorderSide(color: AppColors.gray100),
                                  ),
                                ),
                                child: const Text(
                                  '제목',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.gray900,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _titleController,
                                  maxLength: _maxTitleLength,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                    color: AppColors.gray900,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '제목을 입력하세요',
                                    hintStyle: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: AppColors.gray300,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    counterText:
                                        '${_titleController.text.length}/$_maxTitleLength',
                                    counterStyle: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: AppColors.gray400,
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          ),
                          const Divider(
                              color: AppColors.gray100, height: 1),
                          // 이미지 추가 영역
                          GestureDetector(
                            onTap: () async {
                              final file = await pickImage(context);
                              if (file != null) {
                                setState(() => _pickedImage = file);
                              }
                            },
                            child: _pickedImage != null
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                        child: Image.file(
                                          _pickedImage!,
                                          width: double.infinity,
                                          height: 360,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      // 편집 버튼
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: GestureDetector(
                                          onTap: () => _showImageCropSheet(),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.black.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.crop,
                                                  size: 14,
                                                  color: AppColors.white,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  '편집',
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                    color: AppColors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // 삭제 버튼
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: GestureDetector(
                                          onTap: () =>
                                              setState(() => _pickedImage = null),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: AppColors.black.withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 14,
                                              color: AppColors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(
                                    width: double.infinity,
                                    height: 160,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFF5F0),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 26,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          '탭하여 그림·사진 추가',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w400,
                                            fontSize: 13,
                                            color: AppColors.gray500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    // 줄이 있는 본문 입력 영역
                    _buildLinedArea(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateChangeDialog() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.gray900,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final pickedUtc = DateTime.utc(picked.year, picked.month, picked.day);
      if (_existingDiaryDates.contains(pickedUtc)) {
        _showDuplicateDiaryDialog();
      } else {
        setState(() => _selectedDate = picked);
      }
    }
  }

  void _showDuplicateDiaryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
            onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildLinedArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            height: 3,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Stack(
              children: [
                Column(
                  children: List.generate(
                    13,
                    (i) => Container(
                      height: 44,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.gray100, width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: _contentController,
                  maxLength: _maxContentLength,
                  maxLines: null,
                  minLines: 12,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                    height: 2.933,
                    color: AppColors.gray800,
                  ),
                  strutStyle: const StrutStyle(
                    fontSize: 15,
                    height: 2.933,
                    forceStrutHeight: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: '오늘의 소중한 순간을 기록해보세요...',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      height: 2.933,
                      color: AppColors.gray300,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 16, 12),
            child: Text(
              '${_contentController.text.length}/$_maxContentLength',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.gray400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherOption {
  final IconData icon;
  final Color color;

  const _WeatherOption({required this.icon, required this.color});
}

class _ImageCropSheet extends StatefulWidget {
  final File imageFile;
  final void Function(File) onCropped;
  final VoidCallback onReplace;

  const _ImageCropSheet({
    required this.imageFile,
    required this.onCropped,
    required this.onReplace,
  });

  @override
  State<_ImageCropSheet> createState() => _ImageCropSheetState();
}

class _ImageCropSheetState extends State<_ImageCropSheet> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _captureAndReturn() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File(
        '${Directory.systemTemp.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCropped(file);
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          const Text(
            '사진 편집',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '핀치로 확대/축소, 드래그로 위치 조정',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 13,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 16),
          // 이미지 편집 영역
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gray200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: InteractiveViewer(
                    transformationController: _controller,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(
                      widget.imageFile,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 하단 버튼
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onReplace,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gray200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '다른 사진',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.gray700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _captureAndReturn,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text(
                                '확인',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
