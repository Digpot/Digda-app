import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:world_holidays/world_holidays.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/common/models/common_models.dart';
import '../../features/membership/models/membership_models.dart';
import '../../features/schedule/models/schedule_models.dart' as api;
import '../../theme/colors.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/notification_bell_icon.dart';

/// 일정 캘린더 뷰 모드 — 월/주.
enum _CalView { month, week }

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

  /// 공휴일 의사(pseudo) 일정 여부 — true 면 탭/상세 진입 없음, 레인엔 일반 일정과 동일 참여.
  final bool isHoliday;

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
    this.isHoliday = false,
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
    _rebuildHolidaySchedules();
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
          _holidays[key] =
              _resolveHolidayName(h.date.month, h.date.day, h.descriptionKo, h.name);
        }
      }
      // 공휴일도 일반 일정과 동일하게 레인에 배치되도록 의사 일정으로 만든 뒤 재계산.
      _rebuildHolidaySchedules();
      _computeLaneAssignments();
    });
  }

  static final RegExp _hangul = RegExp(r'[가-힣]');

  /// 고정 양력 공휴일 표기 — world_holidays 가 한글명을 안 주거나 영문/날짜 문자열을
  /// 주는 경우(예: "2026")를 막기 위해 우리 표기를 우선한다.
  static const Map<String, String> _solarHolidayNames = {
    '1-1': '신정',
    '3-1': '삼일절',
    '5-5': '어린이날',
    '6-6': '현충일',
    '8-15': '광복절',
    '10-3': '개천절',
    '10-9': '한글날',
    '12-25': '성탄절',
  };

  /// 공휴일명 정제 — 고정 양력은 우리 표기, 그 외에는 한글이 포함된 값만 사용.
  /// name(고유 명칭)을 descriptionKo 보다 우선한다: descriptionKo 는 "2026 지방선거"처럼
  /// 연도가 붙어 있어 좁은 캘린더 칸에서 "2026"만 잘려 보였다. 또 앞쪽 연도/숫자/공백 등
  /// 비한글 접두어를 떼어내 "2026 지방선거" → "지방선거" 로 정리하고, 한글이 전혀 없으면
  /// '공휴일' 로 폴백해 날짜/영문/숫자 같은 이상 텍스트를 차단한다.
  String _resolveHolidayName(int month, int day, String? ko, String fallback) {
    final fixed = _solarHolidayNames['$month-$day'];
    if (fixed != null) return fixed;
    for (final cand in [fallback, ko]) {
      if (cand != null && _hangul.hasMatch(cand)) {
        final cleaned = cand.replaceFirst(RegExp(r'^[^가-힣]+'), '').trim();
        if (cleaned.isNotEmpty) return cleaned;
      }
    }
    return '공휴일';
  }

  /// 공휴일 이름
  String? _getHolidayName(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return _holidays[key];
  }

  // 일정 데이터 — API 로드 결과로 채워짐
  List<_Schedule> _schedules = [];

  /// 공휴일을 일반 일정과 동일하게 레인 배치하기 위한 의사(pseudo) 일정 목록.
  List<_Schedule> _holidaySchedules = [];

  /// 레인/날짜 렌더에 사용하는 전체 목록 — 사용자 일정 + 공휴일.
  List<_Schedule> get _displaySchedules => [..._schedules, ..._holidaySchedules];

  /// 현재 보이는 월 그리드(6주) 범위의 공휴일을 의사 일정으로 변환.
  void _rebuildHolidaySchedules() {
    final first = DateTime.utc(_focusedDay.year, _focusedDay.month, 1);
    final gridStart = _weekSunday(first);
    final gridEnd = gridStart.add(const Duration(days: 41));
    final list = <_Schedule>[];
    _holidays.forEach((date, name) {
      if (!date.isBefore(gridStart) && !date.isAfter(gridEnd)) {
        list.add(_Schedule(
          title: name,
          color: AppColors.eventHoliday,
          start: date,
          createdAt: DateTime.utc(2000), // 정렬 안정용 고정값
          allDay: true,
          isHoliday: true,
        ));
      }
    });
    _holidaySchedules = list;
  }

  // 주(row)별 레인 배정: 주 일요일 → (일정 객체 → 레인 인덱스)
  final Map<DateTime, Map<_Schedule, int>> _weekLaneMap = {};
  final Map<DateTime, int> _weekMaxLane = {};

  /// 단일 일정 컴팩션 배치 시 행 정렬 기준(공휴일 위 → 긴 일정 → 시작 빠른 순 → 생성 순).
  int _rowCompare(_Schedule a, _Schedule b) {
    if (a.isHoliday != b.isHoliday) return a.isHoliday ? -1 : 1;
    final ad = a.end.difference(a.start).inDays;
    final bd = b.end.difference(b.start).inDays;
    if (ad != bd) return bd.compareTo(ad);
    final sc = a.start.compareTo(b.start);
    if (sc != 0) return sc;
    return a.createdAt.compareTo(b.createdAt);
  }

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

    // 공휴일도 일반 일정과 같은 레인 시스템에 포함시켜, 멀티데이 일정이 공휴일과
    // 겹쳐도 한 줄로 쭉 이어지고(테트리스), 한 일정은 한 주 내내 같은 레인을 유지한다.
    final all = _displaySchedules;
    // 모든 일정이 걸치는 주 일요일 수집
    final Set<DateTime> weekSundays = {};
    for (final s in all) {
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
      final weekSchedules = all.where((s) {
        final sd = DateTime.utc(s.start.year, s.start.month, s.start.day);
        final ed = DateTime.utc(s.end.year, s.end.month, s.end.day);
        return !ed.isBefore(weekSun) && !sd.isAfter(weekSat);
      }).toList()
        ..sort((a, b) {
          // 긴(멀티데이) 일정이 가장 낮은 레인을 우선 차지하도록 기간 내림차순 우선.
          // 이렇게 해야 공휴일·단일 일정이 낀 날에도 멀티데이 바가 한 주 내내 같은
          // 레인을 유지해 한 줄로 쭉 이어진다(테트리스). 같은 길이일 때만 공휴일을 위로.
          final aDays = a.end.difference(a.start).inDays;
          final bDays = b.end.difference(b.start).inDays;
          if (aDays != bDays) return bDays.compareTo(aDays);
          if (a.isHoliday != b.isHoliday) return a.isHoliday ? -1 : 1;
          final sc = a.start.compareTo(b.start);
          if (sc != 0) return sc;
          return a.createdAt.compareTo(b.createdAt);
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

  /// 해당 날짜에 걸치는 모든 일정 (공휴일 포함)
  List<_Schedule> _getSchedulesForDay(DateTime day) {
    return _displaySchedules.where((s) => s.coversDay(day)).toList();
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
    // 공휴일도 상세 시트에 함께 노출(읽기 전용 — 수정/삭제 불가).
    final userSchedules = _getSchedulesForDay(day);
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

    // 하이브리드 배치(테트리스):
    //  · 멀티데이 일정 = 주(週) 고정 레인(_weekLaneMap) 위치 그대로 → 인접 날과 같은
    //    행을 유지해 한 줄로 쭉 이어지고 제목도 구간당 한 번만 뜬다.
    //  · 단일 일정 = 그 날 비어 있는 가장 낮은 행부터 채워(컴팩션) 한산한 날에
    //    허위 "+N" 이 생기지 않게 한다.
    const int maxEvents = 3;
    final weekSun = _weekSunday(day);
    final weekLane = isOutside
        ? <_Schedule, int>{}
        : (_weekLaneMap[weekSun] ?? <_Schedule, int>{});
    final dayEvents = isOutside ? <_Schedule>[] : _getSchedulesForDay(day);

    final Map<int, _Schedule> rowToSchedule = {};
    int hiddenCount = 0;
    // 1) 멀티데이 — 주 고정 레인에 배치(표시 범위를 벗어난 레인은 숨김).
    for (final s in dayEvents.where((s) => s.isMultiDay)) {
      final lane = weekLane[s];
      if (lane != null && lane < maxEvents && !rowToSchedule.containsKey(lane)) {
        rowToSchedule[lane] = s;
      } else {
        hiddenCount++;
      }
    }
    // 2) 단일 일정 — 비어 있는 가장 낮은 행부터 채움.
    final singles = dayEvents.where((s) => !s.isMultiDay).toList()
      ..sort(_rowCompare);
    for (final s in singles) {
      int placed = -1;
      for (int r = 0; r < maxEvents; r++) {
        if (!rowToSchedule.containsKey(r)) {
          placed = r;
          break;
        }
      }
      if (placed >= 0) {
        rowToSchedule[placed] = s;
      } else {
        hiddenCount++;
      }
    }
    final bool hasOverflow = hiddenCount > 0;

    return SizedBox(
      height: rowHeight,
      child: Column(
        children: [
          const SizedBox(height: 2),
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
          // 행별 이벤트 pill — 모든 셀이 동일한 3행 구조라 같은 레인의 멀티데이
          // 막대가 인접 셀과 정확히 같은 높이에서 맞닿는다. 빈 행은 placeholder.
          for (int row = 0; row < maxEvents; row++)
            rowToSchedule[row] != null
                ? _buildMonthEventPill(day, rowToSchedule[row]!, cellWidth)
                : const SizedBox(height: 18),
          // 오버플로우: 4번째부터 숨기고 "…"로 남은 개수 표시
          if (hasOverflow) _buildMorePill(hiddenCount),
        ],
      ),
    );
  }

  Widget _buildMorePill(int count) {
    return Container(
      height: 17,
      margin: const EdgeInsets.only(top: 1, left: 2, right: 2),
      alignment: Alignment.center,
      child: Text(
        '⋯ +$count',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: AppColors.gray500,
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

  Widget _buildEventPill(
    DateTime day,
    _Schedule schedule,
    double cellWidth, {
    double barHeight = 17,
    double fontSize = 11,
  }) {
    final color = schedule.color;
    final isStart = schedule.isStartDay(day);
    final isEnd = schedule.isEndDay(day);
    final isMulti = schedule.isMultiDay;

    // 가독성: 막대는 일정 색을 '진하게'(solid) 깔고 글자는 흰색 볼드로 통일한다.
    // 공휴일만 예외 — 연한 배경 + 빨간 글자를 유지한다.
    final isHoliday = schedule.isHoliday;
    final bg = isHoliday ? color.withValues(alpha: 0.15) : color;
    final fg = isHoliday ? color : AppColors.white;

    // 단일 일정 — 둥근 pill
    if (!isMulti) {
      return Container(
        height: barHeight,
        margin: const EdgeInsets.only(top: 1, left: 2, right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          schedule.title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            color: fg,
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
      color: bg,
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
        height: barHeight,
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
                  fontWeight: FontWeight.w700,
                  fontSize: fontSize,
                  color: fg,
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
      height: barHeight,
      margin: EdgeInsets.only(
        top: 1,
        left: roundLeft ? 2 : 0,
        right: roundRight ? 2 : 0,
      ),
      decoration: barDecoration,
    );
  }

  /// 월 뷰 전용 pill — 날짜별 컴팩션 행에 맞춰 '셀 단위'로 그린다.
  /// 멀티데이는 셀마다 자기 세그먼트를 그리며, 인접한 날과 같은 행이면 이어진 막대처럼 보인다.
  Widget _buildMonthEventPill(
    DateTime day,
    _Schedule schedule,
    double cellWidth, {
    double barHeight = 17,
    double fontSize = 11,
  }) {
    final color = schedule.color;
    // 막대는 진한 색 배경 + 흰색 볼드 글자로 통일(공휴일만 연한 배경 + 빨간 글자).
    final isHoliday = schedule.isHoliday;
    final bg = isHoliday ? color.withValues(alpha: 0.15) : color;
    final fg = isHoliday ? color : AppColors.white;

    if (!schedule.isMultiDay) {
      return Container(
        height: barHeight,
        margin: const EdgeInsets.only(top: 1, left: 2, right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          schedule.title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            color: fg,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }

    // 멀티데이 — 주 고정 레인이라 같은 주 안 인접 날들은 같은 행 → 막대가 이어진다.
    // 구간(run)은 일정의 시작/끝일 또는 주 경계(일/토)에서만 끊긴다.
    // 따라서 토→일로 넘어가면 토에서 한 번 끊기고 일에서 새 구간이 시작돼 제목이
    // 두 줄(주마다 1번)에 표시된다.
    final bool isSunday = day.weekday == DateTime.sunday;
    final bool isSaturday = day.weekday == DateTime.saturday;
    final bool runStart = schedule.isStartDay(day) || isSunday;
    final bool runEnd = schedule.isEndDay(day) || isSaturday;

    return Container(
      height: barHeight,
      margin: EdgeInsets.only(
        top: 1,
        left: runStart ? 2 : 0,
        right: runEnd ? 2 : 0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.horizontal(
          left: runStart ? const Radius.circular(4) : Radius.zero,
          right: runEnd ? const Radius.circular(4) : Radius.zero,
        ),
      ),
      alignment: Alignment.centerLeft,
      // 제목은 구간 시작 셀에서만 표시(셀 폭에 맞춰 줄임).
      child: runStart
          ? Text(
              schedule.title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: fontSize,
                color: fg,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            )
          : null,
    );
  }

  // ─── 공통 네비게이션 ──────────────────────────────────────────────────────────
  Future<void> _openDetail(String? id) async {
    if (id == null) return;
    await Navigator.of(context).pushNamed('/schedule-detail', arguments: id);
    _loadSchedules();
  }

  // ─── 뷰 토글 (월/주) ─────────────────────────────────────────────────────────
  Widget _buildViewToggle() {
    Widget seg(String label, _CalView v) {
      final active = _view == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _view = v;
            // 월로 돌아올 때 선택 강조(빨간 원)가 남지 않도록 초기화.
            _selectedDay = null;
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
          ],
        ),
      ),
    );
  }

  // ─── 멤버 필터 ────────────────────────────────────────────────────────────────
  Widget _buildMemberFilter() {
    if (_members.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 46,
      padding: const EdgeInsets.only(bottom: 6),
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
    // 월 뷰와 동일한 셀 폭(maxWidth/7)이어야 멀티데이 연결 바의 span 계산이 맞다.
    final cellWidth = constraints.maxWidth / 7;

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
          onTap: () => _showDayDetail(d),
          child: Column(
            children: [
              Text(
                labels[d.weekday % 7],
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
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

    // 이 주의 레인 배정 — 월 뷰와 '같은' 데이터(_weekLaneMap)를 그대로 사용한다.
    // 그래야 26~29처럼 여러 날 걸친 일정이 월 뷰와 동일하게 한 줄로 쭉 이어진다.
    final laneAssignments = _weekLaneMap[weekSun] ?? <_Schedule, int>{};
    final weekMax = _weekMaxLane[weekSun] ?? -1;

    // 날짜별 (레인 → 일정) 매핑. 한 날의 같은 레인에는 하나의 일정만 온다.
    final Map<DateTime, Map<int, _Schedule>> laneToScheduleByDay = {
      for (final d in days)
        d: {
          for (final s in _getSchedulesForDay(d))
            if (laneAssignments[s] != null) laneAssignments[s]!: s,
        },
    };

    const barHeight = 20.0;
    const rowHeight = barHeight + 5; // 바 + 줄 간격

    // 가로 한 줄(레인)을 7개 셀로 그린다. 멀티데이는 시작 셀에서 span 만큼 늘어난
    // 연결 바(_buildEventPill)가 되고, 단일 일정은 그 칸의 pill 이 된다 — 월 뷰와 동일.
    Widget laneRow(int lane) {
      return SizedBox(
        height: rowHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in days)
              SizedBox(
                width: cellWidth,
                child: () {
                  final s = laneToScheduleByDay[d]?[lane];
                  if (s == null) return const SizedBox.shrink();
                  final pill = _buildEventPill(
                    d,
                    s,
                    cellWidth,
                    barHeight: barHeight,
                    fontSize: 11,
                  );
                  // 공휴일은 서버 상세가 없으므로 그 날의 상세 시트(읽기 전용)를 연다.
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        s.isHoliday ? _showDayDetail(d) : _openDetail(s.id),
                    child: pill,
                  );
                }(),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(children: days.map(header).toList()),
        const SizedBox(height: 6),
        const Divider(height: 1, color: AppColors.gray100),
        const SizedBox(height: 4),
        Expanded(
          child: weekMax < 0
              ? const Center(
                  child: Text(
                    '이번 주 일정이 없어요',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: AppColors.gray400,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      for (int lane = 0; lane <= weekMax; lane++) laneRow(lane),
                    ],
                  ),
                ),
        ),
      ],
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
    ).whenComplete(controller.dispose);
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
            // 헤더 - 제목 "우리 약속" + 우측 아이콘
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Text(
                    '우리 약속',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
            // 배너 광고 — 월/주 탭·멤버필터 아래, 달력 본문 위.
            const AdBanner(),
            // 본문 — 월/주/일 뷰 전환
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_view == _CalView.week) {
                    return _buildWeekView(constraints);
                  }
                  // 셀 높이는 일정 3개 + "…" 가 들어가도록 처음부터 충분히(최소 100) 확보.
                  // 화면이 커서 더 여유가 있으면 6주가 화면을 꽉 채우도록 늘린다.
                  final rowHeight =
                      ((constraints.maxHeight - 24) / 6).clamp(100.0, 160.0);
                  final cellWidth = constraints.maxWidth / 7;
                  final monthCalendar = TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    startingDayOfWeek: StartingDayOfWeek.sunday,
                    // 세로 스크롤 래퍼와 충돌하지 않도록 가로 스와이프만 허용.
                    availableGestures: AvailableGestures.horizontalSwipe,
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
                              fontWeight: FontWeight.w700,
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
                      // 가로 스와이프로 달이 바뀌면 해당 월 일정을 다시 불러온다.
                      // (예전엔 _focusedDay 만 갱신하고 재조회를 안 해, 스와이프로 이동한
                      //  달엔 일정이 안 뜨다가 다른 화면을 갔다 와야 보이던 버그가 있었다.)
                      final monthChanged =
                          focusedDay.year != _focusedDay.year ||
                              focusedDay.month != _focusedDay.month;
                      setState(() => _focusedDay = focusedDay);
                      if (monthChanged) _loadSchedules();
                    },
                  );
                  // 셀을 키웠을 때 6주가 화면보다 길어지면 세로 스크롤로 처리.
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: monthCalendar,
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
      // 공휴일은 읽기 전용 — 상세/수정 화면으로 넘어가지 않는다.
      onTap: schedule.isHoliday ? null : () => onScheduleTap(schedule.id),
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
            // 공휴일은 참석자 대신 '공휴일' 배지를 보여준다(수정 불가 표시).
            if (schedule.isHoliday)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '공휴일',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: color,
                  ),
                ),
              )
            else
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
