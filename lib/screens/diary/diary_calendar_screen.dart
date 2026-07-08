import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import '../../features/diary/models/diary_models.dart';
import '../../theme/colors.dart';
import '../map/korea_map_screen.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/notification_bell_icon.dart';
import '../../widgets/retrying_network_image.dart';

/// 그림일기 캘린더 — 사진 모자이크 달력 + 통계 스트립 + 리스트 토글.
/// 설계: docs/DIARY_CALENDAR.md
class DiaryCalendarScreen extends StatefulWidget {
  const DiaryCalendarScreen({super.key});

  @override
  State<DiaryCalendarScreen> createState() => _DiaryCalendarScreenState();
}

enum _DiaryView { calendar, list }

class _DiaryCalendarScreenState extends State<DiaryCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  _DiaryView _view = _DiaryView.calendar;

  DiaryCalendarResult? _calendar;
  List<DiarySummary> _monthDiaries = const [];
  bool _loading = false;
  /// 썸네일 precache 완료 시 증가. 그리드 썸네일 위젯의 key 에 섞어, 캐시가 데워진
  /// 뒤 위젯을 새로 생성해 첫 진입에도 사진이 바로 뜨게 한다(상세 왕복 없이).
  int _thumbVersion = 0;

  static const _amber = Color(0xFFFBBF24);
  static const _accentPalette = [
    AppColors.primary,
    AppColors.blue,
    AppColors.green,
    AppColors.purple,
  ];

  /// 기분 이모지 — 0 행복 / 1 평온 / 2 슬픔 / 3 화남 / 4 피곤.
  static const _moodEmoji = ['😊', '😌', '😢', '😠', '😴'];
  static const _moodLabel = ['행복', '평온', '슬픔', '화남', '피곤'];

  String _emojiOf(int mood) =>
      (mood >= 0 && mood < _moodEmoji.length) ? _moodEmoji[mood] : '🙂';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMonth());
  }

  Future<void> _loadMonth() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    setState(() => _loading = true);
    try {
      // 그리드·통계는 calendar() 만으로 충분 — 즉시 표시(캐시 우선).
      final calendar = await Di.diaryRepository.calendar(groupId, _focusedDay);
      if (!mounted) return;
      setState(() {
        _calendar = calendar;
        _loading = false;
      });
      _precacheThumbs(calendar);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorDialog(context, errorMessageOf(e));
    }
    // 리스트 뷰일 때만 일기 목록을 추가 로드(지연 로드).
    if (_view == _DiaryView.list) _loadList();
  }

  /// 캘린더 썸네일을 미리 디코드해 이미지 캐시에 적재한다. 콜드스타트 첫 진입에서
  /// 그리드가 사진 여러 장을 한꺼번에 요청하다 일부 첫 로드가 실패로 굳어(Flutter 는
  /// 실패를 캐시하고 재시도하지 않음) 상세를 갔다 와야 보이던 문제를 막는다.
  ///
  /// precache 가 끝나면 [_thumbVersion] 을 올려 그리드 썸네일 위젯을 새로 생성한다.
  /// 그리드가 콜드 첫 빌드에서 실패로 굳었더라도, 캐시가 데워진 뒤 위젯이 재생성되며
  /// 다시 로드해 첫 진입에도 사진이 보이게 된다(예전엔 상세 화면을 왕복해야 떴음).
  Future<void> _precacheThumbs(DiaryCalendarResult cal) async {
    final futures = <Future<void>>[];
    for (final e in cal.byDay.values) {
      final url = e.thumbnailUrl;
      if (url != null && url.isNotEmpty) {
        futures.add(precacheImage(NetworkImage(url), context).catchError((_) {}));
      }
    }
    if (futures.isEmpty) return;
    await Future.wait(futures);
    if (mounted) setState(() => _thumbVersion++);
  }

  /// 리스트 뷰용 일기 목록 — 캘린더 뷰에선 불필요하므로 분리해 지연 로드.
  Future<void> _loadList() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    try {
      final list = await Di.diaryRepository.list(
        groupId,
        month: _focusedDay,
        limit: 31,
      );
      if (!mounted) return;
      setState(() => _monthDiaries = list.diaries);
    } catch (_) {
      // 리스트 로드 실패는 캘린더 표시를 막지 않도록 무시.
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + delta);
      _selectedDay = null;
    });
    _loadMonth();
  }

  DateTime _key(DateTime d) => DateTime(d.year, d.month, d.day);

  DiaryCalendarEntry? _entryFor(DateTime day) => _calendar?.byDay[_key(day)];

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  bool _isFuture(DateTime day) {
    final now = DateTime.now();
    return _key(day).isAfter(_key(now));
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthNav(),
                    // 배너 광고 — 'YYYY년 M월' 월 네비 바로 아래.
                    const AdBanner(),
                    if (_view == _DiaryView.calendar) ...[
                      _buildStatStrip(),
                      _buildPhotoGrid(),
                      _buildTodayPrompt(),
                      _buildMapButton(),
                    ] else
                      _buildListView(),
                    const SizedBox(height: 88),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDatePickerBottomSheet,
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: AppColors.white, size: 28),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }

  /// 헤더 안내(!) — 그림일기는 "인당" 하루 한 편 작성 가능하다는 규칙 안내 (2.0.0).
  void _showDiaryRuleInfo() {
    showInfoDialog(
      context,
      '그림일기 작성 규칙',
      '그림일기는 한 사람당 하루에 한 편씩 쓸 수 있어요.\n그룹원이 10명이면 하루에 최대 10편이 모여요.\n캘린더에는 그날의 대표 썸네일 한 장이 보이고,\n날짜를 누르면 그날의 모든 일기를 볼 수 있어요.',
    );
  }

  // ─── Header + view toggle ──────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const Text(
            '그림일기',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.gray900,
            ),
          ),
          const Spacer(),
          _buildViewToggle(),
          const SizedBox(width: 14),
          // 모찌 시스템과 동일하게 안내(!) 아이콘을 알림 버튼 옆에 배치 — '하루 한 편' 규칙 안내.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showDiaryRuleInfo,
            child: const Icon(Icons.info_outline,
                size: 22, color: AppColors.gray700),
          ),
          const SizedBox(width: 14),
          const NotificationBellIcon(),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/my-page'),
            child: const Icon(
              Icons.settings_outlined,
              size: 22,
              color: AppColors.gray700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    Widget seg(IconData icon, _DiaryView v) {
      final active = _view == v;
      return GestureDetector(
        onTap: () {
          setState(() => _view = v);
          if (v == _DiaryView.list) _loadList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
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
          child: Icon(
            icon,
            size: 16,
            color: active ? AppColors.primary : AppColors.gray400,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          seg(Icons.grid_view_rounded, _DiaryView.calendar),
          seg(Icons.view_agenda_outlined, _DiaryView.list),
        ],
      ),
    );
  }

  // ─── Month nav ─────────────────────────────────────────────────────────────
  Widget _buildMonthNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _changeMonth(-1),
            child: const Icon(Icons.chevron_left,
                size: 22, color: AppColors.gray500),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showMonthPicker,
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
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _changeMonth(1),
            child: const Icon(Icons.chevron_right,
                size: 22, color: AppColors.gray500),
          ),
        ],
      ),
    );
  }

  // ─── Stat strip ────────────────────────────────────────────────────────────
  Widget _buildStatStrip() {
    final stats = _calendar?.stats;
    final count = stats?.count ?? 0;
    final streak = stats?.streak ?? 0;
    final topMood = stats?.topMood;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          _statCard(
            bg: AppColors.primary.withValues(alpha: 0.08),
            value: '$count편',
            label: '이번 달',
            valueColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _statCard(
            bg: _amber.withValues(alpha: 0.12),
            value: '🔥 $streak일',
            label: '연속 기록',
            valueColor: const Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          _statCard(
            bg: AppColors.purple.withValues(alpha: 0.12),
            value: topMood != null ? _emojiOf(topMood) : '—',
            label: topMood != null ? _moodLabel[topMood] : '기분',
            valueColor: AppColors.purple,
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required Color bg,
    required String value,
    required String label,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Photo grid ────────────────────────────────────────────────────────────
  Widget _buildPhotoGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / 7;
          return TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            headerVisible: false,
            daysOfWeekHeight: 28,
            rowHeight: cellWidth + 4,
            availableGestures: AvailableGestures.horizontalSwipe,
            calendarStyle: const CalendarStyle(
              cellMargin: EdgeInsets.all(2),
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
                const labels = ['일', '월', '화', '수', '목', '금', '토'];
                final idx = day.weekday % 7; // Sunday=0
                final color = day.weekday == DateTime.saturday
                    ? AppColors.blue
                    : day.weekday == DateTime.sunday
                        ? AppColors.primary
                        : AppColors.gray500;
                return Center(
                  child: Text(
                    labels[idx],
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: color,
                    ),
                  ),
                );
              },
              defaultBuilder: (c, day, f) => _buildGridTile(day),
              selectedBuilder: (c, day, f) => _buildGridTile(day),
              todayBuilder: (c, day, f) => _buildGridTile(day),
              outsideBuilder: (c, day, f) =>
                  _buildGridTile(day, isOutside: true),
            ),
            onDaySelected: _onDayTap,
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
              _loadMonth();
            },
          );
        },
      ),
    );
  }

  Widget _buildGridTile(DateTime day, {bool isOutside = false}) {
    final entry = isOutside ? null : _entryFor(day);
    final today = !isOutside && _isToday(day);
    final hasDiary = entry != null;

    final dayColor = isOutside
        ? AppColors.gray300
        : day.weekday == DateTime.saturday
            ? AppColors.blue
            : day.weekday == DateTime.sunday
                ? AppColors.primary
                : AppColors.gray800;

    // 오늘(빈 날) — coral 보더 + '+' 작성 유도.
    if (today && !hasDiary) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary, width: 1.5),
          color: AppColors.primary.withValues(alpha: 0.04),
        ),
        child: const Center(
          child: Icon(Icons.add, size: 18, color: AppColors.primary),
        ),
      );
    }

    // 차단/신고로 숨겨진 날 — 슬롯은 채워진 상태로 두되(중복 작성 방지) 내용은 가린다.
    if (hasDiary && entry.hidden) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(10),
            border: today
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 3,
                left: 5,
                child: Text(
                  '${day.day}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.gray500,
                  ),
                ),
              ),
              const Center(
                child: Icon(Icons.visibility_off_outlined,
                    size: 18, color: AppColors.gray400),
              ),
            ],
          ),
        ),
      );
    }

    // 일기 있는 날 — 사진/기분 타일.
    if (hasDiary) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: today
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (entry.thumbnailUrl != null &&
                  entry.thumbnailUrl!.isNotEmpty)
                // 갓 작성한 일기 사진은 서버 썸네일 생성이 잠깐 늦을 수 있어, 첫 실패에
                // 고정되지 않도록 자동 재시도하는 이미지로 그린다. precache 완료 후
                // _thumbVersion 이 바뀌면 위젯이 새로 생성돼 데워진 캐시에서 다시 로드된다.
                RetryingNetworkImage(
                  key: ValueKey(
                      '${entry.thumbnailUrl}#v$_thumbVersion'),
                  url: entry.thumbnailUrl!,
                  fit: BoxFit.cover,
                  fallback: _moodTileBg(entry.mood),
                )
              else
                _moodTileBg(entry.mood),
              // 하단 그라데이션(사진 위 대비 보조)
              if (entry.thumbnailUrl != null &&
                  entry.thumbnailUrl!.isNotEmpty)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                  ),
                ),
              // 날짜 — 사진/모찌 모두 어두운 배경이라 흰색으로 통일.
              Positioned(
                top: 3,
                left: 5,
                child: Text(
                  '${day.day}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.white,
                  ),
                ),
              ),
              // 기분 이모지 — 사진 있을 때만(모찌 타일은 표정으로 기분 표현).
              if (entry.thumbnailUrl != null && entry.thumbnailUrl!.isNotEmpty)
                Positioned(
                  bottom: 2,
                  right: 3,
                  child: Text(_emojiOf(entry.mood),
                      style: const TextStyle(fontSize: 12)),
                ),
              // 여러 편 +N
              if (entry.count > 1)
                Positioned(
                  top: 2,
                  right: 3,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.gray900.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${entry.count - 1}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 8,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // 일기 없는 날 — 옅은 surface 빈 타일.
    return Container(
      decoration: BoxDecoration(
        color: isOutside ? Colors.transparent : AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 13,
          color: dayColor,
        ),
      ),
    );
  }

  /// 기분(0~4) → 모찌 표정 매핑.
  MochiEmotion _moodEmotion(int mood) {
    switch (mood) {
      case 0:
        return MochiEmotion.happy; // 행복
      case 1:
        return MochiEmotion.idle; // 평온
      case 2:
        return MochiEmotion.sleepy; // 슬픔
      case 3:
        return MochiEmotion.proud; // 화남
      case 4:
        return MochiEmotion.sleepy; // 피곤
      default:
        return MochiEmotion.idle;
    }
  }

  /// 사진 없는 일기 타일 — 웃는 이모지 대신 모찌 캐릭터(기분에 맞는 표정).
  Widget _moodTileBg(int mood) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: MochiCharacterView(
          appearance: MochiAppearance.coral,
          stage: CharacterStage.bloom,
          size: 200,
          expression: _moodEmotion(mood),
        ),
      ),
    );
  }

  void _onDayTap(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    final entry = _entryFor(selectedDay);
    if (entry != null) {
      // 2.0.0: 인당 하루 1편 — 하루에 여러 편이 있을 수 있어 상세 대신
      // 그날의 일기 목록 화면으로 진입한다(대표 썸네일 변경도 거기서).
      Navigator.of(context)
          .pushNamed('/diary-day', arguments: _key(selectedDay))
          .then((_) {
        if (mounted) {
          setState(() => _selectedDay = null);
          _loadMonth();
        }
      });
      return;
    }
    if (_isFuture(selectedDay)) {
      setState(() => _selectedDay = null);
      return;
    }
    _confirmWrite(selectedDay);
  }

  void _confirmWrite(DateTime day) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '일기가 없어요',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: Text(
          '${day.month}월 ${day.day}일 일기를 작성할까요?',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
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
              Navigator.of(dialogCtx).pop();
              setState(() => _selectedDay = null);
              Navigator.of(context)
                  .pushNamed('/write-diary', arguments: day)
                  .then((_) {
                if (mounted) _loadMonth();
              });
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

  // ─── Today prompt card ─────────────────────────────────────────────────────
  Widget _buildTodayPrompt() {
    final now = DateTime.now();
    final sameMonth =
        _focusedDay.year == now.year && _focusedDay.month == now.month;
    if (!sameMonth) return const SizedBox.shrink();

    final streak = _calendar?.stats.streak ?? 0;

    // 2.0.0 인당 하루 1편 — '작성 완료'는 그룹 아닌 "내가" 오늘 썼는지로 판정한다.
    final bool done = _calendar?.hasMine(now) ?? false;
    final String title =
        done ? '✅ 오늘 일기를 남겼어요!' : '✏️ 오늘은 어떤 하루였나요?';
    final String subtitle = done
        ? (streak > 0 ? '연속 $streak일째 기록 중이에요 🔥' : '오늘의 추억을 남겼어요 💖')
        : '지금 기록하면 연속 ${streak + 1}일째 🔥';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: GestureDetector(
        onTap: () {
          if (done) {
            // 오늘의 일기 목록으로 — 내 일기 외 그룹원들 일기도 함께 볼 수 있다.
            Navigator.of(context)
                .pushNamed('/diary-day', arguments: _key(now))
                .then((_) {
              if (mounted) _loadMonth();
            });
          } else {
            Navigator.of(context)
                .pushNamed('/write-diary', arguments: now)
                .then((_) {
              if (mounted) _loadMonth();
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: done
                  ? const [Color(0xFFFFB36B), Color(0xFFFF8A8A)]
                  : const [AppColors.primary, Color(0xFFFF9472)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: AppColors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.white),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 시그니처 지도 진입 버튼 ────────────────────────────────────────────────
  Widget _buildMapButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const KoreaMapScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD2C8)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map_outlined,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '대한민국 지도를 채워봐요',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '일기에 다녀온 곳을 남기면 그 지역이 색칠돼요',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: AppColors.gray500.withValues(alpha: 1),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }

  // ─── List view ─────────────────────────────────────────────────────────────
  Widget _buildListView() {
    if (_monthDiaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 48, color: AppColors.gray200),
              const SizedBox(height: 12),
              Text(
                _loading ? '불러오는 중...' : '이번 달 일기가 없어요',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        const SizedBox(height: 4),
        for (var i = 0; i < _monthDiaries.length; i++)
          _buildDiaryItem(_monthDiaries[i], i),
      ],
    );
  }

  Widget _buildDiaryItem(DiarySummary diary, int index) {
    final color = _accentPalette[index % _accentPalette.length];
    final hasImage =
        diary.thumbnailUrl != null && diary.thumbnailUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.of(context)
          .pushNamed('/diary-detail', arguments: diary.id)
          .then((_) => _loadMonth()),
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
            Container(
              width: 3,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_emojiOf(diary.mood),
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          diary.title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.gray900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(diary.date),
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
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: RetryingNetworkImage(
                  url: diary.thumbnailUrl!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  fallback: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image_outlined,
                        size: 24, color: color.withValues(alpha: 0.5)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Month picker (제목 탭) ──────────────────────────────────────────────────
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
      _loadMonth();
    }
  }

  // ─── FAB: 날짜 선택 후 작성 ───────────────────────────────────────────────────
  void _showDatePickerBottomSheet() {
    DateTime pickerFocusedDay = DateTime.now();
    DateTime? pickerSelectedDay = DateTime.now();
    Set<DateTime> pickerDiaryDates = {};
    String pickerLoadedKey = '';

    Future<void> loadPickerDiaries(StateSetter setModalState) async {
      final key = '${pickerFocusedDay.year}-${pickerFocusedDay.month}';
      if (pickerLoadedKey == key) return;
      pickerLoadedKey = key;
      final groupId = Di.activeGroup.groupRoomId;
      if (groupId == null) return;
      try {
        final result =
            await Di.diaryRepository.calendar(groupId, pickerFocusedDay);
        if (mounted) {
          setModalState(() {
            // 인당 하루 1편 — "내가" 이미 쓴 날짜만 막는다(그룹원 일기와 무관).
            pickerDiaryDates = result.myDates
                .map((d) => DateTime.utc(d.year, d.month, d.day))
                .toSet();
          });
        }
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            loadPickerDiaries(setModalState);
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                          child: const Icon(Icons.chevron_left,
                              size: 20, color: AppColors.gray500),
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
                          child: const Icon(Icons.chevron_right,
                              size: 20, color: AppColors.gray500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Builder(builder: (context) {
                      final now = DateTime.now();
                      final today = DateTime.utc(now.year, now.month, now.day);
                      return TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: today,
                        focusedDay: pickerFocusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(pickerSelectedDay, day),
                        enabledDayPredicate: (day) {
                          final d = DateTime.utc(day.year, day.month, day.day);
                          return !d.isAfter(today);
                        },
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
                          markersMaxCount: 1,
                          markerDecoration: BoxDecoration(
                            color: Color(0xFFFBBF24),
                            shape: BoxShape.circle,
                          ),
                          markerSize: 5,
                          markerMargin: EdgeInsets.only(top: 1),
                        ),
                        eventLoader: (day) {
                          final key =
                              DateTime.utc(day.year, day.month, day.day);
                          return pickerDiaryDates.contains(key)
                              ? const [Object()]
                              : const [];
                        },
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
                            const labels = ['일', '월', '화', '수', '목', '금', '토'];
                            final idx = day.weekday % 7;
                            final color = day.weekday == DateTime.saturday
                                ? AppColors.blue
                                : day.weekday == DateTime.sunday
                                    ? AppColors.primary
                                    : AppColors.gray500;
                            return Center(
                              child: Text(
                                labels[idx],
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: color,
                                ),
                              ),
                            );
                          },
                        ),
                        onDaySelected: (selectedDay, focusedDay) {
                          setModalState(() {
                            pickerSelectedDay = selectedDay;
                            pickerFocusedDay = focusedDay;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          setModalState(() => pickerFocusedDay = focusedDay);
                          loadPickerDiaries(setModalState);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
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
                                if (pickerDiaryDates.contains(selectedUtc)) {
                                  Navigator.of(context).pop();
                                  _showDuplicateDiaryDialog();
                                } else {
                                  Navigator.of(context).pop();
                                  Navigator.of(context)
                                      .pushNamed('/write-diary',
                                          arguments: selected)
                                      .then((_) {
                                    if (mounted) _loadMonth();
                                  });
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
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDuplicateDiaryDialog() {
    showLimitDialog(
      context,
      icon: Icons.event_available_rounded,
      title: '이미 일기를 썼어요',
      message: '이 날짜엔 이미 내가 쓴 일기가 있어요.\n한 사람당 하루에 한 편만 쓸 수 있어요.',
    );
  }
}
