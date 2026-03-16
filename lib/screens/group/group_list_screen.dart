import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/colors.dart';
import '../../widgets/group_list_tile.dart';

class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  static const _groups = [
    _GroupData(
      name: '대학 친구들',
      members: 4,
      icon: Icons.image_outlined,
      bgColor: Color(0xFFFFEAEA),
      iconColor: AppColors.primary,
      showActions: false,
    ),
    _GroupData(
      name: '여행 모임',
      members: 6,
      icon: Icons.diamond_outlined,
      bgColor: Color(0xFFEAEEFF),
      iconColor: Color(0xFF6B82F0),
      showActions: true,
    ),
    _GroupData(
      name: '회사 동기',
      members: 2,
      icon: Icons.coffee_outlined,
      bgColor: Color(0xFFFFF3E0),
      iconColor: Color(0xFFF0A050),
      showActions: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더 - 푸터 제거됨, 제목 변경
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '내 다이어리',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      height: 1.3,
                      color: AppColors.gray900,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed('/notifications'),
                    child: Stack(
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          size: 22,
                          color: AppColors.gray700,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed('/my-page'),
                    child: const Icon(
                      Icons.settings_outlined,
                      size: 22,
                      color: AppColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
            // 그룹 리스트 - 그룹 수에 따라 동적 중앙 배치
            Expanded(
              child: _groups.length < 6
                  ? Center(
                      child: _buildGroupContent(context),
                    )
                  : SingleChildScrollView(
                      child: _buildGroupContent(context),
                    ),
            ),
          ],
        ),
      ),
      // 푸터 제거됨
    );
  }

  void _showInviteCodeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) => const _InviteCodeBottomSheet(),
    );
  }

  Widget _buildGroupContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._groups.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GroupListTile(
                name: g.name,
                memberCount: '${g.members}명 참여 중',
                groupIcon: g.icon,
                groupIconBg: g.bgColor,
                groupIconColor: g.iconColor,
                showActions: g.showActions,
                onTap: () => Navigator.of(context).pushNamed('/group-home',
                    arguments: {'name': g.name, 'members': g.members}),
                onShare: () => _showInviteCodeSheet(context),
                onSettings: () =>
                    Navigator.of(context).pushNamed('/update-diary'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/create-diary'),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '새 다이어리 추가',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupData {
  final String name;
  final int members;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final bool showActions;

  const _GroupData({
    required this.name,
    required this.members,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.showActions,
  });
}

class _InviteCodeBottomSheet extends StatefulWidget {
  const _InviteCodeBottomSheet();

  @override
  State<_InviteCodeBottomSheet> createState() => _InviteCodeBottomSheetState();
}

class _InviteCodeBottomSheetState extends State<_InviteCodeBottomSheet> {
  final String _generatedCode = 'A3X9K2';
  bool _copied = false;

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _generatedCode));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '초대 코드가 생성됐어요!',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              height: 1.3,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                _generatedCode,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 36,
                  letterSpacing: 6,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _copyCode,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gray200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _copied ? '복사됨' : '코드 복사',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.gray700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Share.share(
                      'Digda에서 함께 일기를 써요!\n\n초대 코드: $_generatedCode\n\nDigda 앱을 열고 초대 코드를 입력해주세요 🙌',
                    );
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        '공유하기',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              '상대방이 이 코드를 입력하면 연결돼요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13,
                color: AppColors.gray500,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '코드는 24시간 후 만료됩니다',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: AppColors.gray400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
