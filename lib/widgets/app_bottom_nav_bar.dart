import 'package:flutter/material.dart';
import '../core/di.dart';
import '../theme/colors.dart';
import 'app_dialog.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  /// 이용 제한 계정은 메인 탭(홈/일정/일기/모찌)으로 이동할 수 없다 — 마이페이지만 허용.
  /// 막힌 경우 안내 팝업을 띄우고 true 를 반환한다.
  bool _blockedByRestriction(BuildContext context) {
    if (Di.userSession.profile?.restricted == true) {
      showRestrictionDialog(context);
      return true;
    }
    return false;
  }

  void _navigate(BuildContext context, int index) {
    if (currentIndex == index) return;
    const routes = ['/group-home', '/schedule', '/diary', '/character'];
    if (index < routes.length) {
      Navigator.of(context).pushReplacementNamed(routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.gray100, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTab(context, 0, Icons.home_rounded, Icons.home_outlined),
                _buildTab(context, 1, Icons.calendar_today_rounded, Icons.calendar_today_outlined),
                _buildTab(context, 2, Icons.menu_book_rounded, Icons.menu_book_outlined),
                _buildTab(context, 3, Icons.favorite_rounded, Icons.favorite_outline),
              ],
            ),
          ),
          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index, IconData activeIcon, IconData inactiveIcon) {
    final bool isSelected = currentIndex == index;
    final Color color = isSelected ? AppColors.primary : AppColors.gray400;
    final IconData icon = isSelected ? activeIcon : inactiveIcon;
    return GestureDetector(
      onTap: () {
        if (currentIndex != index && _blockedByRestriction(context)) return;
        if (onTap != null) {
          onTap!.call(index);
        } else {
          _navigate(context, index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Center(
          child: Icon(icon, size: 28, color: color),
        ),
      ),
    );
  }
}
