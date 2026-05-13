import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/group_room/models/group_room_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/feature_card.dart';

class GroupHomeScreen extends StatefulWidget {
  const GroupHomeScreen({
    super.key,
    this.groupName = '대학 친구들',
    this.isOwner = true,
  });

  final String groupName;
  final bool isOwner;

  @override
  State<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends State<GroupHomeScreen> {
  static const _memberColors = [
    AppColors.primary,
    AppColors.blue,
    AppColors.green,
    AppColors.purple,
  ];

  GroupRoomDetail? _detail;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final activeId = Di.activeGroup.groupRoomId;
    if (activeId == null) {
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
      final detail = await Di.groupRoomRepository.detail(activeId);
      if (!mounted) return;
      // 활성 컨텍스트의 역할/이름을 최신으로 동기화.
      Di.activeGroup.enter(
        groupRoomId: detail.groupRoom.id,
        groupRoomName: detail.groupRoom.name,
        isOwner: detail.isOwner,
      );
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = errorMessageOf(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    String dynamicName = widget.groupName;
    int memberCount = 7;
    bool dynamicIsOwner = widget.isOwner;
    if (args is Map<String, dynamic>) {
      dynamicName = args['name'] as String? ?? widget.groupName;
      memberCount = args['members'] as int? ?? 7;
      dynamicIsOwner = args['isOwner'] as bool? ?? widget.isOwner;
    } else if (args is String) {
      dynamicName = args;
    }

    final detail = _detail;
    if (detail != null) {
      dynamicName = detail.groupRoom.name;
      memberCount = detail.memberships.isNotEmpty
          ? detail.memberships.length
          : detail.groupRoom.memberCount;
      dynamicIsOwner = detail.isOwner;
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Di.activeGroup.clear();
                      Navigator.of(context).pop();
                    },
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      dynamicName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: AppColors.gray900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed('/notifications'),
                    child: const Icon(
                      Icons.notifications_outlined,
                      size: 22,
                      color: AppColors.gray700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context)
                        .pushNamed('/manage-diary')
                        .then((_) => _load()),
                    child: const Icon(
                      Icons.settings_outlined,
                      size: 22,
                      color: AppColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                _buildMemberSection(memberCount),
                                const SizedBox(height: 60),
                                FeatureCard(
                                  icon: Icons.calendar_month_outlined,
                                  iconBgColor: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  iconColor: AppColors.primary,
                                  cardBgColor: AppColors.primary
                                      .withValues(alpha: 0.06),
                                  title: '일정 관리',
                                  subtitle: '우리 모임 일정을 한눈에',
                                  onTap: () => Navigator.of(context)
                                      .pushNamed('/schedule'),
                                ),
                                const SizedBox(height: 12),
                                FeatureCard(
                                  icon: Icons.book_outlined,
                                  iconBgColor: const Color(0xFFFFE88A),
                                  iconColor: const Color(0xFFC89A00),
                                  cardBgColor: const Color(0xFFFFFBEE),
                                  title: '그림일기',
                                  subtitle: '오늘의 추억을 기록해요',
                                  onTap: () => Navigator.of(context)
                                      .pushNamed('/diary'),
                                ),
                                const SizedBox(height: 12),
                                FeatureCard(
                                  icon: Icons.sentiment_satisfied_outlined,
                                  iconBgColor: AppColors.gray100,
                                  iconColor: AppColors.gray400,
                                  cardBgColor: AppColors.gray50,
                                  title: '퀴즈 게임',
                                  subtitle: '준비 중이에요',
                                  isDisabled: true,
                                  badge: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.gray200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Coming Soon',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FeatureCard(
                                  icon: Icons.check_box_outlined,
                                  iconBgColor:
                                      AppColors.blue.withValues(alpha: 0.2),
                                  iconColor: AppColors.blue,
                                  cardBgColor:
                                      AppColors.blue.withValues(alpha: 0.06),
                                  title: '투두리스트',
                                  subtitle: '할 일을 함께 관리해요',
                                  onTap: () => Navigator.of(context)
                                      .pushNamed('/todo'),
                                ),
                                if (dynamicIsOwner) ...[
                                  const SizedBox(height: 12),
                                  FeatureCard(
                                    icon: Icons.swap_horiz_rounded,
                                    iconBgColor: AppColors.purple
                                        .withValues(alpha: 0.15),
                                    iconColor: AppColors.purple,
                                    cardBgColor: AppColors.purple
                                        .withValues(alpha: 0.06),
                                    title: '방장 양도',
                                    subtitle: '다른 멤버에게 방장을 넘겨요',
                                    onTap: () => Navigator.of(context)
                                        .pushNamed(
                                      '/transfer-owner',
                                      arguments: dynamicName,
                                    ).then((_) => _load()),
                                  ),
                                ],
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppColors.gray400),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage ?? '',
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
            onPressed: _load,
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

  Widget _buildMemberSection(int totalMembers) {
    final displayCount = totalMembers > 4 ? 4 : totalMembers;
    final extraCount = totalMembers - displayCount;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...List.generate(displayCount, (i) => _buildAvatar(i)),
            if (extraCount > 0) ...[
              const SizedBox(width: 8),
              _buildExtraAvatar(extraCount),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$totalMembers명 참여 중',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(int index) {
    final color = _memberColors[index % _memberColors.length];
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
      ),
      child: Icon(Icons.person_outline, size: 22, color: color),
    );
  }

  Widget _buildExtraAvatar(int count) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.gray100,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.gray500,
          ),
        ),
      ),
    );
  }
}
