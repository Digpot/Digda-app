import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/primary_button.dart';

class AddScheduleScreen extends StatefulWidget {
  const AddScheduleScreen({super.key});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final TextEditingController _titleController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  Color _selectedColor = AppColors.primary;

  final List<Map<String, dynamic>> _allParticipants = [
    {
      'name': '승호',
      'isMe': true,
      'color': AppColors.primary,
      'selected': true
    },
    {
      'name': '지수',
      'isMe': false,
      'color': AppColors.blue,
      'selected': true
    },
    {
      'name': '민호',
      'isMe': false,
      'color': AppColors.green,
      'selected': true
    },
    {
      'name': '수진',
      'isMe': false,
      'color': const Color(0xFFFBBF24),
      'selected': false
    },
    {
      'name': '현우',
      'isMe': false,
      'color': AppColors.purple,
      'selected': false
    },
  ];

  int get _selectedCount =>
      _allParticipants.where((p) => p['selected'] as bool).length;

  final List<Color> _colorOptions = [
    AppColors.primary,
    AppColors.purple,
    AppColors.blue,
    AppColors.green,
    const Color(0xFFFBBF24),
  ];

  bool get _canSave => _titleController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay time) {
    final period = time.hour < 12 ? '오전' : '오후';
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
            ? time.hour - 12
            : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$period $hour:$minute';
  }

  void _showParticipantPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ParticipantPopup(
        participants: _allParticipants,
        onConfirm: (updated) {
          setState(() {
            for (int i = 0; i < _allParticipants.length; i++) {
              _allParticipants[i]['selected'] = updated[i]['selected'];
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - 좌측 정렬
            Padding(
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
                    '일정 등록',
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Category/Color - 회색 배경 + 정중앙 정렬, "+" 제거
                    _buildSectionLabel('카테고리 분류'),
                    const SizedBox(height: 12),
                    _buildColorPicker(),
                    const SizedBox(height: 24),
                    // Title
                    _buildSectionLabel('제목'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _titleController,
                      hintText: '일정 제목을 입력하세요',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 24),
                    // Date - 시작일/종료일
                    _buildSectionLabel('날짜'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDateRange,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDateField('시작일', _startDate),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '~',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                color: AppColors.gray400,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildDateField('종료일', _endDate),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Time
                    _buildSectionLabel('시간'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(isStart: true),
                            child: _buildTimeField(_formatTime(_startTime)),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '~',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              color: AppColors.gray400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(isStart: false),
                            child: _buildTimeField(_formatTime(_endTime)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Participants
                    _buildSectionLabel('참가자'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showParticipantPopup,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ..._allParticipants
                                .where((p) => p['selected'] as bool)
                                .take(3)
                                .map((p) => _buildSmallAvatar(
                                      p['color'] as Color,
                                    )),
                            Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: AppColors.gray200,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 16,
                                color: AppColors.gray500,
                              ),
                            ),
                            Text(
                              '$_selectedCount명 참가',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color: AppColors.gray500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PrimaryButton(
                text: '일정 저장하기',
                onPressed: _canSave ? () => Navigator.of(context).pop() : null,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: AppColors.gray900,
      ),
    );
  }

  // 색상 선택 - "+" 제거, 회색 배경 영역, 정중앙 정렬
  Widget _buildColorPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _colorOptions.map((color) {
          final isSelected = _selectedColor == color;
          return GestureDetector(
            onTap: () => setState(() => _selectedColor = color),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: AppColors.gray900, width: 2.5)
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 18, color: AppColors.white)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w400,
        fontSize: 15,
        color: AppColors.gray900,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 15,
          color: AppColors.gray300,
        ),
        filled: true,
        fillColor: AppColors.gray50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildDateField(String label, DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 11,
              color: AppColors.gray400,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppColors.gray400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${date.month}/${date.day}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: AppColors.gray900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 15,
          color: AppColors.gray900,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSmallAvatar(Color color) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 18, color: color),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: const Locale('ko', 'KR'),
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
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
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
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }
}

class _ParticipantPopup extends StatefulWidget {
  final List<Map<String, dynamic>> participants;
  final void Function(List<Map<String, dynamic>>) onConfirm;

  const _ParticipantPopup({
    required this.participants,
    required this.onConfirm,
  });

  @override
  State<_ParticipantPopup> createState() => _ParticipantPopupState();
}

class _ParticipantPopupState extends State<_ParticipantPopup> {
  late List<Map<String, dynamic>> _local;

  @override
  void initState() {
    super.initState();
    _local = widget.participants
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }

  int get _selectedCount =>
      _local.where((p) => p['selected'] as bool).length;

  String get _headerTitle {
    final me =
        _local.firstWhere((p) => p['isMe'] as bool, orElse: () => {});
    final myName = me.isNotEmpty ? me['name'] as String : '나';
    final others = _selectedCount -
        (me.isNotEmpty && me['selected'] as bool ? 1 : 0);
    return '참가자 : $myName(나), 기타 $others명';
  }

  @override
  Widget build(BuildContext context) {
    final me = _local.where((p) => p['isMe'] as bool).toList();
    final members = _local.where((p) => !(p['isMe'] as bool)).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _headerTitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.gray100, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '나',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
              ),
            ),
          ),
          ...me.map((p) => _buildParticipantRow(p)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '멤버 (${members.length})',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
              ),
            ),
          ),
          ...members.map((p) => _buildParticipantRow(p)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PrimaryButton(
              text: '확인',
              onPressed: () {
                widget.onConfirm(_local);
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantRow(Map<String, dynamic> participant) {
    final idx = _local.indexOf(participant);
    final isSelected = participant['selected'] as bool;
    final color = participant['color'] as Color;

    return GestureDetector(
      onTap: () {
        setState(() => _local[idx]['selected'] = !isSelected);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, size: 24, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                participant['name'] as String,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  color: AppColors.gray900,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? null
                    : Border.all(color: AppColors.gray200, width: 1.5),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: AppColors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
