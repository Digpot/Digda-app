import 'package:flutter/material.dart';
import '../features/ledger/models/ledger_models.dart';
import '../theme/colors.dart';

/// 가계부 분류의 색·아이콘 매핑.
///
/// 캘린더 · 일정 추가 · 일정 상세 · 전체 가계부 네 화면이 같은 분류를 그린다.
/// 각자 매핑을 들고 있으면 화면마다 식비 색이 달라지므로 여기 한 곳만 둔다.
Color categoryColor(ExpenseCategory category) {
  switch (category) {
    case ExpenseCategory.food:
      return AppColors.ledgerFood;
    case ExpenseCategory.transport:
      return AppColors.ledgerTransport;
    case ExpenseCategory.lodging:
      return AppColors.ledgerLodging;
    case ExpenseCategory.shopping:
      return AppColors.ledgerShopping;
    case ExpenseCategory.etc:
      return AppColors.ledgerEtc;
  }
}

IconData categoryIcon(ExpenseCategory category) {
  switch (category) {
    case ExpenseCategory.food:
      return Icons.restaurant_rounded;
    case ExpenseCategory.transport:
      return Icons.directions_bus_rounded;
    case ExpenseCategory.lodging:
      return Icons.hotel_rounded;
    case ExpenseCategory.shopping:
      return Icons.shopping_bag_rounded;
    case ExpenseCategory.etc:
      return Icons.more_horiz_rounded;
  }
}

/// 분류 아이콘을 둥근 배경에 얹은 작은 배지 — 목록 좌측 표식으로 공용.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.category,
    this.size = 36,
  });

  final ExpenseCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(categoryIcon(category), size: size * 0.5, color: color),
    );
  }
}
