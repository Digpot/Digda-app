/// 음력 → 양력 변환. 설날·추석·부처님오신날처럼 음력으로 정해지는 공휴일을 양력 날짜로
/// 옮기는 데만 쓴다.
///
/// 연도별 한 칸(`_lunarInfo[year - 1900]`)에 그 해의 달 길이와 윤달 정보를 비트로 담는
/// 표준 방식이다. 비트 배치는 이렇다.
///
/// - `0x8000`~`0x0010` (상위 12비트): 1월~12월이 큰달(30일)이면 1, 작은달(29일)이면 0
/// - `0x10000`: 윤달이 큰달이면 1
/// - `0x000f` (하위 4비트): 윤달이 낀 달 번호. 0 이면 그 해엔 윤달이 없다
///
/// 표는 1900~2100 년치(201칸)라 앱이 다룰 만한 미래는 전부 덮는다.
class LunarCalendar {
  LunarCalendar._();

  static const int firstYear = 1900;
  static final int lastYear = firstYear + _lunarInfo.length - 1;

  /// 표의 기준점 — 음력 1900년 1월 1일에 해당하는 양력 날짜.
  static final DateTime _baseDate = DateTime.utc(1900, 1, 31);

  /// 표가 쓰는 옛 윤달 배치가 현행 역법과 어긋나는 해의 보정.
  ///
  /// 이른바 '2033년 문제' — 이 표는 2033년에 윤7월을 두지만 한국천문연구원 역법은
  /// 윤11월을 둔다. 그래서 2033년 8월 이후의 달 번호가 한 달씩 밀린다. 실제로 어긋나는
  /// 공휴일은 추석(음 8/15) 하나뿐이다. 설날·부처님오신날은 윤달 앞이라 영향이 없다.
  static const Map<String, String> _overrides = {
    '2033-8-15': '2033-09-08T00:00:00Z',
  };

  /// 음력 [year]년 [month]월 [day]일(평달)의 양력 날짜. 범위 밖이면 null.
  ///
  /// 윤달은 다루지 않는다 — 공휴일 중 음력으로 정해지는 셋(설날·부처님오신날·추석)은
  /// 모두 평달 기준이라 필요가 없다.
  static DateTime? toSolar(int year, int month, int day) {
    if (year < firstYear || year > lastYear) return null;

    final override = _overrides['$year-$month-$day'];
    if (override != null) return DateTime.parse(override);

    var offset = 0;
    for (var y = firstYear; y < year; y++) {
      offset += _yearDays(y);
    }
    final leap = _leapMonth(year);
    for (var m = 1; m < month; m++) {
      offset += _monthDays(year, m);
      if (leap == m) offset += _leapMonthDays(year);
    }
    offset += day - 1;

    return _baseDate.add(Duration(days: offset));
  }

  /// 음력 [year]년의 총 일수. 평달 12개(348일)에서 큰달마다 하루씩 더하고 윤달을 얹는다.
  static int _yearDays(int year) {
    var days = 348;
    for (var mask = 0x8000; mask > 0x8; mask >>= 1) {
      if ((_info(year) & mask) != 0) days++;
    }
    return days + _leapMonthDays(year);
  }

  static int _monthDays(int year, int month) =>
      (_info(year) & (0x10000 >> month)) == 0 ? 29 : 30;

  static int _leapMonthDays(int year) {
    if (_leapMonth(year) == 0) return 0;
    return (_info(year) & 0x10000) == 0 ? 29 : 30;
  }

  static int _leapMonth(int year) => _info(year) & 0xf;

  static int _info(int year) => _lunarInfo[year - firstYear];

  static const List<int> _lunarInfo = [
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
    0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
    0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
    0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
    0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5d0, 0x14573, 0x052d0, 0x0a9a8, 0x0e950, 0x06aa0,
    0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
    0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b5a0, 0x195a6,
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
    0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x05ac0, 0x0ab60, 0x096d5, 0x092e0,
    0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
    0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
    0x05aa0, 0x076a3, 0x096d0, 0x04bd7, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
    0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
    0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4,
    0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0,
    0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160,
    0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
    0x0d520,  ];
}
