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

  /// 날짜별 기존 일정 색 — 숫자 아래 점으로 찍어 "그날 이미 뭐가 있는지" 보여준다.
  /// 하루에 여러 일정이면 색이 여럿, 같은 색은 한 번만.
  final Map<DateTime, List<Color>> _existing = {};

  /// 이미 조회한 달(yyyy-MM) — 앞뒤로 왔다 갔다 해도 다시 부르지 않는다.
  final Set<String> _loadedMonths = {};

  @override
  void initState() {
    super.initState();
    final start = widget.schedule.startDate;
    _visibleMonth = DateTime(start.year, start.month, 1);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadExisting(_visibleMonth));
  }

  static Color _parseColor(String hex, Color fallback) {
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : fallback;
  }

  Color get _accent => _parseColor(widget.schedule.color, AppColors.primary);

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  /// 보이는 6주(42칸) 범위의 기존 일정을 받아 날짜별 색으로 접어 둔다.
  /// 실패하면 점만 안 보일 뿐 복사 자체엔 지장이 없으므로 조용히 넘어간다.
  Future<void> _loadExisting(DateTime month) async {
    final key = _monthKey(month);
    if (_loadedMonths.contains(key)) return;
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    _loadedMonths.add(key);
    final gridStart = _gridStartOf(month);
    try {
      final schedules = await Di.scheduleRepository.list(
        groupId,
        startDate: gridStart,
        endDate: gridStart.add(const Duration(days: 41)),
      );
      if (!mounted) return;
      setState(() {
        for (final s in schedules) {
          if (s.hidden) continue;
          final color = _parseColor(s.color, AppColors.gray400);
          // 기간 일정은 걸쳐 있는 날마다 점을 찍는다.
          var day = _dayKey(s.startDate);
          final last = _dayKey(s.endDate);
          for (var guard = 0; !day.isAfter(last) && guard < 400; guard++) {
            final colors = _existing.putIfAbsent(day, () => []);
            if (!colors.contains(color)) colors.add(color);
            day = DateTime(day.year, day.month, day.day + 1);
          }
        }
      });
    } catch (_) {
      // 다음에 이 달을 다시 열면 재시도할 수 있게 표식을 되돌린다.
      _loadedMonths.remove(key);
    }
  }

  /// 일요일 시작 6주 그리드의 첫 칸 날짜.
  DateTime _gridStartOf(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    return first.subtract(Duration(days: first.weekday % 7));
  }

  void _goMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    setState(() => _visibleMonth = next);
    _loadExisting(next);
  }

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

  /// 선택한 날짜 1개를 지울 수 있는 칩. 일정 색으로 은은하게 칠한다.
  Widget _dateChip(DateTime d) {
    final accent = _accent;
    return GestureDetector(
      onTap: () => _toggle(d),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${d.month}월 ${d.day}일',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: accent,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.close_rounded,
                size: 14, color: accent.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
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
          const SizedBox(height: 6),
          Text(
            _selected.isEmpty
                ? '일정을 복사할 날짜를 골라 주세요 · 숫자 아래 점은 그날 이미 있는 일정이에요'
                : '${_selected.length}개 날짜 선택 · 최대 ${ScheduleCopySheet.maxDates}개',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: _selected.isEmpty ? AppColors.gray400 : AppColors.gray500,
            ),
          ),
          // 선택 날짜 칩 — 고른 순서대로, 탭하면 해제. 길어지면 이 블록 안에서만 스크롤.
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 76),
              child: SingleChildScrollView(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: _selected.map(_dateChip).toList(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
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
                          : '${_selected.length}개 날짜에 복사',
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
          onTap: () => _goMonth(-1),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.gray50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_left,
                size: 20, color: AppColors.gray600),
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
          onTap: () => _goMonth(1),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.gray50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_right,
                size: 20, color: AppColors.gray600),
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
    final gridStart = _gridStartOf(_visibleMonth);
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
    final key = _dayKey(day);
    final selected = _isSelected(day);
    final isToday = key == today;
    final inMonth = day.month == _visibleMonth.month;
    final accent = _accent;
    // 그날 이미 있는 일정들의 색 — 최대 3개까지만 점으로 보여준다.
    final existing = _existing[key] ?? const <Color>[];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(day),
      // 작은 화면에서 줄 높이가 모자라도 넘치지 않게 통째로 줄인다.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 38,
            height: 38,
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
                fontWeight:
                    selected || isToday ? FontWeight.w700 : FontWeight.w500,
                fontSize: 16,
                color: selected
                    ? Colors.white
                    : inMonth
                        ? AppColors.gray900
                        : AppColors.gray400,
              ),
            ),
          ),
          const SizedBox(height: 3),
          // 점 자리는 일정이 없어도 비워 둔다 — 있고 없고에 따라 숫자가 튀지 않게.
          SizedBox(
            height: 6,
            child: existing.isEmpty
                ? null
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final c in existing.take(3))
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: inMonth ? c : c.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
        ),
      ),
    );
  }
}
