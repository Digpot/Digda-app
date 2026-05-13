import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/membership/models/membership_models.dart';
import '../../features/schedule/models/schedule_models.dart';
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
  final bool _allDay = false;
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
      _titleController.text.trim().isNotEmpty && !_saving;

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
      List<String> initialIds = members.map((m) => m.userId).toList();

      if (_isEdit) {
        // 편집 모드 — 기존 일정으로 폼 채움
        final detail =
            await Di.scheduleRepository.detail(groupId, _editingScheduleId!);
        final s = detail.schedule;
        _titleController.text = s.title;
        _startDate = s.startDate;
        _endDate = s.endDate;
        _selectedColor = _parseHex(s.color);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessageOf(e))));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessageOf(e))));
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
                      _buildSectionLabel('시간'),
                      const SizedBox(height: 8),
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
                              child: _buildTimeField(_formatTime(_endTime)),
                            ),
                          ),
                        ],
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

  Widget _buildSmallAvatar(Color color, String name) {
    final initial = name.isNotEmpty ? name[0] : '?';
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
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
