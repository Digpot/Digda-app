import 'lunar_calendar.dart';

/// 한국 법정공휴일 — 연도 제한 없이 기기에서 직접 계산한다.
///
/// 예전엔 `world_holidays` 패키지에서 받아 썼는데 그 패키지가 들고 있는 데이터가
/// 2024~2026 뿐이라 2027년부터 달력의 공휴일이 통째로 사라졌다. 공휴일은 규칙으로
/// 정해지는 값이고 규칙은 매년 바뀌지 않으니, 표를 받아오는 대신 계산한다.
/// 덤으로 네트워크·캐시가 사라져 첫 화면에서 공휴일이 늦게 뜨는 일도 없다.
///
/// 다루지 못하는 것: 임시공휴일(예: 2025-01-27)과 선거일. 그때그때 정부가 지정하는
/// 값이라 규칙으로 유도할 수 없다.
class KoreanHolidays {
  KoreanHolidays._();

  /// 연도별 계산 결과 캐시 — 달력은 같은 달을 몇 번이고 다시 그린다.
  static final Map<int, Map<DateTime, String>> _cache = {};

  /// [day] 가 공휴일이면 이름, 아니면 null.
  static String? nameOf(DateTime day) =>
      forYear(day.year)[DateTime.utc(day.year, day.month, day.day)];

  /// [year] 년의 공휴일 — 키는 UTC 로 정규화한 날짜.
  static Map<DateTime, String> forYear(int year) =>
      _cache.putIfAbsent(year, () => _build(year));

  /// [from]~[to] (양끝 포함) 사이의 공휴일. 달력 그리드가 연말·연초에 걸칠 때 쓴다.
  static Map<DateTime, String> inRange(DateTime from, DateTime to) {
    final result = <DateTime, String>{};
    for (var year = from.year; year <= to.year; year++) {
      forYear(year).forEach((date, name) {
        if (!date.isBefore(from) && !date.isAfter(to)) result[date] = name;
      });
    }
    return result;
  }

  static Map<DateTime, String> _build(int year) {
    final bases = _baseHolidays(year);

    // 같은 날에 공휴일이 둘 겹치면(예: 2025-05-05 어린이날 · 부처님오신날) 먼저 넣은
    // 쪽 이름만 남긴다 — 좁은 달력 칸에 두 줄을 넣을 자리가 없다.
    final holidays = <DateTime, String>{};
    for (final base in bases) {
      holidays.putIfAbsent(base.date, () => base.name);
    }

    _applySubstitutes(holidays, bases);
    return holidays;
  }

  /// 대체공휴일을 뺀 '본' 공휴일 목록 — 날짜 오름차순.
  static List<_BaseHoliday> _baseHolidays(int year) {
    final bases = <_BaseHoliday>[];

    void single(int month, int day, String name, _Sub rule) {
      final date = DateTime.utc(year, month, day);
      bases.add(_BaseHoliday(date, date, name, rule));
    }

    /// 설날·추석은 앞뒤 하루씩 붙은 사흘 연휴다. 대체공휴일은 연휴가 끝난 뒤에서
    /// 찾아야 하므로 세 날 모두 같은 [runEnd] 를 들고 다닌다.
    void run(DateTime? center, String name) {
      if (center == null) return;
      final start = center.subtract(const Duration(days: 1));
      final end = center.add(const Duration(days: 1));
      bases.add(_BaseHoliday(start, end, '$name 연휴', _Sub.sundayOrOverlap));
      bases.add(_BaseHoliday(center, end, name, _Sub.sundayOrOverlap));
      bases.add(_BaseHoliday(end, end, '$name 연휴', _Sub.sundayOrOverlap));
    }

    single(1, 1, '신정', _Sub.none);
    run(_lunar(year, 1, 1), '설날');
    single(3, 1, '삼일절', _Sub.weekend);
    // 어린이날을 부처님오신날보다 먼저 넣는다 — 둘이 같은 날일 때(2025-05-05)
    // 달력 칸에 남길 이름은 어린이날 쪽이다.
    single(5, 5, '어린이날', _Sub.weekendOrOverlap);
    _lunarSingle(bases, year, 4, 8, '부처님오신날', _Sub.weekend);
    single(6, 6, '현충일', _Sub.none);
    single(8, 15, '광복절', _Sub.weekend);
    run(_lunar(year, 8, 15), '추석');
    single(10, 3, '개천절', _Sub.weekend);
    single(10, 9, '한글날', _Sub.weekend);
    single(12, 25, '성탄절', _Sub.weekend);

    // 같은 날짜면 넣은 순서를 유지한다(Dart 의 sort 는 안정 정렬이 아니다).
    final order = {for (var i = 0; i < bases.length; i++) bases[i]: i};
    bases.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : order[a]!.compareTo(order[b]!);
    });
    return bases;
  }

  static void _lunarSingle(
    List<_BaseHoliday> bases,
    int year,
    int lunarMonth,
    int lunarDay,
    String name,
    _Sub rule,
  ) {
    final date = _lunar(year, lunarMonth, lunarDay);
    if (date == null) return;
    bases.add(_BaseHoliday(date, date, name, rule));
  }

  static DateTime? _lunar(int year, int month, int day) =>
      LunarCalendar.toSolar(year, month, day);

  /// 대체공휴일 배정.
  ///
  /// 겹침 판정은 **대체공휴일을 넣기 전** 상태로 한다 — 방금 만든 대체공휴일 때문에
  /// 또 다른 대체공휴일이 생기는 연쇄를 막기 위함.
  static void _applySubstitutes(
    Map<DateTime, String> holidays,
    List<_BaseHoliday> bases,
  ) {
    final baseCount = <DateTime, int>{};
    for (final base in bases) {
      baseCount.update(base.date, (v) => v + 1, ifAbsent: () => 1);
    }

    for (final base in bases) {
      if (!base.rule.triggersOn(base.date, (baseCount[base.date] ?? 1) > 1)) {
        continue;
      }
      // 연휴 다음의 첫 번째 '쉬지 않는 평일'. 이미 공휴일인 날과 주말은 건너뛴다.
      var cursor = base.runEnd.add(const Duration(days: 1));
      while (holidays.containsKey(cursor) || _isWeekend(cursor)) {
        cursor = cursor.add(const Duration(days: 1));
      }
      holidays[cursor] = '대체공휴일';
    }
  }

  static bool _isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
}

/// 대체공휴일 규칙. 공휴일마다 다르다 — 신정·현충일은 아예 대상이 아니고,
/// 설날·추석 연휴는 토요일과 겹쳐도 대체가 생기지 않는다.
enum _Sub {
  /// 대체공휴일 없음 — 신정·현충일.
  none,

  /// 토·일과 겹치면 대체 — 삼일절·부처님오신날·광복절·개천절·한글날·성탄절.
  weekend,

  /// 토·일 또는 다른 공휴일과 겹치면 대체 — 어린이날.
  weekendOrOverlap,

  /// 일요일 또는 다른 공휴일과 겹치면 대체 — 설날·추석 연휴.
  sundayOrOverlap;

  bool triggersOn(DateTime date, bool overlapsAnother) {
    switch (this) {
      case _Sub.none:
        return false;
      case _Sub.weekend:
        return KoreanHolidays._isWeekend(date);
      case _Sub.weekendOrOverlap:
        return KoreanHolidays._isWeekend(date) || overlapsAnother;
      case _Sub.sundayOrOverlap:
        return date.weekday == DateTime.sunday || overlapsAnother;
    }
  }
}

class _BaseHoliday {
  const _BaseHoliday(this.date, this.runEnd, this.name, this.rule);

  final DateTime date;

  /// 이 공휴일이 속한 연휴의 마지막 날. 하루짜리면 [date] 와 같다.
  final DateTime runEnd;
  final String name;
  final _Sub rule;
}
