import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:world_holidays/world_holidays.dart';
import '../../theme/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class _Schedule {
  final String title;
  final Color color;
  final DateTime start;
  final DateTime end;
  final String? time;

  const _Schedule({
    required this.title,
    required this.color,
    required this.start,
    DateTime? end,
    this.time,
  }) : end = end ?? start;

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

  /// 공휴일 맵: 날짜(utc normalized) → 공휴일명
  final Map<DateTime, String> _holidays = {};

  @override
  void initState() {
    super.initState();
    _loadHolidays();
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

  // 일정 데이터 — start/end로 다일 이벤트 지원
  final List<_Schedule> _schedules = [
    _Schedule(
      title: '야근',
      color: AppColors.primary,
      start: DateTime.utc(2026, 2, 1),
    ),
    _Schedule(
      title: '야근',
      color: AppColors.primary,
      start: DateTime.utc(2026, 2, 5),
    ),
    _Schedule(
      title: '출근 일찍',
      color: AppColors.primary,
      start: DateTime.utc(2026, 2, 7),
    ),
    _Schedule(
      title: '카페로 데이트',
      color: AppColors.purple,
      start: DateTime.utc(2026, 2, 7),
    ),
    _Schedule(
      title: '야근',
      color: AppColors.primary,
      start: DateTime.utc(2026, 2, 8),
      time: '종일',
    ),
    _Schedule(
      title: '출근 늦게',
      color: AppColors.purple,
      start: DateTime.utc(2026, 2, 8),
      time: '오후 2:00 - 5:00',
    ),
    _Schedule(
      title: '출근 늦게',
      color: AppColors.purple,
      start: DateTime.utc(2026, 2, 14),
    ),
    // 설날연휴는 world_holidays에서 자동 로드
    _Schedule(
      title: '영화보기',
      color: AppColors.purple,
      start: DateTime.utc(2026, 2, 18),
    ),
    _Schedule(
      title: '야근',
      color: AppColors.primary,
      start: DateTime.utc(2026, 2, 20),
    ),
    // 출장 — 2일
    _Schedule(
      title: '제주 출장',
      color: AppColors.purple,
      start: DateTime.utc(2026, 2, 22),
      end: DateTime.utc(2026, 2, 23),
    ),
    _Schedule(
      title: '야근',
      color: AppColors.primary,
      start: DateTime.utc(2026, 2, 26),
    ),
    _Schedule(
      title: '출근 일찍',
      color: AppColors.primary,
      start: DateTime.utc(2026, 2, 28),
    ),
    _Schedule(
      title: '부랄 저녁',
      color: AppColors.purple,
      start: DateTime.utc(2026, 2, 28),
    ),
    // 삼일절은 world_holidays에서 자동 로드
  ];

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
      setState(() {
        _focusedDay = picked;
        _selectedDay = null;
      });
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
        onAddSchedule: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed('/add-schedule');
        },
        onScheduleTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed('/schedule-detail');
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
  }) {
    final schedules = isOutside ? <_Schedule>[] : _getSchedulesForDay(day);
    final holidayName = isOutside ? null : _getHolidayName(day);

    // 공휴일이면 날짜 텍스트를 공휴일 색으로 (circleBg가 없을 때만)
    final dayTextColor =
        (holidayName != null && circleBg == null) ? AppColors.eventHoliday : textColor;

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
                shape: BoxShape.circle,
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
          // 공휴일 pill (첫 번째 슬롯)
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
          // 일반 일정 pill (공휴일이 있으면 1개만, 없으면 2개)
          ...schedules.take(holidayName != null ? 1 : 2).map((s) => _buildEventPill(day, s, cellWidth)),
        ],
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
                    onTap: () =>
                        Navigator.of(context).pushNamed('/notifications'),
                    child: Stack(
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          size: 22,
                          color: AppColors.gray700,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
            // 날짜 네비게이션 - 가운데 정렬
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      _focusedDay = DateTime(
                        _focusedDay.year,
                        _focusedDay.month - 1,
                      );
                    }),
                    child: const Icon(
                      Icons.chevron_left,
                      size: 20,
                      color: AppColors.gray500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showMonthPicker(),
                    child: Row(
                      children: [
                        Text(
                          '${_focusedDay.year}년 ${_focusedDay.month}월',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: AppColors.gray700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() {
                      _focusedDay = DateTime(
                        _focusedDay.year,
                        _focusedDay.month + 1,
                      );
                    }),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
            // 캘린더 - 하단까지 확장
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
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
                        color: AppColors.primary,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final isWeekend =
                            day.weekday == DateTime.saturday ||
                            day.weekday == DateTime.sunday;
                        return _buildDayCell(
                          day,
                          rowHeight,
                          cellWidth,
                          textColor: isWeekend
                              ? AppColors.primary
                              : AppColors.gray900,
                        );
                      },
                      todayBuilder: (context, day, focusedDay) {
                        return _buildDayCell(
                          day,
                          rowHeight,
                          cellWidth,
                          circleBg: AppColors.black,
                          textColor: AppColors.white,
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
                Navigator.of(context).pushNamed('/add-schedule'),
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
  final VoidCallback onScheduleTap;

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
                          left: 24,
                          right: 24,
                          bottom:
                              MediaQuery.of(context).padding.bottom + 16,
                        ),
                        itemCount: schedules.length,
                        itemBuilder: (context, index) {
                          final schedule = schedules[index];
                          final color = schedule.color;
                          // 다일 일정이면 날짜 범위 표시
                          String timeText = schedule.time ?? '종일';
                          if (schedule.isMultiDay) {
                            timeText =
                                '${schedule.start.month}/${schedule.start.day} - ${schedule.end.month}/${schedule.end.day}';
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: onScheduleTap,
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
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                    _buildAvatarStack(),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildAvatarStack() {
    return SizedBox(
      width: 46,
      height: 28,
      child: Stack(
        children: [
          _buildAvatar(AppColors.primary, 0),
          _buildAvatar(AppColors.blue, 16),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color color, double left) {
    return Positioned(
      left: left,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 1.5),
        ),
        child: Icon(Icons.person, size: 16, color: color),
      ),
    );
  }
}
