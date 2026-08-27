import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 달 선택 시트. 가계부 · 일정 · 일기 세 화면이 같은 걸 쓴다.
///
/// `showDatePicker` 를 쓰지 않는 이유:
/// 1. 이 화면들은 **날짜가 아니라 달**을 고른다. 일(day) 격자는 고를 필요 없는 것을 묻는다.
/// 2. 고를 수 없는 달을 눌리지 않게 막을 방법이 없다(가계부).
///
/// 두 가지 모드가 있다.
/// - [selectableMonths] 를 주면 **그 달들만** 고를 수 있다. 나머지는 테두리만 남고 눌리지
///   않는다. 기록이 있는 달에는 점이 찍힌다 — 가계부용.
/// - 주지 않으면 [firstYear]~[lastYear] 안의 **모든 달**을 고를 수 있다. 점도 범례도 없다
///   — 일정·일기처럼 '기록 있는 달'이라는 개념이 없는 화면용.
///
/// 고른 달(그 달 1일)을 돌려주고, 취소하면 null.
Future<DateTime?> showMonthPickerSheet(
  BuildContext context, {
  required DateTime selected,
  Set<DateTime>? selectableMonths,
  int firstYear = 2020,
  int lastYear = 2030,
  String title = '어느 달을 볼까요',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MonthPickerSheet(
      selected: selected,
      selectableMonths: selectableMonths,
      firstYear: firstYear,
      lastYear: lastYear,
      title: title,
    ),
  );
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({
    required this.selected,
    required this.selectableMonths,
    required this.firstYear,
    required this.lastYear,
    required this.title,
  });

  final DateTime selected;

  /// 고를 수 있는 달 (각 원소는 그 달 1일). null 이면 연도 범위 안의 모든 달.
  final Set<DateTime>? selectableMonths;

  final int firstYear;
  final int lastYear;
  final String title;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year = widget.selected.year;

  /// 고를 수 있는 달을 목록으로 제한하는 모드인가. 점·범례·안내가 여기에 딸려 있다.
  bool get _restricted => widget.selectableMonths != null;

  /// 고를 수 있는 달이 있는 연도 — 오름차순. 연도 이동은 이 안에서만 한다.
  /// 지금 보고 있는 연도는 기록이 없어도 넣는다(빈 목록이 되어 화면이 멈추지 않게).
  late final List<int> _years = _buildYears();

  List<int> _buildYears() {
    final months = widget.selectableMonths;
    if (months == null) {
      return [for (var y = widget.firstYear; y <= widget.lastYear; y++) y];
    }
    final years = months.map((m) => m.year).toSet()..add(widget.selected.year);
    return years.toList()..sort();
  }

  bool _isSelectable(int year, int month) =>
      !_restricted || widget.selectableMonths!.contains(DateTime(year, month));

  /// 그 해에 기록이 있는 달 수 — 연도 아래 요약에 쓴다(제한 모드에서만).
  int _countIn(int year) =>
      widget.selectableMonths?.where((m) => m.year == year).length ?? 0;

  int? get _prevYear {
    final index = _years.indexOf(_year);
    if (index <= 0) return null;
    return _years[index - 1];
  }

  int? get _nextYear {
    final index = _years.indexOf(_year);
    if (index < 0 || index >= _years.length - 1) return null;
    return _years[index + 1];
  }

  /// 기록 없는 달을 눌렀을 때 격자 아래에 잠깐 뜨는 안내. 없으면 범례를 보여준다.
  String? _notice;
  Timer? _noticeTimer;

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _onMonthTap(int month) {
    if (!_isSelectable(_year, month)) {
      // 눌리지 않는 이유를 말해준다 — 회색이 '고장'이 아니라 '기록 없음'이라는 걸
      // 알 방법이 색밖에 없으면 사용자는 계속 누른다.
      //
      // 스낵바를 쓰지 않는다: 시트가 화면 아래를 덮고 있어 스낵바가 그 뒤에 깔려
      // 보이지 않는다. 안내는 시트 안에 있어야 눈에 든다.
      setState(() => _notice = '$_year년 $month월엔 기록된 지출이 없어요');
      _noticeTimer?.cancel();
      _noticeTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _notice = null);
      });
      return;
    }
    Navigator.of(context).pop(DateTime(_year, month));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bottomSheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.gray900,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _buildYearRow(),
              const SizedBox(height: 18),
              _buildMonthGrid(now),
              // 모든 달을 고를 수 있는 화면(일정·일기)엔 설명할 게 없다.
              // 안 눌리는 칸이 없으니 범례도, 안내도 자리만 차지한다.
              if (_restricted) ...[
                const SizedBox(height: 16),
                _buildFooterLine(),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYearRow() {
    final count = _countIn(_year);
    return Row(
      children: [
        _YearArrow(
          icon: Icons.chevron_left_rounded,
          onTap:
              _prevYear == null ? null : () => setState(() => _year = _prevYear!),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '$_year년',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: AppColors.gray900,
                ),
              ),
              // 제한 모드에서만 요약을 붙인다. 모든 달을 고를 수 있는 화면에선
              // '12개 달에 기록' 같은 말이 아무것도 알려주지 않는다.
              if (_restricted) ...[
                const SizedBox(height: 2),
                Text(
                  count == 0 ? '기록 없음' : '$count개 달에 기록',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: count == 0 ? AppColors.gray400 : AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        _YearArrow(
          icon: Icons.chevron_right_rounded,
          onTap:
              _nextYear == null ? null : () => setState(() => _year = _nextYear!),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(DateTime now) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final month = index + 1;
        return _MonthCell(
          month: month,
          selectable: _isSelectable(_year, month),
          // 점은 '기록이 있다'는 표시다. 모든 달을 고를 수 있는 화면에선 모든 칸에
          // 점이 찍혀 아무 뜻도 없어지므로 끈다.
          showDot: _restricted,
          isSelected:
              _year == widget.selected.year && month == widget.selected.month,
          isThisMonth: _year == now.year && month == now.month,
          onTap: () => _onMonthTap(month),
        );
      },
    );
  }

  /// 격자 아래 한 줄 — 평소엔 빈 칸이 왜 빈 칸인지 알려주는 범례,
  /// 기록 없는 달을 누른 직후엔 그 달을 짚어주는 안내.
  ///
  /// 자리를 늘 차지하게 둔다. 안내가 나타났다 사라질 때마다 시트 높이가 출렁이면
  /// 아래 격자가 따라 움직여 다른 달을 잘못 누르게 된다.
  Widget _buildFooterLine() {
    final notice = _notice;
    return SizedBox(
      height: 22,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: notice != null
              ? Row(
                  key: const ValueKey('notice'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      notice,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('legend'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gray100, width: 1.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      '테두리만 있는 달은 기록된 지출이 없어요',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _YearArrow extends StatelessWidget {
  const _YearArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.gray50 : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 26,
            color: enabled ? AppColors.gray700 : AppColors.gray200,
          ),
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.month,
    required this.selectable,
    required this.showDot,
    required this.isSelected,
    required this.isThisMonth,
    required this.onTap,
  });

  final int month;
  final bool selectable;

  /// '기록 있음' 점을 찍을지. 모든 달을 고를 수 있는 화면에선 끈다.
  final bool showDot;
  final bool isSelected;
  final bool isThisMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 세 상태를 **채움/비움**으로 가른다 — 명도만 살짝 다르게 하면 나란히 놓였을 때
    // 어느 쪽이 눌리는지 알아볼 수 없다.
    //   고른 달   : 코랄로 꽉 채움
    //   기록 있는 달 : 회색으로 채움 + 코랄 점
    //   기록 없는 달 : 채우지 않고 테두리만 (= 비어 있다는 뜻 그대로)
    final Color background;
    final Color foreground;
    if (isSelected) {
      background = AppColors.primary;
      foreground = AppColors.white;
    } else if (selectable) {
      background = AppColors.gray50;
      foreground = AppColors.gray900;
    } else {
      background = Colors.transparent;
      foreground = AppColors.gray300;
    }

    Border? border;
    if (isThisMonth && !isSelected) {
      // 이번 달은 고르지 않았어도 코랄 테두리로 '지금 어디쯤인지'를 남긴다.
      border = Border.all(color: AppColors.primary, width: 1.4);
    } else if (!selectable) {
      border = Border.all(color: AppColors.gray100, width: 1.2);
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$month월',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  fontSize: 16,
                  color: foreground,
                ),
              ),
              // 기록이 있는 달에만 점을 찍는다. 고른 달은 흰 점이라 채움 위에서도 보인다.
              if (showDot) ...[
                const SizedBox(height: 3),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !selectable
                        ? Colors.transparent
                        : isSelected
                            ? AppColors.white
                            : AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
