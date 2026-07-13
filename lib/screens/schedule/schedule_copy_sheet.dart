import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/schedule/models/schedule_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

/// 일정 상세의 '여러 날짜에 복사하기' 바텀시트를 띄운다.
/// 복사에 성공하면 복사된 개수(int)로 pop, 취소하면 null.
Future<int?> showScheduleCopySheet(
  BuildContext context, {
  required Schedule schedule,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ScheduleCopySheet(schedule: schedule),
  );
}

/// 일정을 복사할 날짜들을 고르는 멀티 선택 캘린더 시트.
///
/// 선택된 날짜는 일정의 색으로 칠해지고(파란 일정이면 파란 원), 상단에는
/// 선택한 날짜 목록이 선택한 순서대로 나열된다. 한 번에 최대 31개
/// (서버 MAX_COPY_DATES 와 동일) 까지 고를 수 있다.
class ScheduleCopySheet extends StatefulWidget {
  const ScheduleCopySheet({super.key, required this.schedule});
  final Schedule schedule;

  /// 서버 제한과 동일한 값 — 초과 선택 시 팝업으로 안내한다.
  static const int maxDates = 31;

  @override
  State<ScheduleCopySheet> createState() => _ScheduleCopySheetState();
}

class _ScheduleCopySheetState extends State<ScheduleCopySheet> {
  /// 선택한 순서를 유지한다 — 상단 목록이 사진처럼 고른 순서대로 쌓인다.
  final List<DateTime> _selected = [];
  late DateTime _visibleMonth; // 항상 해당 월 1일
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final start = widget.schedule.startDate;
    _visibleMonth = DateTime(start.year, start.month, 1);
  }

  Color get _accent {
    final cleaned = widget.schedule.color.replaceAll('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : AppColors.primary;
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSelected(DateTime day) => _selected.contains(_dayKey(day));

  void _toggle(DateTime day) {
    final key = _dayKey(day);
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
        return;
      }
      if (_selected.length >= ScheduleCopySheet.maxDates) {
        // setState 밖 컨텍스트로 미루지 않고 바로 안내 — 선택은 추가하지 않는다.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showErrorDialog(
              context,
              '한 번에 최대 ${ScheduleCopySheet.maxDates}개 날짜까지 복사할 수 있어요.',
            );
          }
        });
        return;
      }
      _selected.add(key);
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty || _submitting) return;
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    setState(() => _submitting = true);
    try {
      final copies = await Di.scheduleRepository.copy(
        groupId,
        widget.schedule.id,
        List.of(_selected),
      );
      if (!mounted) return;
      Navigator.of(context).pop(copies.length);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  String _selectedLabel() {
    if (_selected.isEmpty) return '복사할 날짜를 선택해 주세요';
    final parts = _selected.map((d) => '${d.month}월 ${d.day}일').join(', ');
    return '선택: $parts';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final height = MediaQuery.of(context).size.height * 0.82;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 16),
      child: Column(
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
          const SizedBox(height: 20),
          Text(
            widget.schedule.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 19,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 10),
          // 선택 날짜 목록 — 고른 순서대로. 길어지면 이 블록 안에서만 스크롤.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 88),
            child: SingleChildScrollView(
              child: Text(
                _selectedLabel(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.5,
                  color:
                      _selected.isEmpty ? AppColors.gray400 : AppColors.gray600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: AppColors.gray100),
          const SizedBox(height: 12),
          _buildMonthHeader(),
          const SizedBox(height: 8),
          _buildWeekdayRow(),
          const SizedBox(height: 4),
          Expanded(child: _buildDayGrid()),
          const SizedBox(height: 12),
          // CTA — 사진처럼 검정 필 버튼. 선택 없으면 비활성.
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed:
                  _selected.isEmpty || _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gray900,
                disabledBackgroundColor: AppColors.gray200,
                foregroundColor: Colors.white,
                disabledForegroundColor: AppColors.gray400,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _selected.isEmpty
                          ? '날짜를 선택해 주세요'
                          : '선택한 날짜에 일정을 복사하기',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _visibleMonth =
                DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
          }),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child:
                Icon(Icons.chevron_left, size: 24, color: AppColors.gray500),
          ),
        ),
        SizedBox(
          width: 120,
          child: Text(
            '${_visibleMonth.year}. ${_visibleMonth.month}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.gray900,
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _visibleMonth =
                DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
          }),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child:
                Icon(Icons.chevron_right, size: 24, color: AppColors.gray500),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayRow() {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(
                l,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.gray400,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDayGrid() {
    // 일요일 시작 6주(42칸) 고정 — 사진처럼 앞뒤 달 날짜도 노출·선택 가능.
    final first = _visibleMonth;
    final leading = first.weekday % 7; // 일=0, 월=1 ...
    final gridStart = first.subtract(Duration(days: leading));
    final today = _dayKey(DateTime.now());
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = constraints.maxHeight / 6;
        return Column(
          children: [
            for (var week = 0; week < 6; week++)
              SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    for (var d = 0; d < 7; d++)
                      Expanded(
                        child: _buildDayCell(
                          gridStart.add(Duration(days: week * 7 + d)),
                          today,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDayCell(DateTime day, DateTime today) {
    final selected = _isSelected(day);
    final isToday = _dayKey(day) == today;
    final inMonth = day.month == _visibleMonth.month;
    final accent = _accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(day),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // 선택 = 일정 색으로 꽉 찬 원, 오늘 = 옅은 일정 색 원.
            color: selected
                ? accent
                : isToday
                    ? accent.withValues(alpha: 0.14)
                    : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: selected || isToday
                  ? FontWeight.w700
                  : FontWeight.w500,
              fontSize: 16,
              color: selected
                  ? Colors.white
                  : inMonth
                      ? AppColors.gray900
                      : AppColors.gray400,
            ),
          ),
        ),
      ),
    );
  }
}
