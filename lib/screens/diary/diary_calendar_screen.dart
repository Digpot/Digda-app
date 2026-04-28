import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../theme/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class DiaryCalendarScreen extends StatefulWidget {
  const DiaryCalendarScreen({super.key});

  @override
  State<DiaryCalendarScreen> createState() => _DiaryCalendarScreenState();
}

class _DiaryCalendarScreenState extends State<DiaryCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Mock diary data with colors for left border
  final List<Map<String, dynamic>> _recentDiaries = [
    {
      'title': '설날 데이트',
      'preview': '오늘 떡국 먹고 영화 봤다. 너무 행복했다...',
      'date': '2026.02.08',
      'color': AppColors.primary,
      'hasImage': true,
    },
    {
      'title': '제물포 바닷가 산책',
      'preview': '바다 보면서 산책하고 커피 마셨다...',
      'date': '2026.02.07',
      'color': AppColors.blue,
      'hasImage': true,
    },
    {
      'title': '카페에서 브런치',
      'preview': '새로 생긴 카페 가봤는데 분위기 좋았다...',
      'date': '2026.02.05',
      'color': AppColors.green,
      'hasImage': true,
    },
  ];

  final Map<DateTime, List<Map<String, dynamic>>> _diaries = {
    DateTime.utc(2026, 2, 5): [
      {'title': '카페에서 브런치'},
    ],
    DateTime.utc(2026, 2, 7): [
      {'title': '제물포 바닷가 산책'},
    ],
    DateTime.utc(2026, 2, 8): [
      {'title': '설날 데이트'},
    ],
    DateTime.utc(2026, 2, 14): [
      {'title': '발렌타인 데이'},
    ],
    DateTime.utc(2026, 2, 21): [
      {'title': '주말'},
    ],
    DateTime.utc(2026, 2, 22): [
      {'title': '산책'},
    ],
  };

  List<Map<String, dynamic>> _getDiariesForDay(DateTime day) {
    return _diaries[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header - 제목 + 우측 아이콘
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        const Text(
                          '그림일기',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.gray900,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context)
                              .pushNamed('/notifications'),
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
                          onTap: () => Navigator.of(context)
                              .pushNamed('/my-page'),
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
                  // Calendar
                  TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: _getDiariesForDay,
                    calendarFormat: CalendarFormat.month,
                    headerVisible: false,
                    calendarStyle: const CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: AppColors.gray900,
                        shape: BoxShape.circle,
                      ),
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
                      markersMaxCount: 1,
                      markerDecoration: BoxDecoration(
                        color: Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                      ),
                      markerSize: 5,
                      markerMargin: EdgeInsets.only(top: 1),
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
                    enabledDayPredicate: (day) {
                      final now = DateTime.now();
                      final today = DateTime.utc(now.year, now.month, now.day);
                      final d = DateTime.utc(day.year, day.month, day.day);
                      return !d.isAfter(today);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      final hasDiary = _getDiariesForDay(selectedDay).isNotEmpty;
                      if (hasDiary) {
                        Navigator.of(context).pushNamed('/diary-detail').then((_) {
                          setState(() => _selectedDay = null);
                        });
                      } else {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text(
                              '일기가 없어요',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: AppColors.gray900,
                              ),
                            ),
                            content: const Text(
                              '이 날의 일기를 작성할까요?',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color: AppColors.gray700,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  setState(() => _selectedDay = null);
                                },
                                child: const Text(
                                  '취소',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: AppColors.gray500,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  setState(() => _selectedDay = null);
                                  Navigator.of(context).pushNamed('/write-diary');
                                },
                                child: const Text(
                                  '작성하기',
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
                    },
                    onPageChanged: (focusedDay) {
                      setState(() => _focusedDay = focusedDay);
                    },
                  ),
                  // Legend
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: Color(0xFFFBBF24),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '일기가 있는 날',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Recent diary section header
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '최근 일기',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppColors.gray900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            // Diary list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final diary = _recentDiaries[index];
                  return _buildDiaryItem(diary);
                },
                childCount: _recentDiaries.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDatePickerBottomSheet(),
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: AppColors.white, size: 28),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
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

  void _showDatePickerBottomSheet() {
    DateTime pickerFocusedDay = DateTime.now();
    DateTime? pickerSelectedDay = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Drag handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.gray200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  const Text(
                    '날짜 선택',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '일기를 작성할 날짜를 선택해주세요',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: AppColors.gray500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Month navigation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => setModalState(() {
                            pickerFocusedDay = DateTime(
                              pickerFocusedDay.year,
                              pickerFocusedDay.month - 1,
                            );
                          }),
                          child: const Icon(
                            Icons.chevron_left,
                            size: 20,
                            color: AppColors.gray500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${pickerFocusedDay.year}년 ${pickerFocusedDay.month}월',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: AppColors.gray700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setModalState(() {
                            pickerFocusedDay = DateTime(
                              pickerFocusedDay.year,
                              pickerFocusedDay.month + 1,
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
                  const SizedBox(height: 8),
                  // Calendar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.now(),
                      focusedDay: pickerFocusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(pickerSelectedDay, day),
                      enabledDayPredicate: (day) =>
                          !day.isAfter(DateTime.now()),
                      calendarFormat: CalendarFormat.month,
                      headerVisible: false,
                      calendarStyle: const CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: AppColors.gray900,
                          shape: BoxShape.circle,
                        ),
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
                        disabledTextStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                          color: AppColors.gray200,
                        ),
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
                      onDaySelected: (selectedDay, focusedDay) {
                        setModalState(() {
                          pickerSelectedDay = selectedDay;
                          pickerFocusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        setModalState(() => pickerFocusedDay = focusedDay);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Confirm button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: pickerSelectedDay != null
                            ? () {
                                final selected = pickerSelectedDay!;
                                final selectedUtc = DateTime.utc(
                                  selected.year,
                                  selected.month,
                                  selected.day,
                                );
                                if (_getDiariesForDay(selectedUtc).isNotEmpty) {
                                  Navigator.of(context).pop();
                                  _showDuplicateDiaryDialog();
                                } else {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pushNamed(
                                    '/write-diary',
                                    arguments: selected,
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.gray200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          pickerSelectedDay != null
                              ? '${pickerSelectedDay!.month}월 ${pickerSelectedDay!.day}일에 일기 쓰기'
                              : '날짜를 선택해주세요',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: pickerSelectedDay != null
                                ? AppColors.white
                                : AppColors.gray400,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            );
          },
        );
      },
    );
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

  Widget _buildDiaryItem(Map<String, dynamic> diary) {
    final color = diary['color'] as Color;
    final hasImage = diary['hasImage'] as bool;

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/diary-detail'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray100),
        ),
        child: Row(
          children: [
            // Left color border
            Container(
              width: 3,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diary['title'] as String,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    diary['preview'] as String,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: AppColors.gray500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    diary['date'] as String,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
            ),
            // Image placeholder
            if (hasImage)
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.image_outlined,
                  size: 24,
                  color: color.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
