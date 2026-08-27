import '../../common/models/common_models.dart';

/// 그룹 가계부(Ledger) DTO — 서버 `digdaserver.domain.ledger` 와 1:1.

/// 지출 분류. 서버 enum 과 이름을 맞추고, 알 수 없는 값이 오면 [etc] 로 떨어진다
/// (서버에 분류가 추가돼도 구버전 앱이 파싱에서 죽지 않게).
enum ExpenseCategory {
  food('FOOD', '식비'),
  transport('TRANSPORT', '교통'),
  lodging('LODGING', '숙박'),
  shopping('SHOPPING', '쇼핑'),
  etc('ETC', '기타');

  const ExpenseCategory(this.wire, this.label);

  /// 서버로 보내는 값.
  final String wire;

  /// 화면 표기. 서버도 categoryLabel 을 내려주지만, 입력 화면처럼 아직 저장 전이라
  /// 서버 응답이 없는 자리에서 쓰기 위해 앱에도 같은 표를 둔다.
  final String label;

  static ExpenseCategory fromWire(String? value) {
    for (final c in ExpenseCategory.values) {
      if (c.wire == value) return c;
    }
    return ExpenseCategory.etc;
  }
}

/// 일정에 달린 지출 한 건.
class ScheduleExpense {
  const ScheduleExpense({
    required this.id,
    required this.amount,
    required this.category,
    required this.categoryLabel,
    this.memo,
    this.payer,
  });

  final String id;

  /// 원(KRW) 단위 정수.
  final int amount;
  final ExpenseCategory category;
  final String categoryLabel;
  final String? memo;

  /// 탈퇴한 멤버가 낸 지출이거나 '누가 냈는지 미지정'이면 null.
  final UserSummary? payer;

  factory ScheduleExpense.fromJson(Map<String, dynamic> json) {
    final category = ExpenseCategory.fromWire(json['category'] as String?);
    return ScheduleExpense(
      id: json['id'].toString(),
      amount: (json['amount'] as num? ?? 0).toInt(),
      category: category,
      categoryLabel: json['categoryLabel'] as String? ?? category.label,
      memo: json['memo'] as String?,
      payer: json['payer'] == null
          ? null
          : UserSummary.fromJson(json['payer'] as Map<String, dynamic>),
    );
  }
}

/// 일정 저장 시 함께 보내는 지출 한 건.
class ExpenseWrite {
  const ExpenseWrite({
    required this.amount,
    required this.category,
    this.payerId,
    this.memo,
  });

  final int amount;
  final ExpenseCategory category;
  final String? payerId;
  final String? memo;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'category': category.wire,
        if (payerId != null) 'payerId': payerId,
        if (memo != null && memo!.isNotEmpty) 'memo': memo,
      };

  /// 서버에서 받은 지출을 다시 편집 폼에 올릴 때.
  factory ExpenseWrite.fromExpense(ScheduleExpense e) => ExpenseWrite(
        amount: e.amount,
        category: e.category,
        payerId: e.payer?.id,
        memo: e.memo,
      );
}

// ─── 전체 가계부 화면용 월 요약 ────────────────────────────────────────────────

class LedgerSummary {
  const LedgerSummary({
    required this.year,
    required this.month,
    required this.totalAmount,
    required this.prevMonthTotal,
    required this.allTimeTotal,
    required this.entryCount,
    required this.categories,
    required this.members,
    required this.schedules,
    required this.daily,
    this.firstEntryMonth,
    this.lastEntryMonth,
  });

  final int year;
  final int month;
  final int totalAmount;

  /// 지난달 총 지출 — 증감 배지에 쓴다.
  final int prevMonthTotal;

  /// 그룹 누적 지출.
  final int allTimeTotal;
  final int entryCount;
  final List<LedgerCategoryStat> categories;
  final List<LedgerMemberStat> members;
  final List<LedgerScheduleStat> schedules;
  final List<LedgerDailyStat> daily;

  /// 가계부에 기록이 남아 있는 첫 달 / 마지막 달 (일(day)은 1 로 고정). 기록이 없으면 null.
  ///
  /// 월 이동 범위를 여기서 잡는다 — "미래 달은 못 본다" 같은 규칙을 앱에 박아두면
  /// 다음 달 여행비를 미리 적어둔 그룹이 정작 자기가 쓴 달을 보지 못한다.
  final DateTime? firstEntryMonth;
  final DateTime? lastEntryMonth;

  bool get isEmpty => entryCount == 0;

  /// 지난달 대비 증감액. 지난달 지출이 없으면 비교 자체를 하지 않는다(null).
  int? get diffFromPrevMonth =>
      prevMonthTotal == 0 ? null : totalAmount - prevMonthTotal;

  static LedgerSummary empty(int year, int month) => LedgerSummary(
        year: year,
        month: month,
        totalAmount: 0,
        prevMonthTotal: 0,
        allTimeTotal: 0,
        entryCount: 0,
        categories: const [],
        members: const [],
        schedules: const [],
        daily: const [],
      );

  factory LedgerSummary.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) f) =>
        (json[key] as List? ?? [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return LedgerSummary(
      year: (json['year'] as num).toInt(),
      month: (json['month'] as num).toInt(),
      totalAmount: (json['totalAmount'] as num? ?? 0).toInt(),
      prevMonthTotal: (json['prevMonthTotal'] as num? ?? 0).toInt(),
      allTimeTotal: (json['allTimeTotal'] as num? ?? 0).toInt(),
      entryCount: (json['entryCount'] as num? ?? 0).toInt(),
      categories: parse('categories', LedgerCategoryStat.fromJson),
      members: parse('members', LedgerMemberStat.fromJson),
      schedules: parse('schedules', LedgerScheduleStat.fromJson),
      daily: parse('daily', LedgerDailyStat.fromJson),
      firstEntryMonth: _parseMonth(json['firstEntryMonth'] as String?),
      lastEntryMonth: _parseMonth(json['lastEntryMonth'] as String?),
    );
  }

  /// `yyyy-MM` → 그 달의 1일. 서버가 못 주거나 형식이 어긋나면 null 로 떨어뜨려
  /// 화면이 이번 달만 보여주는 쪽으로 안전하게 물러난다.
  static DateTime? _parseMonth(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length < 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month);
  }
}

class LedgerCategoryStat {
  const LedgerCategoryStat({
    required this.category,
    required this.label,
    required this.amount,
    required this.ratio,
  });

  final ExpenseCategory category;
  final String label;
  final int amount;

  /// 0.0~1.0. 서버가 0 나눗셈을 막아 계산해 내려준다.
  final double ratio;

  factory LedgerCategoryStat.fromJson(Map<String, dynamic> json) {
    final category = ExpenseCategory.fromWire(json['category'] as String?);
    return LedgerCategoryStat(
      category: category,
      label: json['label'] as String? ?? category.label,
      amount: (json['amount'] as num? ?? 0).toInt(),
      ratio: (json['ratio'] as num? ?? 0).toDouble(),
    );
  }
}

class LedgerMemberStat {
  const LedgerMemberStat({
    required this.payer,
    required this.amount,
    required this.ratio,
  });

  /// null 이면 '탈퇴한 멤버' 또는 낸 사람 미지정.
  final UserSummary? payer;
  final int amount;
  final double ratio;

  factory LedgerMemberStat.fromJson(Map<String, dynamic> json) =>
      LedgerMemberStat(
        payer: json['payer'] == null
            ? null
            : UserSummary.fromJson(json['payer'] as Map<String, dynamic>),
        amount: (json['amount'] as num? ?? 0).toInt(),
        ratio: (json['ratio'] as num? ?? 0).toDouble(),
      );
}

class LedgerScheduleStat {
  const LedgerScheduleStat({
    required this.scheduleId,
    required this.title,
    required this.color,
    required this.startDate,
    required this.amount,
    required this.entryCount,
  });

  final String scheduleId;
  final String title;
  final String color;
  final DateTime startDate;
  final int amount;
  final int entryCount;

  factory LedgerScheduleStat.fromJson(Map<String, dynamic> json) =>
      LedgerScheduleStat(
        scheduleId: json['scheduleId'].toString(),
        title: json['title'] as String? ?? '',
        color: json['color'] as String? ?? '#FF6B6B',
        startDate: DateTime.parse(json['startDate'] as String),
        amount: (json['amount'] as num? ?? 0).toInt(),
        entryCount: (json['entryCount'] as num? ?? 0).toInt(),
      );
}

class LedgerDailyStat {
  const LedgerDailyStat({required this.date, required this.amount});

  final DateTime date;
  final int amount;

  factory LedgerDailyStat.fromJson(Map<String, dynamic> json) => LedgerDailyStat(
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num? ?? 0).toInt(),
      );
}
