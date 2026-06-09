import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/membership/models/membership_models.dart';
import '../../features/schedule/models/schedule_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
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
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  Color _selectedColor = AppColors.primary;
  bool _allDay = true;
  bool _saving = false;
  bool _loading = true;
  bool _argsConsumed = false;
  String? _editingScheduleId;

  List<Membership> _members = const [];
  final Set<String> _selectedIds = <String>{};

  final List<Color> _colorOptions = [
    AppColors.primary,
    AppColors.purple,
    AppColors.blue,
    AppColors.green,
    const Color(0xFFFBBF24),
  ];

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty && !_saving && _timeOrderValid;

  /// 같은 날 시간 지정 일정에서 종료 시간이 시작 시간보다 빠르면 false.
  /// (종일이거나 종료일이 시작일보다 뒤면 시간 순서를 따지지 않는다)
  bool get _timeOrderValid {
    if (_allDay) return true;
    final sameDay = _startDate.year == _endDate.year &&
        _startDate.month == _endDate.month &&
        _startDate.day == _endDate.day;
    if (!sameDay) return true;
    final start = _startTime.hour * 60 + _startTime.minute;
    final end = _endTime.hour * 60 + _endTime.minute;
    return end >= start;
  }

  bool get _isEdit => _editingScheduleId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsConsumed) return;
    _argsConsumed = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _editingScheduleId = args;
    } else if (args is Map<String, dynamic>) {
      final dateStr = args['date'] as String?;
      if (dateStr != null) {
        final d = DateTime.tryParse(dateStr);
        if (d != null) {
          _startDate = d;
          _endDate = d;
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      // 멤버 목록 (참가자 선택 UI 의 원천)
      final members = await Di.membershipRepository.list(groupId);
      final myId = Di.userSession.profile?.id;
      List<String> initialIds = myId != null ? [myId] : [];

      if (_isEdit) {
        // 편집 모드 — 기존 일정으로 폼 채움
        final detail =
            await Di.scheduleRepository.detail(groupId, _editingScheduleId!);
        final s = detail.schedule;
        _titleController.text = s.title;
        _startDate = s.startDate;
        _endDate = s.endDate;
        _selectedColor = _parseHex(s.color);
        _allDay = s.startTime == null && s.endTime == null;
        if (s.startTime != null) {
          _startTime = _parseTime(s.startTime!) ?? _startTime;
        }
        if (s.endTime != null) {
          _endTime = _parseTime(s.endTime!) ?? _endTime;
        }
        initialIds = s.participants.map((p) => p.id).toList();
      }

      if (!mounted) return;
      setState(() {
        _members = members;
        _selectedIds
          ..clear()
          ..addAll(initialIds);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : AppColors.primary;
  }

  TimeOfDay? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _hexFromColor(Color c) {
    final r = (c.r * 255).round() & 0xff;
    final g = (c.g * 255).round() & 0xff;
    final b = (c.b * 255).round() & 0xff;
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  String _formatTime24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Color _memberColor(Membership m) => _parseHex(m.color);

  Future<void> _save() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    setState(() => _saving = true);
    try {
      final body = ScheduleWriteRequest.create(
        title: _titleController.text.trim(),
        color: _hexFromColor(_selectedColor),
        startDate: _startDate,
        endDate: _endDate,
        allDay: _allDay,
        startTime: _allDay ? null : _formatTime24(_startTime),
        endTime: _allDay ? null : _formatTime24(_endTime),
        participantIds: _selectedIds.toList(),
      );
      if (_isEdit) {
        await Di.scheduleRepository.update(
            groupId, _editingScheduleId!, body);
      } else {
        await Di.scheduleRepository.create(groupId, body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

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
        members: _members,
        selectedIds: _selectedIds.toSet(),
        onConfirm: (updated) {
          setState(() {
            _selectedIds
              ..clear()
              ..addAll(updated);
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
                  Text(
                    _isEdit ? '일정 수정' : '일정 등록',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildSectionLabel('카테고리 분류'),
                      const SizedBox(height: 12),
                      _buildColorPicker(),
                      const SizedBox(height: 24),
                      _buildSectionLabel('제목'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _titleController,
                        hintText: '일정 제목을 입력하세요',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 24),
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
                      Row(
                        children: [
                          _buildSectionLabel('시간'),
                          const Spacer(),
                          const Text(
                            '하루 종일',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: AppColors.gray700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Switch.adaptive(
                            value: _allDay,
                            activeThumbColor: AppColors.primary,
                            onChanged: (v) => setState(() => _allDay = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!_allDay)
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _pickTime(isStart: true),
                                child:
                                    _buildTimeField(_formatTime(_startTime)),
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
                                child:
                                    _buildTimeField(_formatTime(_endTime)),
                              ),
                            ),
                          ],
                        ),
                      if (!_allDay && !_timeOrderValid)
                        const Padding(
                          padding: EdgeInsets.only(top: 8, left: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '종료 시간이 시작 시간보다 빠를 수 없어요',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _buildSectionLabel('참가자'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _members.isEmpty ? null : _showParticipantPopup,
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
                              ..._members
                                  .where((m) => _selectedIds.contains(m.userId))
                                  .take(3)
                                  .map((m) => _buildSmallAvatar(
                                        _memberColor(m),
                                        m.name,
                                        profileImage: m.profileImage,
                                      )),
                              if (_selectedIds.isNotEmpty)
                                const SizedBox(width: 4),
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
                                _selectedIds.isEmpty
                                    ? '참가자 선택'
                                    : '${_selectedIds.length}명 참가',
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
                text: _saving
                    ? '저장 중...'
                    : (_isEdit ? '일정 수정하기' : '일정 저장하기'),
                onPressed: _canSave ? _save : null,
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

  Widget _buildSmallAvatar(Color color, String name, {String? profileImage}) {
    final initial = name.isNotEmpty ? name[0] : '?';
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: (profileImage != null && profileImage.isNotEmpty)
          ? Image.network(
              profileImage,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ),
    );
  }

  Future<void> _pickDateRange() async {
    final result = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DateRangePickerSheet(
        initialRange: DateTimeRange(start: _startDate, end: _endDate),
      ),
    );
    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimePickerSheet(
        initialTime: isStart ? _startTime : _endTime,
        title: isStart ? '시작 시간' : '종료 시간',
      ),
    );
    if (result != null) {
      setState(() {
        if (isStart) {
          _startTime = result;
        } else {
          _endTime = result;
        }
      });
    }
  }
}

class _ParticipantPopup extends StatefulWidget {
  final List<Membership> members;
  final Set<String> selectedIds;
  final void Function(Set<String>) onConfirm;

  const _ParticipantPopup({
    required this.members,
    required this.selectedIds,
    required this.onConfirm,
  });

  @override
  State<_ParticipantPopup> createState() => _ParticipantPopupState();
}

class _ParticipantPopupState extends State<_ParticipantPopup> {
  late Set<String> _local;

  @override
  void initState() {
    super.initState();
    _local = widget.selectedIds.toSet();
  }

  Color _color(Membership m) {
    final cleaned = m.color.replaceAll('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : AppColors.primary;
  }

  String? get _myId => Di.userSession.profile?.id;

  @override
  Widget build(BuildContext context) {
    final me = widget.members
        .where((m) => _myId != null && m.userId == _myId)
        .toList();
    final others = widget.members
        .where((m) => _myId == null || m.userId != _myId)
        .toList();

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
            '${_local.length}명 선택됨',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.gray100, height: 1),
          if (me.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Align(
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
            ...me.map(_buildParticipantRow),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '멤버 (${others.length})',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
              ),
            ),
          ),
          ...others.map(_buildParticipantRow),
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

  Widget _buildParticipantRow(Membership m) {
    final isSelected = _local.contains(m.userId);
    final color = _color(m);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _local.remove(m.userId);
          } else {
            _local.add(m.userId);
          }
        });
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
              clipBehavior: Clip.antiAlias,
              child: m.profileImage != null && m.profileImage!.isNotEmpty
                  ? Image.network(m.profileImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _initialAvatar(m.name, color))
                  : _initialAvatar(m.name, color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                m.name,
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

  Widget _initialAvatar(String name, Color color) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: color,
        ),
      ),
    );
  }
}

// ─── 날짜 범위 선택 바텀시트 ─────────────────────────────────────────────────

class _DateRangePickerSheet extends StatefulWidget {
  final DateTimeRange initialRange;
  const _DateRangePickerSheet({required this.initialRange});

  @override
  State<_DateRangePickerSheet> createState() => _DateRangePickerSheetState();
}

class _DateRangePickerSheetState extends State<_DateRangePickerSheet> {
  late DateTime _display;
  DateTime? _start;
  DateTime? _end;
  bool _pickingEnd = false;

  static DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _eq(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _start = _strip(widget.initialRange.start);
    _end = _strip(widget.initialRange.end);
    _display = DateTime(_start!.year, _start!.month);
  }

  void _onTap(DateTime day) {
    setState(() {
      if (!_pickingEnd) {
        // 한 번 탭 = 그날 하루(시작=종료). 바로 확인 가능, 한 번 더 누르면 기간으로 확장.
        _start = day;
        _end = day;
        _pickingEnd = true;
      } else {
        if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
        _pickingEnd = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_display.year, _display.month + 1, 0).day;
    // Sunday = 0 offset
    final startOffset = DateTime(_display.year, _display.month, 1).weekday % 7;
    final today = _strip(DateTime.now());
    final hasRange = _start != null && _end != null && !_eq(_start!, _end!);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 핸들 바 ──
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── 월 네비게이션 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _MonthNavBtn(
                  icon: Icons.chevron_left,
                  onTap: () => setState(() =>
                      _display = DateTime(_display.year, _display.month - 1)),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_display.year}년 ${_display.month}월',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.gray900,
                      ),
                    ),
                  ),
                ),
                _MonthNavBtn(
                  icon: Icons.chevron_right,
                  onTap: () => setState(() =>
                      _display = DateTime(_display.year, _display.month + 1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 요일 헤더 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: List.generate(7, (i) {
                const labels = ['일', '월', '화', '수', '목', '금', '토'];
                final colors = [
                  AppColors.primary,
                  AppColors.gray400,
                  AppColors.gray400,
                  AppColors.gray400,
                  AppColors.gray400,
                  AppColors.gray400,
                  AppColors.blue,
                ];
                return Expanded(
                  child: Center(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: colors[i],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 2),

          // ── 날짜 그리드 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 44,
              ),
              itemCount: startOffset + daysInMonth,
              itemBuilder: (context, index) {
                if (index < startOffset) return const SizedBox();
                final day = DateTime(
                    _display.year, _display.month, index - startOffset + 1);
                return _buildDayCell(day, today, hasRange);
              },
            ),
          ),

          // ── 안내 문구 ──
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              '날짜를 누르면 하루, 한 번 더 누르면 기간이 선택돼요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: AppColors.gray400,
              ),
            ),
          ),

          // ── 시작/종료 칩 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(
              children: [
                Expanded(child: _DateChip(label: '시작일', date: _start)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward,
                      size: 16, color: AppColors.gray300),
                ),
                Expanded(child: _DateChip(label: '종료일', date: _end)),
              ],
            ),
          ),

          // ── 확인 버튼 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_start != null && _end != null)
                    ? () => Navigator.of(context)
                        .pop(DateTimeRange(start: _start!, end: _end!))
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.gray100,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  '확인',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: (_start != null && _end != null)
                        ? AppColors.white
                        : AppColors.gray400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime day, DateTime today, bool hasRange) {
    final isStart = _start != null && _eq(day, _start!);
    final isEnd = _end != null && _eq(day, _end!);
    final isBetween = _start != null &&
        _end != null &&
        day.isAfter(_start!) &&
        day.isBefore(_end!);
    final isToday = _eq(day, today);
    final isSun = day.weekday == DateTime.sunday;
    final isSat = day.weekday == DateTime.saturday;

    Color textColor;
    if (isStart || isEnd) {
      textColor = AppColors.white;
    } else if (isSun) {
      textColor = AppColors.primary;
    } else if (isSat) {
      textColor = AppColors.blue;
    } else {
      textColor = AppColors.gray900;
    }

    return GestureDetector(
      onTap: () => _onTap(day),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 범위 중간 스트립 (전체 셀)
                if (isBetween)
                  Positioned(
                    top: 4, bottom: 4, left: 0, right: 0,
                    child: Container(
                      color: AppColors.primary.withValues(alpha: 0.10),
                    ),
                  ),
                // 시작 셀 오른쪽 반 스트립 (범위 있을 때)
                if (isStart && hasRange)
                  Positioned(
                    top: 4, bottom: 4,
                    left: w / 2, right: 0,
                    child: Container(
                      color: AppColors.primary.withValues(alpha: 0.10),
                    ),
                  ),
                // 종료 셀 왼쪽 반 스트립 (범위 있을 때)
                if (isEnd && hasRange)
                  Positioned(
                    top: 4, bottom: 4,
                    left: 0, right: w / 2,
                    child: Container(
                      color: AppColors.primary.withValues(alpha: 0.10),
                    ),
                  ),
                // 오늘 날짜 테두리
                if (isToday && !isStart && !isEnd)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                // 선택된 날짜 원형 배경
                if (isStart || isEnd)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                // 날짜 텍스트
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: (isStart || isEnd || isToday)
                        ? FontWeight.w700
                        : FontWeight.w400,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MonthNavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.gray700),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final DateTime? date;
  const _DateChip({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasDate
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 10,
              color: AppColors.gray400,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            hasDate ? '${date!.month}월 ${date!.day}일' : '미선택',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: hasDate ? AppColors.primary : AppColors.gray300,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 시간 선택 바텀시트 ──────────────────────────────────────────────────────

class _TimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;

  const _TimePickerSheet({
    required this.initialTime,
    required this.title,
  });

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late bool _isAm;
  late int _hour12; // 1 ~ 12
  late int _minute; // 0 ~ 59

  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTime;
    _isAm = t.hour < 12;
    _hour12 = t.hour == 0
        ? 12
        : t.hour > 12
            ? t.hour - 12
            : t.hour;
    _minute = t.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  TimeOfDay get _result {
    int h = _hour12 == 12 ? 0 : _hour12;
    if (!_isAm) h += 12;
    return TimeOfDay(hour: h, minute: _minute);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 핸들 바 ──
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── 타이틀 ──
          Text(
            widget.title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 20),

          // ── 오전/오후 토글 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _AmPmToggle(
                    label: '오전',
                    selected: _isAm,
                    onTap: () => setState(() => _isAm = true),
                  ),
                  _AmPmToggle(
                    label: '오후',
                    selected: !_isAm,
                    onTap: () => setState(() => _isAm = false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── 시·분 휠 ──
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 선택 영역 하이라이트 바
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                // 휠 Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 시(時) 휠
                    SizedBox(
                      width: 88,
                      child: ListWheelScrollView.useDelegate(
                        controller: _hourCtrl,
                        itemExtent: 52,
                        perspective: 0.003,
                        diameterRatio: 2.0,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) =>
                            setState(() => _hour12 = i + 1),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 12,
                          builder: (context, index) {
                            final h = index + 1;
                            final selected = h == _hour12;
                            return Center(
                              child: Text(
                                '$h',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  fontSize: selected ? 26 : 18,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.gray300,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // 구분자
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                          color: AppColors.gray700,
                        ),
                      ),
                    ),
                    // 분(分) 휠
                    SizedBox(
                      width: 88,
                      child: ListWheelScrollView.useDelegate(
                        controller: _minuteCtrl,
                        itemExtent: 52,
                        perspective: 0.003,
                        diameterRatio: 2.0,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) =>
                            setState(() => _minute = i),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 60,
                          builder: (context, index) {
                            final selected = index == _minute;
                            return Center(
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  fontSize: selected ? 26 : 18,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.gray300,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 미리보기 텍스트 ──
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 20),
            child: Text(
              '${_isAm ? '오전' : '오후'} $_hour12:${_minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),

          // ── 확인 버튼 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_result),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  '확인',
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
        ],
      ),
    );
  }
}

class _AmPmToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AmPmToggle(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: selected ? AppColors.white : AppColors.gray400,
            ),
          ),
        ),
      ),
    );
  }
}
