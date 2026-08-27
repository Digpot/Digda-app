import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../widgets/month_picker_sheet.dart';

/// 가계부 달 이동 UI 확인용 dev 엔트리포인트 — 로그인/서버 없이 달 이동 줄과
/// 달 선택 시트를 실제 위젯 그대로 띄운다.
///
/// 가정한 데이터: 2025.03 ~ 2027.12 사이에 **드문드문** 기록이 있는 그룹.
/// (기록 없는 달이 어떻게 보이는지가 이 화면의 핵심이라 일부러 구멍을 냈다)
///
///   flutter run -d <device> -t lib/dev/ledger_month_preview_main.dart
void main() {
  runApp(const _LedgerMonthPreviewApp());
}

/// 기록이 있는 달 — 서버 `entryMonths` 가 내려줬다고 치는 값.
final Set<DateTime> _entryMonths = {
  DateTime(2025, 3),
  DateTime(2025, 4),
  DateTime(2025, 7),
  DateTime(2025, 10),
  DateTime(2025, 12),
  DateTime(2026, 2),
  DateTime(2026, 5),
  DateTime(2026, 8),
  DateTime(2026, 11),
  DateTime(2027, 1),
  DateTime(2027, 6),
  DateTime(2027, 12),
};

class _LedgerMonthPreviewApp extends StatelessWidget {
  const _LedgerMonthPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Inter', useMaterial3: true),
      home: const _PreviewScreen(),
    );
  }
}

class _PreviewScreen extends StatefulWidget {
  const _PreviewScreen();

  @override
  State<_PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<_PreviewScreen> {
  DateTime _month = DateTime(2026, 8);

  Set<DateTime> get _selectable {
    final now = DateTime.now();
    return {
      ..._entryMonths,
      DateTime(now.year, now.month),
      DateTime(_month.year, _month.month),
    };
  }

  DateTime? _adjacent(int delta) {
    final sorted = _selectable.toList()..sort();
    final index = sorted.indexWhere(
      (m) => m.year == _month.year && m.month == _month.month,
    );
    if (index < 0) return null;
    final target = index + delta;
    if (target < 0 || target >= sorted.length) return null;
    return sorted[target];
  }

  Future<void> _openPicker() async {
    final picked = await showMonthPickerSheet(
      context,
      selected: _month,
      selectableMonths: _selectable,
    );
    if (picked == null) return;
    setState(() => _month = picked);
  }

  @override
  Widget build(BuildContext context) {
    final prev = _adjacent(-1);
    final next = _adjacent(1);
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            _monthNav(prev, next),
            const Divider(height: 1, color: AppColors.gray100),
            Expanded(child: _placeholderBody()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child:
                Icon(Icons.arrow_back_ios, size: 16, color: AppColors.gray900),
          ),
          Text(
            '우리 가계부',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.gray900,
            ),
          ),
          Spacer(),
          Icon(Icons.notifications_none_rounded,
              size: 22, color: AppColors.gray700),
          SizedBox(width: 16),
          Icon(Icons.settings_outlined, size: 22, color: AppColors.gray700),
        ],
      ),
    );
  }

  Widget _monthNav(DateTime? prev, DateTime? next) {
    final now = DateTime.now();
    final isThisMonth = _month.year == now.year && _month.month == now.month;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _arrow(
            Icons.chevron_left_rounded,
            prev == null ? null : () => setState(() => _month = prev),
          ),
          Expanded(
            child: Center(
              child: Material(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _openPicker,
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
                        if (isThisMonth) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
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
            ),
          ),
          _arrow(
            Icons.chevron_right_rounded,
            next == null ? null : () => setState(() => _month = next),
          ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback? onTap) {
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

  /// 본문은 이 프리뷰의 관심사가 아니라 총액 카드만 흉내 낸다.
  Widget _placeholderBody() {
    final has = _entryMonths.contains(DateTime(_month.year, _month.month));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
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
                '${_month.month}월에 쓴 돈',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.white.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                has ? '412,000원' : '0원',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          has
              ? '· 달 이름을 누르면 달 선택 시트가 열립니다.\n'
                  '· 화살표는 기록이 있는 달로 건너뜁니다.'
              : '이 달엔 기록이 없어요 (이번 달이라 열려 있는 상태)',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 13,
            height: 1.6,
            color: AppColors.gray600,
          ),
        ),
      ],
    );
  }
}
