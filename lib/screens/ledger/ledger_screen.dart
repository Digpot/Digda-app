import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/format/money.dart';
import '../../core/network/error_message.dart';
import '../../features/ledger/models/ledger_models.dart';
import '../../theme/colors.dart';
import '../../widgets/ledger_style.dart';
import '../../widgets/month_picker_sheet.dart';
import '../../widgets/notification_bell_icon.dart';

/// 그룹 가계부 전체 화면 — 한 달치 지출을 총액 · 분류 · 사람 · 일정 · 날짜의
/// 다섯 각도로 보여준다.
///
/// 캘린더의 가계부 모드가 "언제 썼나"를 보여준다면 이 화면은 "어디에·누가 썼나"를
/// 본다. 그래서 달력을 다시 그리지 않고 집계만 쌓는다.
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  /// 보고 있는 달. 일(day)은 쓰지 않는다.
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  LedgerSummary? _summary;
  bool _loading = true;
  String? _errorMessage;

  /// 고를 수 있는 달 (각 원소는 그 달 1일). 서버가 내려준 '기록 있는 달' 목록과
  /// 이번 달의 합집합이다. 응답을 받기 전엔 이번 달 하나뿐.
  Set<DateTime> _selectableMonths = {
    DateTime(DateTime.now().year, DateTime.now().month),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) {
      setState(() {
        _loading = false;
        _errorMessage = '그룹방 정보를 불러올 수 없어요';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final summary = await Di.ledgerRepository.monthly(
        groupId,
        year: _month.year,
        month: _month.month,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
        _applyMonthBounds(summary);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = errorMessageOf(e);
      });
    }
  }

  /// [delta] 방향으로 **고를 수 있는** 다음 달. 없으면 null(화살표가 죽는다).
  ///
  /// 한 달씩 세지 않고 기록이 있는 달로 건너뛴다. 3월과 11월에만 썼다면 3월에서 오른쪽
  /// 화살표 한 번에 11월로 간다 — 그 사이 여덟 번은 눌러 봐야 전부 빈 화면이다.
  DateTime? _adjacentSelectableMonth(int delta) {
    final sorted = _selectableMonths.toList()..sort();
    final index = sorted.indexWhere(
      (m) => m.year == _month.year && m.month == _month.month,
    );
    if (index < 0) return null;
    final target = index + delta;
    if (target < 0 || target >= sorted.length) return null;
    return sorted[target];
  }

  void _goToMonth(DateTime month) {
    if (month.year == _month.year && month.month == _month.month) return;
    setState(() {
      _month = DateTime(month.year, month.month);
      // 달을 넘기는 동안 이전 달 숫자가 남아 있으면 잘못된 값을 읽게 되므로 비운다.
      _summary = null;
    });
    _load();
  }

  /// 고를 수 있는 달 = 서버가 알려준 기록 있는 달 ∪ 이번 달 ∪ 지금 보고 있는 달.
  ///
  /// 이번 달을 넣는 이유: 기록이 하나도 없는 새 그룹도 자기 화면은 열어볼 수 있어야 한다.
  /// 보고 있는 달을 넣는 이유: 마지막 지출을 지워 목록이 줄어들어도 지금 화면이 목록
  /// 밖으로 밀려나 양쪽 화살표가 다 죽는 상태가 되지 않게.
  void _applyMonthBounds(LedgerSummary summary) {
    final now = DateTime.now();
    _selectableMonths = {
      ...summary.entryMonths,
      DateTime(now.year, now.month),
      DateTime(_month.year, _month.month),
    };
  }

  /// 달 선택 시트 — 기록이 없는 달은 흐리게 두고 눌러도 넘어가지 않는다.
  Future<void> _showMonthPicker() async {
    final picked = await showMonthPickerSheet(
      context,
      selected: _month,
      selectableMonths: _selectableMonths,
    );
    if (picked == null) return;
    _goToMonth(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildMonthNav(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  /// 일정 화면과 같은 자리·같은 크기의 헤더.
  /// (padding 20/16, 제목 20px w700, 우측 아이콘 22px · 간격 16)
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.arrow_back_ios,
                  size: 16, color: AppColors.gray900),
            ),
          ),
          const Text(
            '우리 가계부',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.gray900,
            ),
          ),
          const Spacer(),
          const NotificationBellIcon(),
          const SizedBox(width: 16),
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

  /// 달 이동 줄. 화살표는 44×44 원형 버튼이고, 가운데 달 이름은 눌러서 여는 알약이다.
  ///
  /// 예전엔 22px 아이콘 하나가 곧 탭 영역이라 손가락으로 맞히기 어려웠다.
  /// 44 는 눌러야 할 것을 눌리게 하는 최소치다.
  Widget _buildMonthNav() {
    final prev = _adjacentSelectableMonth(-1);
    final next = _adjacentSelectableMonth(1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 범위 끝에서도 화살표 자리는 비워두지 않는다 — 자리가 사라지면 라벨이
          // 좌우로 움직여 달을 넘길 때마다 글자가 흔들린다.
          _NavArrow(
            icon: Icons.chevron_left_rounded,
            onTap: prev == null ? null : () => _goToMonth(prev),
          ),
          Expanded(child: _buildMonthLabel()),
          _NavArrow(
            icon: Icons.chevron_right_rounded,
            onTap: next == null ? null : () => _goToMonth(next),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthLabel() {
    final now = DateTime.now();
    final isThisMonth = _month.year == now.year && _month.month == now.month;
    return Center(
      child: Material(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _showMonthPicker,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_month.year}년 ${_month.month}월',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: AppColors.gray900,
                  ),
                ),
                // 화살표로 몇 달을 건너뛰다 보면 지금 보는 게 이번 달인지 헷갈린다.
                // 이번 달일 때만 작은 배지로 짚어준다.
                if (isThisMonth) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '이번 달',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded,
                    size: 20, color: AppColors.gray600),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.gray400),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.gray700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _load(forceRefresh: true),
              child: const Text(
                '다시 시도',
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

    final summary = _summary ?? LedgerSummary.empty(_month.year, _month.month);

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          _TotalHeroCard(summary: summary),
          if (summary.isEmpty) ...[
            const SizedBox(height: 20),
            const _EmptyLedger(),
          ] else ...[
            const SizedBox(height: 24),
            const _SectionTitle('어디에 썼나요'),
            const SizedBox(height: 14),
            _CategoryBreakdown(stats: summary.categories),
            const SizedBox(height: 28),
            const _SectionTitle('누가 냈나요'),
            const SizedBox(height: 14),
            _MemberBreakdown(stats: summary.members, total: summary.totalAmount),
            const SizedBox(height: 28),
            const _SectionTitle('날짜별 지출'),
            const SizedBox(height: 14),
            _DailyChart(month: _month, stats: summary.daily),
            const SizedBox(height: 28),
            const _SectionTitle('일정별 지출'),
            const SizedBox(height: 14),
            _ScheduleBreakdown(
              stats: summary.schedules,
              onTap: (id) async {
                await Navigator.of(context)
                    .pushNamed('/schedule-detail', arguments: id);
                if (!mounted) return;
                // 상세에서 금액을 고쳤을 수 있으니 돌아오면 다시 집계한다.
                _load(forceRefresh: true);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ① 총액 히어로 카드
// ────────────────────────────────────────────────────────────

class _TotalHeroCard extends StatelessWidget {
  const _TotalHeroCard({required this.summary});

  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    final diff = summary.diffFromPrevMonth;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B3242), AppColors.ledgerInk],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${summary.month}월에 쓴 돈',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatWon(summary.totalAmount),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 34,
                height: 1.1,
                color: AppColors.white,
              ),
            ),
          ),
          if (diff != null) ...[
            const SizedBox(height: 10),
            _DiffBadge(diff: diff),
          ],
          const SizedBox(height: 18),
          Divider(height: 1, color: AppColors.white.withValues(alpha: 0.14)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: '이 달 건수',
                  value: '${summary.entryCount}건',
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: AppColors.white.withValues(alpha: 0.14),
              ),
              Expanded(
                child: _HeroStat(
                  label: '우리가 쓴 전체',
                  value: '${formatAmountCompact(summary.allTimeTotal)}원',
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiffBadge extends StatelessWidget {
  const _DiffBadge({required this.diff});

  /// 지난달 대비 증감액. 양수면 더 썼다는 뜻.
  final int diff;

  @override
  Widget build(BuildContext context) {
    final spentMore = diff > 0;
    // 색은 '많이 썼다=경고' 가 아니라 방향 표시로만 쓴다. 그룹 여행비를 두고
    // 빨간불을 켜면 기록하기 싫어진다.
    final color = spentMore ? const Color(0xFFFFB4A2) : const Color(0xFF9BE7C4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            spentMore ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '지난달보다 ${formatWon(diff.abs())} ${spentMore ? '더' : '덜'} 썼어요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 11,
            color: AppColors.white.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppColors.white,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ② 분류별 — 도넛 + 범례
// ────────────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.stats});

  final List<LedgerCategoryStat> stats;

  @override
  Widget build(BuildContext context) {
    final top = stats.isEmpty ? null : stats.first;
    return _Card(
      child: Column(
        children: [
          SizedBox(
            height: 156,
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(140, 140),
                        painter: _DonutPainter(
                          slices: [
                            for (final s in stats)
                              (
                                ratio: s.ratio,
                                color: categoryColor(s.category),
                              ),
                          ],
                        ),
                      ),
                      if (top != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              top.label,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: AppColors.gray500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(top.ratio * 100).round()}%',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                color: AppColors.ledgerInk,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in stats.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _LegendRow(stat: s),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.stat});

  final LedgerCategoryStat stat;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(stat.category);
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.gray700,
            ),
          ),
        ),
        Text(
          '${formatAmountCompact(stat.amount)}원',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.ledgerInk,
          ),
        ),
      ],
    );
  }
}

/// 분류 비율 도넛.
///
/// 조각 사이를 살짝 벌려(=_gapRadians) 색이 붙어 한 덩어리로 보이지 않게 한다.
/// 조각이 하나뿐이면 벌릴 데가 없으므로 통짜 원으로 그린다.
class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices});

  final List<({double ratio, Color color})> slices;

  static const double _stroke = 20;
  static const double _gapRadians = 0.045;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _stroke / 2,
      _stroke / 2,
      size.width - _stroke,
      size.height - _stroke,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = AppColors.gray100;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (slices.isEmpty) return;

    final single = slices.length == 1;
    final gap = single ? 0.0 : _gapRadians;
    // 12시 방향에서 시작.
    double start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = math.pi * 2 * slice.ratio - gap;
      if (sweep <= 0) {
        start += math.pi * 2 * slice.ratio;
        continue;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = single ? StrokeCap.butt : StrokeCap.round
        ..color = slice.color;
      canvas.drawArc(rect, start + gap / 2, sweep, false, paint);
      start += math.pi * 2 * slice.ratio;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}

// ────────────────────────────────────────────────────────────
//  ③ 사람별 — 가로 막대
// ────────────────────────────────────────────────────────────

class _MemberBreakdown extends StatelessWidget {
  const _MemberBreakdown({required this.stats, required this.total});

  final List<LedgerMemberStat> stats;
  final int total;

  @override
  Widget build(BuildContext context) {
    // 막대 길이는 총액이 아니라 1등 대비 비율로 잡는다. 총액 기준이면 인원이
    // 늘수록 모든 막대가 짧아져 누가 많이 냈는지 비교가 안 된다.
    final maxAmount = stats.isEmpty
        ? 0
        : stats.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    return _Card(
      child: Column(
        children: [
          for (int i = 0; i < stats.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == stats.length - 1 ? 0 : 16),
              child: _MemberBar(
                stat: stats[i],
                maxAmount: maxAmount,
                rank: i,
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberBar extends StatelessWidget {
  const _MemberBar({
    required this.stat,
    required this.maxAmount,
    required this.rank,
  });

  final LedgerMemberStat stat;
  final int maxAmount;
  final int rank;

  /// 순위별 색 — 1등이 가장 진하다. 멤버 색(그룹 설정)을 쓰면 탈퇴자 행에 쓸 색이
  /// 없어 회색만 남으므로, 여기서는 순위 팔레트로 통일한다.
  static const List<Color> _palette = [
    AppColors.primary,
    AppColors.ledgerTransport,
    AppColors.ledgerLodging,
    AppColors.ledgerEtc,
    AppColors.ledgerShopping,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[rank % _palette.length];
    final name = stat.payer?.name ?? '누가 냈는지 미정';
    final fraction = maxAmount <= 0 ? 0.0 : stat.amount / maxAmount;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.gray800,
                ),
              ),
            ),
            Text(
              formatWon(stat.amount),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.ledgerInk,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text(
                '${(stat.ratio * 100).round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.gray500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.gray100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ④ 날짜별 — 막대 그래프
// ────────────────────────────────────────────────────────────

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.month, required this.stats});

  final DateTime month;
  final List<LedgerDailyStat> stats;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final byDay = <int, int>{for (final s in stats) s.date.day: s.amount};
    final maxAmount =
        byDay.values.isEmpty ? 0 : byDay.values.reduce((a, b) => a > b ? a : b);
    final peakDay = byDay.entries.isEmpty
        ? null
        : byDay.entries.reduce((a, b) => a.value >= b.value ? a : b);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (peakDay != null) ...[
            Text(
              '${peakDay.key}일에 제일 많이 썼어요 · ${formatWon(peakDay.value)}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: 92,
            // 달의 날 수만큼 막대가 서므로 한 칸이 아주 좁다. 가로 스크롤 없이
            // 전부 보이도록 Expanded 로 균등 분배하고, 값이 있는 날만 색을 채운다.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int day = 1; day <= daysInMonth; day++)
                  Expanded(
                    child: _DailyBar(
                      amount: byDay[day] ?? 0,
                      maxAmount: maxAmount,
                      isPeak: peakDay != null && peakDay.key == day,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _axisLabel('1일'),
              _axisLabel('${(daysInMonth / 2).round()}일'),
              _axisLabel('$daysInMonth일'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _axisLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 11,
          color: AppColors.gray400,
        ),
      );
}

class _DailyBar extends StatelessWidget {
  const _DailyBar({
    required this.amount,
    required this.maxAmount,
    required this.isPeak,
  });

  final int amount;
  final int maxAmount;
  final bool isPeak;

  @override
  Widget build(BuildContext context) {
    // 금액이 있는 날은 아무리 작아도 눈에 보이도록 최소 높이를 준다.
    final ratio = maxAmount <= 0 ? 0.0 : amount / maxAmount;
    final height = amount == 0 ? 3.0 : (6 + ratio * 78);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: amount == 0
              ? AppColors.gray100
              : (isPeak
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ⑤ 일정별
// ────────────────────────────────────────────────────────────

class _ScheduleBreakdown extends StatelessWidget {
  const _ScheduleBreakdown({required this.stats, required this.onTap});

  final List<LedgerScheduleStat> stats;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final s in stats)
            _ScheduleRow(stat: s, onTap: () => onTap(s.scheduleId)),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.stat, required this.onTap});

  final LedgerScheduleStat stat;
  final VoidCallback onTap;

  Color get _color {
    final cleaned = stat.color.replaceAll('#', '');
    final argb = int.tryParse('FF$cleaned', radix: 16);
    return argb != null ? Color(argb) : AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 34,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${stat.startDate.month}월 ${stat.startDate.day}일 · ${stat.entryCount}건',
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
              const SizedBox(width: 8),
              Text(
                formatWon(stat.amount),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.ledgerInk,
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  공통
// ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: AppColors.gray900,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ledgerSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gray100),
      ),
      child: child,
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            '이 달엔 기록된 지출이 없어요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.gray800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '일정을 만들 때 금액을 함께 적으면\n여기에 우리가 쓴 돈이 모여요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 13,
              height: 1.5,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 달 이동 화살표 — 44×44 원형 버튼.
///
/// 예전엔 아이콘 하나(22px)가 그대로 탭 영역이라 손가락으로 맞히기 어려웠다.
/// 끝에 닿아 눌리지 않을 때도 자리는 그대로 지킨다 — 자리가 사라지면 가운데 달 이름이
/// 좌우로 움직여 달을 넘길 때마다 글자가 흔들린다.
class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.gray50 : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 26,
            color: enabled ? AppColors.gray800 : AppColors.gray200,
          ),
        ),
      ),
    );
  }
}
