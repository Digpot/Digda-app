import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'app_dialog.dart';

/// 가계부 달 선택 시트.
///
/// `showDatePicker` 를 쓰지 않는 이유가 둘 있다.
/// 1. 가계부는 **날짜가 아니라 달**을 고른다. 일(day) 격자는 고를 필요 없는 것을 묻는다.
/// 2. 기록이 없는 달을 눌리지 않게 막을 방법이 없다. 첫 달~마지막 달 사이에도 한 푼도
///    안 쓴 달이 얼마든지 있고, 그런 달은 눌러 봐야 빈 화면이다.
///
/// 고른 달을 돌려주고, 취소하면 null.
Future<DateTime?> showMonthPickerSheet(
  BuildContext context, {
  required DateTime selected,
  required Set<DateTime> selectableMonths,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MonthPickerSheet(
      selected: selected,
      selectableMonths: selectableMonths,
    ),
  );
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({
    required this.selected,
    required this.selectableMonths,
  });

  final DateTime selected;

  /// 고를 수 있는 달 (각 원소는 그 달 1일).
  final Set<DateTime> selectableMonths;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year = widget.selected.year;

  /// 고를 수 있는 달이 하나라도 있는 연도 — 오름차순. 연도 이동은 이 안에서만 한다.
  /// 지금 보고 있는 연도는 기록이 없어도 넣는다(빈 목록이 되어 화면이 멈추지 않게).
  late final List<int> _years =
      (widget.selectableMonths.map((m) => m.year).toSet()
            ..add(widget.selected.year))
          .toList()
        ..sort();

  bool _isSelectable(int year, int month) =>
      widget.selectableMonths.contains(DateTime(year, month));

  /// 그 해에 기록이 있는 달 수 — 연도 아래 요약에 쓴다.
  int _countIn(int year) =>
      widget.selectableMonths.where((m) => m.year == year).length;

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

  void _onMonthTap(int month) {
    if (!_isSelectable(_year, month)) {
      // 눌리지 않는 이유를 말해준다 — 회색이 '고장'이 아니라 '기록 없음'이라는 걸
      // 알 방법이 색밖에 없으면 사용자는 계속 누른다.
      showAppSnackBar(context, '$_year년 $month월엔 기록된 지출이 없어요');
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '어느 달을 볼까요',
                  style: TextStyle(
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
              const SizedBox(height: 14),
              _buildLegend(),
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
          isSelected:
              _year == widget.selected.year && month == widget.selected.month,
          isThisMonth: _year == now.year && month == now.month,
          onTap: () => _onMonthTap(month),
        );
      },
    );
  }

  /// 회색 칸이 왜 회색인지 한 줄로 밝혀둔다.
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        const Text(
          '흐린 달은 기록된 지출이 없어요',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.gray500,
          ),
        ),
      ],
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
    required this.isSelected,
    required this.isThisMonth,
    required this.onTap,
  });

  final int month;
  final bool selectable;
  final bool isSelected;
  final bool isThisMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 세 상태 — 고른 달(코랄 채움) / 고를 수 있는 달(연회색) / 기록 없는 달(더 흐림).
    final Color background;
    final Color foreground;
    if (isSelected) {
      background = AppColors.primary;
      foreground = AppColors.white;
    } else if (selectable) {
      background = AppColors.gray50;
      foreground = AppColors.gray900;
    } else {
      background = AppColors.gray50.withValues(alpha: 0.5);
      foreground = AppColors.gray300;
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
            // 이번 달은 고르지 않았어도 테두리로 표시해 '지금 어디쯤인지'를 남긴다.
            border: isThisMonth && !isSelected
                ? Border.all(color: AppColors.primary, width: 1.4)
                : null,
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
              const SizedBox(height: 3),
              // 기록이 있는 달에만 점을 찍는다. 고른 달은 흰 점이라 채움 위에서도 보인다.
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
          ),
        ),
      ),
    );
  }
}
