import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:world_holidays/world_holidays.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/common/models/common_models.dart';
import '../../features/membership/models/membership_models.dart';
import '../../features/schedule/models/schedule_models.dart' as api;
import '../../theme/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/notification_bell_icon.dart';

/// 일정 캘린더 뷰 모드 — 월/주/일.
enum _CalView { month, week, day }

class _Schedule {
  final String? id;
  final String title;
  final Color color;
  final DateTime start;
  final DateTime end;
  final String? time;
  final List<UserSummary> participants;
  final DateTime createdAt;
  final bool allDay;

  /// 타임라인 정렬 키 — 종일/다일은 -1(상단), 시간 일정은 0~1439(분).
  final int sortMinutes;

  /// 타임라인 좌측 시간 레일 라벨 — '종일' 또는 '오전 7시'.
  final String railLabel;

  const _Schedule({
    this.id,
    required this.title,
    required this.color,
    required this.start,
    DateTime? end,
    this.time,
    this.participants = const [],
    required this.createdAt,
    this.allDay = true,
    this.sortMinutes = -1,
    this.railLabel = '종일',
  }) : end = end ?? start;

  /// 'HH:mm[:ss]' → '오전 9시', '오후 2시 30분' 같은 한글 표기.
  static String _toKorean(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    final period = h < 12 ? '오전' : '오후';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    if (m == 0) return '$period $hour12시';
    return '$period $hour12시 ${m.toString().padLeft(2, '0')}분';
  }

  /// 서버 Schedule → 화면용 _Schedule.
  factory _Schedule.fromApi(api.Schedule s) {
    final cleaned = s.color.replaceAll('#', '');
    final argb = int.tryParse('FF$cleaned', radix: 16);
    final color = argb != null ? Color(argb) : AppColors.primary;
    String? time;
    var sortMinutes = -1;
    var railLabel = '종일';
    if (s.allDay) {
      time = '종일';
    } else if (s.startTime != null) {
      time = s.endTime != null
          ? '${_toKorean(s.startTime!)} - ${_toKorean(s.endTime!)}'
          : _toKorean(s.startTime!);
      railLabel = _toKorean(s.startTime!);
      final parts = s.startTime!.split(':');
      final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      sortMinutes = h * 60 + m;
    }
    return _Schedule(
      id: s.id,
      title: s.title,
      color: color,
      start: DateTime.utc(s.startDate.year, s.startDate.month, s.startDate.day),
      end: DateTime.utc(s.endDate.year, s.endDate.month, s.endDate.day),
      time: time,
      participants: s.participants,
      createdAt: s.createdAt,
      allDay: s.allDay,
      sortMinutes: sortMinutes,
      railLabel: railLabel,
    );
  }

  bool get isMultiDay =>
      start.year != end.year ||
      start.month != end.month ||
      start.day != end.day;

  bool coversDay(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    final s = DateTime.utc(start.year, start.month, start.day);
    final e = DateTime.utc(end.year, end.month, end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  bool isStartDay(DateTime day) => isSameDay(start, day);
  bool isEndDay(DateTime day) => isSameDay(end, day);
}

class ScheduleCalendarScreen extends StatefulWidget {
  const ScheduleCalendarScreen({super.key});

  @override
  State<ScheduleCalendarScreen> createState() =>
      _ScheduleCalendarScreenState();
}

class _ScheduleCalendarScreenState extends State<ScheduleCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// 뷰 모드(월/주/일).
  _CalView _view = _CalView.month;

  /// 공휴일 맵: 날짜(utc normalized) → 공휴일명
  final Map<DateTime, String> _holidays = {};

  /// 멤버 필터 — 그룹 구성원 목록과 선택된 userId 집합(빈 집합 = 전체).
  List<Membership> _members = [];
  final Set<String> _memberFilter = {};

  /// 멤버별 아바타 색 — userId → color.
  final Map<String, Color> _memberColors = {};

  @override
  void initState() {
    super.initState();
    _loadHolidays();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMembers();
      _loadSchedules();
    });
  }

  Future<void> _loadMembers() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    try {
      final members = await Di.membershipRepository.list(groupId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _memberColors.clear();
        for (final m in members) {
          final cleaned = m.color.replaceAll('#', '');
          final argb = int.tryParse('FF$cleaned', radix: 16);
          _memberColors[m.userId] =
              argb != null ? Color(argb) : AppColors.primary;
        }
      });
    } catch (_) {
      // 멤버 로드 실패는 필터 비활성 상태로 무시.
    }
  }

  /// 서버에서 받아온 전체 일정(필터 전).
  List<_Schedule> _allSchedules = [];

  Future<void> _loadSchedules() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) {
      setState(() {
        _allSchedules = [];
        _applyMemberFilter();
      });
      return;
    }
    final start = DateTime.utc(_focusedDay.year, _focusedDay.month, 1);
    final end = DateTime.utc(_focusedDay.year, _focusedDay.month + 1, 0);
    try {
      final list = await Di.scheduleRepository.list(
        groupId,
        startDate: start,
        endDate: end,
      );
      if (!mounted) return;
      setState(() {
        // 최신 생성 일정이 위에 표시되도록 createdAt 내림차순 정렬
        _allSchedules = list.map(_Schedule.fromApi).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _applyMemberFilter();
      });
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  /// 멤버 필터를 적용해 표시용 `_schedules` 를 갱신하고 레인을 재계산.
  /// 필터가 비어 있으면 전체 노출. 선택 시 참석자에 한 명이라도 포함되면 노출.
  void _applyMemberFilter() {
    if (_memberFilter.isEmpty) {
      _schedules = List.of(_allSchedules);
    } else {
      _schedules = _allSchedules.where((s) {
        return s.participants.any((p) => _memberFilter.contains(p.id));
      }).toList();
    }
    _computeLaneAssignments();
  }

  void _toggleMemberFilter(String userId) {
    setState(() {
      if (_memberFilter.contains(userId)) {
        _memberFilter.remove(userId);
      } else {
        _memberFilter.add(userId);
      }
      _applyMemberFilter();
    });
  }

  void _clearMemberFilter() {
    setState(() {
      _memberFilter.clear();
      _applyMemberFilter();
    });
  }

  void _changeMonth(DateTime newMonth) {
    setState(() {
      _focusedDay = newMonth;
      _selectedDay = null;
    });
    _loadSchedules();
  }

  /// '오늘' 칩 — 다른 달 탐색 후 현재 달로 즉시 복귀.
  void _goToday() {
    final now = DateTime.now();
    final sameMonth =
        _focusedDay.year == now.year && _focusedDay.month == now.month;
    setState(() {
      _focusedDay = now;
      _selectedDay = null;
    });
    if (!sameMonth) _loadSchedules();
  }

  Future<void> _loadHolidays() async {
    final wh = WorldHolidays();
    // 2024~2026 한국 공휴일 로드
    final holidays = await wh.getHolidays('KR');
    if (!mounted) return;
    setState(() {
      for (final h in holidays) {
        // national만 (기념일 제외, 법정 공휴일만)
        if (h.type == HolidayType.national) {
          final key = DateTime.utc(h.date.year, h.date.month, h.date.day);
          _holidays[key] = h.descriptionKo ?? h.name;
        }
      }
    });
  }

  /// 공휴일 이름
  String? _getHolidayName(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return _holidays[key];
  }

  // 일정 데이터 — API 로드 결과로 채워짐
  List<_Schedule> _schedules = [];

  // 주(row)별 레인 배정: 주 일요일 → (일정 객체 → 레인 인덱스)
  final Map<DateTime, Map<_Schedule, int>> _weekLaneMap = {};
  final Map<DateTime, int> _weekMaxLane = {};

  /// 해당 날의 주(row) 시작 일요일 반환
  DateTime _weekSunday(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    return d.subtract(Duration(days: d.weekday % 7));
  }

  /// 일정 목록 기준으로 주별 레인을 탐욕 알고리즘으로 배정.
  /// 다중 날짜 일정(긴 것)이 우선적으로 낮은 레인을 차지해 가로로 이어지게 한다.
  void _computeLaneAssignments() {
    _weekLaneMap.clear();
    _weekMaxLane.clear();

    // 모든 일정이 걸치는 주 일요일 수집
    final Set<DateTime> weekSundays = {};
    for (final s in _schedules) {
      var d = _weekSunday(s.start);
      final eDate = DateTime.utc(s.end.year, s.end.month, s.end.day);
      while (!d.isAfter(eDate)) {
        weekSundays.add(d);
        d = d.add(const Duration(days: 7));
      }
    }

    for (final weekSun in weekSundays) {
      final weekSat = weekSun.add(const Duration(days: 6));

      // 이 주에 걸치는 일정을 기간 내림차순 → 시작일 오름차순으로 정렬
      final weekSchedules = _schedules.where((s) {
        final sd = DateTime.utc(s.start.year, s.start.month, s.start.day);
        final ed = DateTime.utc(s.end.year, s.end.month, s.end.day);
        return !ed.isBefore(weekSun) && !sd.isAfter(weekSat);
      }).toList()
        ..sort((a, b) {
          final aDays = a.end.difference(a.start).inDays;
          final bDays = b.end.difference(b.start).inDays;
          if (aDays != bDays) return bDays.compareTo(aDays);
          return a.start.compareTo(b.start);
        });

      // 탐욕적 레인 배정
      final List<List<_Schedule>> lanes = [];
      final Map<_Schedule, int> assignments = {};

      for (final schedule in weekSchedules) {
        final sd = DateTime.utc(schedule.start.year, schedule.start.month, schedule.start.day);
        final ed = DateTime.utc(schedule.end.year, schedule.end.month, schedule.end.day);
        final visStart = sd.isAfter(weekSun) ? sd : weekSun;
        final visEnd = ed.isBefore(weekSat) ? ed : weekSat;

        int assignedLane = -1;
        for (int i = 0; i < lanes.length; i++) {
          bool conflict = false;
          for (final existing in lanes[i]) {
            final exS = DateTime.utc(existing.start.year, existing.start.month, existing.start.day);
            final exE = DateTime.utc(existing.end.year, existing.end.month, existing.end.day);
            final exVS = exS.isAfter(weekSun) ? exS : weekSun;
            final exVE = exE.isBefore(weekSat) ? exE : weekSat;
            if (!visEnd.isBefore(exVS) && !visStart.isAfter(exVE)) {
              conflict = true;
              break;
            }
          }
          if (!conflict) {
            assignedLane = i;
            break;
          }
        }

        if (assignedLane == -1) {
          assignedLane = lanes.length;
          lanes.add([]);
        }
        lanes[assignedLane].add(schedule);
        assignments[schedule] = assignedLane;
      }

      _weekLaneMap[weekSun] = assignments;
      _weekMaxLane[weekSun] = assignments.values.isEmpty
          ? -1
          : assignments.values.fold(-1, (a, b) => a > b ? a : b);
    }
  }

  /// 해당 날짜에 걸치는 모든 일정
  List<_Schedule> _getSchedulesForDay(DateTime day) {
    return _schedules.where((s) => s.coversDay(day)).toList();
  }

  /// 사용자 일정만
  List<_Schedule> _getUserSchedulesForDay(DateTime day) {
    return _getSchedulesForDay(day);
  }

  /// eventLoader용 (TableCalendar에 전달)
  List<dynamic> _eventLoader(DateTime day) {
    return _getSchedulesForDay(day);
  }

  void _showMonthPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030, 12, 31),
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
      _changeMonth(picked);
    }
  }

  void _showDayDetail(DateTime day) {
    final userSchedules = _getUserSchedulesForDay(day);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DayDetailBottomSheet(
        day: day,
        schedules: userSchedules,
        onAddSchedule: () async {
          Navigator.of(context).pop();
          await Navigator.of(context).pushNamed(
            '/add-schedule',
            arguments: {'date': day.toIso8601String()},
          );
          _loadSchedules();
        },
        onScheduleTap: (id) async {
          Navigator.of(context).pop();
          await Navigator.of(context).pushNamed(
            '/schedule-detail',
            arguments: id,
          );
          _loadSchedules();
        },
      ),
    ).then((_) {
      setState(() => _selectedDay = null);
    });
  }

  Widget _buildDayCell(
    DateTime day,
    double rowHeight,
    double cellWidth, {
    Color? circleBg,
    required Color textColor,
    bool isOutside = false,
    bool squareHighlight = false,
  }) {
    final holidayName = isOutside ? null : _getHolidayName(day);
    final dayTextColor =
        (holidayName != null && circleBg == null) ? AppColors.eventHoliday : textColor;

    // 레인 기반 렌더링
    final weekSun = _weekSunday(day);
    final laneAssignments = isOutside ? <_Schedule, int>{} : (_weekLaneMap[weekSun] ?? <_Schedule, int>{});
    final daySchedules = isOutside ? <_Schedule>[] : _getSchedulesForDay(day);

    // 이 날의 레인 → 일정 맵
    final Map<int, _Schedule> laneToSchedule = {};
    for (final s in daySchedules) {
      final lane = laneAssignments[s];
      if (lane != null) laneToSchedule[lane] = s;
    }

    // 공휴일이 있으면 사용자 일정 슬롯 2개, 없으면 3개
    final eventSlots = holidayName != null ? 2 : 3;
    final weekMax = _weekMaxLane[weekSun] ?? -1;

    // 이 날 기준 오버플로우 여부 및 숨겨진 일정 수
    final hiddenCount = laneToSchedule.keys.where((l) => l >= eventSlots).length;
    final hasOverflow = hiddenCount > 0;
    final displayMax = hasOverflow ? eventSlots - 1 : eventSlots;
    final visibleLaneCount = weekMax < 0 ? 0 : (weekMax + 1 < displayMax ? weekMax + 1 : displayMax);

    return SizedBox(
      height: rowHeight,
      child: Column(
        children: [
          const SizedBox(height: 4),
          if (circleBg != null)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: circleBg,
                shape: squareHighlight ? BoxShape.rectangle : BoxShape.circle,
                borderRadius:
                    squareHighlight ? BorderRadius.circular(8) : null,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: textColor,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 24,
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: dayTextColor,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 2),
          // 공휴일 pill
          if (holidayName != null)
            Container(
              height: 14,
              margin: const EdgeInsets.only(top: 1, left: 2, right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: AppColors.eventHoliday.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                holidayName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 8,
                  color: AppColors.eventHoliday,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          // 레인별 이벤트 pill (빈 레인은 placeholder로 세로 정렬 유지)
          for (int lane = 0; lane < visibleLaneCount; lane++)
            laneToSchedule.containsKey(lane)
                ? _buildEventPill(day, laneToSchedule[lane]!, cellWidth)
                : const SizedBox(height: 15),
          // 오버플로우 pill: 숨겨진 개수를 +N 형태로 표시
          if (hasOverflow) _buildMorePill(hiddenCount),
        ],
      ),
    );
  }

  Widget _buildMorePill(int count) {
    return Container(
      height: 14,
      margin: const EdgeInsets.only(top: 1, left: 2, right: 2),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 8,
          color: AppColors.gray700,
        ),
      ),
    );
  }

  /// 현재 주(row) 내에서 이벤트가 차지하는 셀 수와 시작 오프셋 계산
  ({int span, int offsetFromStart}) _rowSpanInfo(DateTime day, _Schedule schedule) {
    final d = DateTime.utc(day.year, day.month, day.day);
    final s = DateTime.utc(schedule.start.year, schedule.start.month, schedule.start.day);
    final e = DateTime.utc(schedule.end.year, schedule.end.month, schedule.end.day);

    // 이번 주 일요일~토요일
    final rowSunday = d.subtract(Duration(days: d.weekday % 7));
    final rowSaturday = rowSunday.add(const Duration(days: 6));

    // 이번 주 내 실제 보이는 구간
    final visStart = s.isAfter(rowSunday) ? s : rowSunday;
    final visEnd = e.isBefore(rowSaturday) ? e : rowSaturday;

    final span = visEnd.difference(visStart).inDays + 1; // 셀 수
    final offsetFromStart = d.difference(visStart).inDays; // 현재 셀이 구간 시작에서 몇 번째
    return (span: span, offsetFromStart: offsetFromStart);
  }

  Widget _buildEventPill(DateTime day, _Schedule schedule, double cellWidth) {
    final color = schedule.color;
    final isStart = schedule.isStartDay(day);
    final isEnd = schedule.isEndDay(day);
    final isMulti = schedule.isMultiDay;

    // 단일 일정 — 둥근 pill
    if (!isMulti) {
      return Container(
        height: 14,
        margin: const EdgeInsets.only(top: 1, left: 2, right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          schedule.title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 8,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }

    // 다일 일정 — 연결 바
    final isRowStart = day.weekday == DateTime.sunday;
    final isRowEnd = day.weekday == DateTime.saturday;

    final roundLeft = isStart || isRowStart;
    final roundRight = isEnd || isRowEnd;

    final info = _rowSpanInfo(day, schedule);

    // 배경 바 (모든 셀에 그려짐)
    final barDecoration = BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.horizontal(
        left: roundLeft ? const Radius.circular(4) : Radius.zero,
        right: roundRight ? const Radius.circular(4) : Radius.zero,
      ),
    );

    // 시작 셀에서만 전체 span 너비의 텍스트를 overflow로 렌더링
    final isVisibleStart = isStart || isRowStart;
    if (isVisibleStart) {
      // 전체 바 너비 = 셀 너비 × span - 좌우 margin 보정
      final totalBarWidth = cellWidth * info.span - (roundLeft ? 2 : 0) - (roundRight ? 2 : 0);
      return Container(
        height: 14,
        margin: EdgeInsets.only(
          top: 1,
          left: roundLeft ? 2 : 0,
          right: roundRight ? 2 : 0,
        ),
        decoration: barDecoration,
        child: OverflowBox(
          maxWidth: totalBarWidth,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: totalBarWidth,
            child: Center(
              child: Text(
                schedule.title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 8,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ),
      );
    }

    // 나머지 셀 — 배경만
    return Container(
      height: 14,
      margin: EdgeInsets.only(
        top: 1,
        left: roundLeft ? 2 : 0,
        right: roundRight ? 2 : 0,
      ),
      decoration: barDecoration,
    );
  }

  // ─── 공통 네비게이션 ──────────────────────────────────────────────────────────
  Future<void> _openDetail(String? id) async {
    if (id == null) return;
    await Navigator.of(context).pushNamed('/schedule-detail', arguments: id);
    _loadSchedules();
  }

  Future<void> _openAdd(DateTime? day) async {
    await Navigator.of(context).pushNamed(
      '/add-schedule',
      arguments: day != null ? {'date': day.toIso8601String()} : null,
    );
    _loadSchedules();
  }

  // ─── 뷰 토글 (월/주/일) ───────────────────────────────────────────────────────
  Widget _buildViewToggle() {
    Widget seg(String label, _CalView v) {
      final active = _view == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _view = v;
            if (v == _CalView.day && _selectedDay == null) {
              _selectedDay = _focusedDay;
            }
          }),
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: active ? AppColors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.gray900.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
                color: active ? AppColors.primary : AppColors.gray500,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            seg('월', _CalView.month),
            seg('주', _CalView.week),
            seg('일', _CalView.day),
          ],
        ),
      ),
    );
  }

  // ─── 멤버 필터 ────────────────────────────────────────────────────────────────
  Widget _buildMemberFilter() {
    if (_members.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 52,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _allChip(),
          const SizedBox(width: 8),
          for (final m in _members) ...[
            _memberAvatar(m),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _allChip() {
    final active = _memberFilter.isEmpty;
    return GestureDetector(
      onTap: _clearMemberFilter,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.gray50,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '전체',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: active ? AppColors.white : AppColors.gray500,
          ),
        ),
      ),
    );
  }

  Widget _memberAvatar(Membership m) {
    final selected = _memberFilter.contains(m.userId);
    final dimmed = _memberFilter.isNotEmpty && !selected;
    final color = _memberColors[m.userId] ?? AppColors.primary;
    return GestureDetector(
      onTap: () => _toggleMemberFilter(m.userId),
      child: Opacity(
        opacity: dimmed ? 0.4 : 1,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : AppColors.white,
                  width: selected ? 2 : 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: m.profileImage != null && m.profileImage!.isNotEmpty
                  ? Image.network(
                      m.profileImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _avatarInitial(m.name, color),
                    )
                  : _avatarInitial(m.name, color),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                m.name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _avatarInitial(String name, Color color) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: color,
        ),
      ),
    );
  }

  // ─── 주 뷰 — 7일 컬럼 ─────────────────────────────────────────────────────────
  Widget _buildWeekView(BoxConstraints constraints) {
    final weekSun = _weekSunday(_focusedDay);
    final days = List.generate(7, (i) => weekSun.add(Duration(days: i)));
    const labels = ['일', '월', '화', '수', '목', '금', '토'];

    Color dayColor(DateTime d) => d.weekday == DateTime.saturday
        ? AppColors.blue
        : d.weekday == DateTime.sunday
            ? AppColors.primary
            : AppColors.gray900;

    bool isToday(DateTime d) {
      final n = DateTime.now();
      return d.year == n.year && d.month == n.month && d.day == n.day;
    }

    Widget header(DateTime d) {
      final today = isToday(d);
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _selectedDay = d;
            _view = _CalView.day;
          }),
          child: Column(
            children: [
              Text(
                labels[d.weekday % 7],
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
                  color: dayColor(d).withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: today ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${d.day}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: today ? AppColors.white : dayColor(d),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget column(DateTime d) {
      final list = _schedulesTimelineSorted(_getSchedulesForDay(d));
      return Expanded(
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.gray50, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            children: [
              for (final s in list) _weekChip(s),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: days.map(header).toList()),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1, color: AppColors.gray100),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: days.map(column).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _weekChip(_Schedule s) {
    return GestureDetector(
      onTap: () => _openDetail(s.id),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: s.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          s.title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 9,
            color: s.color,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ─── 일 뷰 — 시간 레일 타임라인 ────────────────────────────────────────────────
  Widget _buildDayView() {
    final day = _selectedDay ?? _focusedDay;
    final list = _schedulesTimelineSorted(_getSchedulesForDay(day));
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final label =
        '${day.month}월 ${day.day}일 ${weekdays[day.weekday - 1]}요일';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '일정 ${list.length}개',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _openAdd(day),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: AppColors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? _dayEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 24, 24),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _timelineRow(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _dayEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_outlined,
              size: 48, color: AppColors.gray200),
          SizedBox(height: 12),
          Text(
            '이 날은 비어 있어요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  List<_Schedule> _schedulesTimelineSorted(List<_Schedule> input) {
    final list = [...input];
    list.sort((a, b) {
      final at = (a.allDay || a.isMultiDay) ? -1 : a.sortMinutes;
      final bt = (b.allDay || b.isMultiDay) ? -1 : b.sortMinutes;
      if (at != bt) return at.compareTo(bt);
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  Widget _timelineRow(_Schedule schedule) {
    final railTop =
        (schedule.allDay || schedule.isMultiDay) ? '종일' : schedule.railLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                railTop,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: schedule.color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: _inlineEventCard(schedule)),
        ],
      ),
    );
  }

  Widget _inlineEventCard(_Schedule schedule) {
    final color = schedule.color;
    var timeText = schedule.time ?? '종일';
    if (schedule.isMultiDay) {
      timeText =
          '${schedule.start.month}/${schedule.start.day} - ${schedule.end.month}/${schedule.end.day}';
    }
    return GestureDetector(
      onTap: () => _openDetail(schedule.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schedule.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.gray900,
                    ),
                  ),
                ],
              ),
            ),
            _inlineAvatarStack(schedule),
          ],
        ),
      ),
    );
  }

  Widget _inlineAvatarStack(_Schedule schedule) {
    final participants = schedule.participants.take(3).toList();
    if (participants.isEmpty) return const SizedBox.shrink();
    const palette = [AppColors.primary, AppColors.blue, AppColors.green];
    return SizedBox(
      width: 28 + (participants.length - 1) * 16.0,
      height: 28,
      child: Stack(
        children: List.generate(participants.length, (i) {
          final p = participants[i];
          final color = _memberColors[p.id] ?? palette[i % palette.length];
          return Positioned(
            left: i * 16.0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: p.profileImage != null && p.profileImage!.isNotEmpty
                  ? Image.network(
                      p.profileImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _avatarInitial(p.name, color),
                    )
                  : _avatarInitial(p.name, color),
            ),
          );
        }),
      ),
    );
  }

  // ─── 검색 ────────────────────────────────────────────────────────────────────
  void _showSearch() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setSheetState) {
                  final q = controller.text.trim().toLowerCase();
                  final results = q.isEmpty
                      ? <_Schedule>[]
                      : _allSchedules
                          .where((s) => s.title.toLowerCase().contains(q))
                          .toList();
                  return Container(
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: TextField(
                            controller: controller,
                            autofocus: true,
                            onChanged: (_) => setSheetState(() {}),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              color: AppColors.gray900,
                            ),
                            decoration: InputDecoration(
                              hintText: '일정 제목 검색',
                              hintStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                color: AppColors.gray400,
                              ),
                              prefixIcon: const Icon(Icons.search,
                                  size: 20, color: AppColors.gray500),
                              filled: true,
                              fillColor: AppColors.gray50,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: q.isEmpty
                              ? const Center(
                                  child: Text(
                                    '이번 달 일정에서 검색해요',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: AppColors.gray400,
                                    ),
                                  ),
                                )
                              : results.isEmpty
                                  ? const Center(
                                      child: Text(
                                        '검색 결과가 없어요',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          color: AppColors.gray400,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: scrollController,
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 0, 20, 24),
                                      itemCount: results.length,
                                      itemBuilder: (context, i) =>
                                          _searchResultRow(results[i]),
                                    ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _searchResultRow(_Schedule s) {
    final dateText = s.isMultiDay
        ? '${s.start.month}/${s.start.day} - ${s.end.month}/${s.end.day}'
        : '${s.start.month}월 ${s.start.day}일 · ${s.time ?? '종일'}';
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        _openDetail(s.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray100),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: s.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.gray900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: AppColors.gray500,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더 - 제목 "일정" + 우측 아이콘
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Text(
                    '일정',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.gray900,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showSearch,
                    child: const Icon(
                      Icons.search,
                      size: 22,
                      color: AppColors.gray700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const NotificationBellIcon(),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed('/my-page'),
                    child: const Icon(
                      Icons.settings_outlined,
                      size: 22,
                      color: AppColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
            // 날짜 네비게이션 — 좌측 월 이동 + 우측 '오늘' 칩
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _changeMonth(DateTime(
                      _focusedDay.year,
                      _focusedDay.month - 1,
                    )),
                    child: const Icon(
                      Icons.chevron_left,
                      size: 22,
                      color: AppColors.gray500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showMonthPicker(),
                    child: Text(
                      '${_focusedDay.year}년 ${_focusedDay.month}월',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.gray900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _changeMonth(DateTime(
                      _focusedDay.year,
                      _focusedDay.month + 1,
                    )),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 22,
                      color: AppColors.gray500,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _goToday,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        child: Text(
                          '오늘',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 뷰 토글 (월/주/일) + 멤버 필터
            _buildViewToggle(),
            _buildMemberFilter(),
            // 본문 — 월/주/일 뷰 전환
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_view == _CalView.week) {
                    return _buildWeekView(constraints);
                  }
                  if (_view == _CalView.day) {
                    return _buildDayView();
                  }
                  final rowHeight =
                      ((constraints.maxHeight - 28) / 6).clamp(64.0, 100.0);
                  final cellWidth = constraints.maxWidth / 7;
                  return TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    startingDayOfWeek: StartingDayOfWeek.sunday,
                    selectedDayPredicate: (day) =>
                        isSameDay(_selectedDay, day),
                    eventLoader: _eventLoader,
                    calendarFormat: CalendarFormat.month,
                    headerVisible: false,
                    daysOfWeekHeight: 24,
                    rowHeight: rowHeight,
                    calendarStyle: const CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.white,
                      ),
                      todayDecoration: BoxDecoration(),
                      todayTextStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.white,
                      ),
                      defaultTextStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        color: AppColors.gray900,
                      ),
                      weekendTextStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                      outsideTextStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        color: AppColors.gray300,
                      ),
                      markersMaxCount: 2,
                      cellAlignment: Alignment.topCenter,
                      cellMargin: EdgeInsets.zero,
                      cellPadding: EdgeInsets.zero,
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 11,
                        color: AppColors.gray500,
                      ),
                      weekendStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 11,
                        color: AppColors.gray500,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      dowBuilder: (context, day) {
                        const labels = ['월', '화', '수', '목', '금', '토', '일'];
                        final color = day.weekday == DateTime.saturday
                            ? AppColors.blue
                            : day.weekday == DateTime.sunday
                                ? AppColors.primary
                                : AppColors.gray500;
                        return Center(
                          child: Text(
                            labels[day.weekday - 1],
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              fontSize: 11,
                              color: color,
                            ),
                          ),
                        );
                      },
                      defaultBuilder: (context, day, focusedDay) {
                        final textColor = day.weekday == DateTime.saturday
                            ? AppColors.blue
                            : day.weekday == DateTime.sunday
                                ? AppColors.primary
                                : AppColors.gray900;
                        return _buildDayCell(
                          day,
                          rowHeight,
                          cellWidth,
                          textColor: textColor,
                        );
                      },
                      todayBuilder: (context, day, focusedDay) {
                        // 오늘 = coral 라운드 스퀘어 강조 (기존 검정 원에서 변경).
                        return _buildDayCell(
                          day,
                          rowHeight,
                          cellWidth,
                          circleBg: AppColors.primary,
                          textColor: AppColors.white,
                          squareHighlight: true,
                        );
                      },
                      selectedBuilder: (context, day, focusedDay) {
                        return _buildDayCell(
                          day,
                          rowHeight,
                          cellWidth,
                          circleBg: AppColors.primary,
                          textColor: AppColors.white,
                        );
                      },
                      outsideBuilder: (context, day, focusedDay) {
                        return _buildDayCell(
                          day,
                          rowHeight,
                          cellWidth,
                          textColor: AppColors.gray300,
                          isOutside: true,
                        );
                      },
                      markerBuilder: (context, day, events) {
                        return const SizedBox.shrink();
                      },
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _showDayDetail(selectedDay);
                    },
                    onPageChanged: (focusedDay) {
                      setState(() => _focusedDay = focusedDay);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60, right: 20),
        child: SizedBox(
          width: 68,
          height: 68,
          child: FloatingActionButton(
            onPressed: () =>
                Navigator.of(context).pushNamed('/add-schedule').then((_) => _loadSchedules()),
            backgroundColor: AppColors.primary,
            shape: const CircleBorder(),
            elevation: 4,
            child: const Icon(Icons.add, color: AppColors.white, size: 30),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }
}

class _DayDetailBottomSheet extends StatelessWidget {
  final DateTime day;
  final List<_Schedule> schedules;
  final VoidCallback onAddSchedule;
  final ValueChanged<String?> onScheduleTap;

  const _DayDetailBottomSheet({
    required this.day,
    required this.schedules,
    required this.onAddSchedule,
    required this.onScheduleTap,
  });

  String _formatDayLabel(DateTime day) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[day.weekday - 1];
    return '${day.month}월 ${day.day}일 $weekday요일';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final sorted = _timelineSorted;
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
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
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDayLabel(day),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: AppColors.gray900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '일정 ${schedules.length}개',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onAddSchedule,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: schedules.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: scrollController,
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 24,
                          bottom:
                              MediaQuery.of(context).padding.bottom + 16,
                        ),
                        itemCount: sorted.length,
                        itemBuilder: (context, index) =>
                            _buildTimelineItem(sorted[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 종일/다일 일정을 상단에, 시간 일정을 시간순으로 정렬.
  List<_Schedule> get _timelineSorted {
    final list = [...schedules];
    list.sort((a, b) {
      final at = (a.allDay || a.isMultiDay) ? -1 : a.sortMinutes;
      final bt = (b.allDay || b.isMultiDay) ? -1 : b.sortMinutes;
      if (at != bt) return at.compareTo(bt);
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  /// 타임라인 한 줄 — 좌측 시간 레일 + 우측 이벤트 카드.
  Widget _buildTimelineItem(_Schedule schedule) {
    final railTop =
        (schedule.allDay || schedule.isMultiDay) ? '종일' : schedule.railLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                railTop,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: schedule.color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: _buildEventCard(schedule)),
        ],
      ),
    );
  }

  Widget _buildEventCard(_Schedule schedule) {
    final color = schedule.color;
    String timeText = schedule.time ?? '종일';
    if (schedule.isMultiDay) {
      timeText =
          '${schedule.start.month}/${schedule.start.day} - ${schedule.end.month}/${schedule.end.day}';
    }
    return GestureDetector(
      onTap: () => onScheduleTap(schedule.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schedule.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.gray900,
                    ),
                  ),
                ],
              ),
            ),
            _buildAvatarStack(schedule),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: AppColors.gray200,
          ),
          SizedBox(height: 12),
          Text(
            '일정이 없어요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack(_Schedule schedule) {
    final participants = schedule.participants.take(3).toList();
    if (participants.isEmpty) return const SizedBox.shrink();
    const palette = [
      AppColors.primary,
      AppColors.blue,
      AppColors.green,
    ];
    return SizedBox(
      width: 28 + (participants.length - 1) * 16.0,
      height: 28,
      child: Stack(
        children: List.generate(participants.length, (i) {
          final p = participants[i];
          final color = palette[i % palette.length];
          return Positioned(
            left: i * 16.0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: p.profileImage != null && p.profileImage!.isNotEmpty
                  ? Image.network(
                      p.profileImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _avatarFallback(p.name, color),
                    )
                  : _avatarFallback(p.name, color),
            ),
          );
        }),
      ),
    );
  }

  Widget _avatarFallback(String name, Color color) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}
