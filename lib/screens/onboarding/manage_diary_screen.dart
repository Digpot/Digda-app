import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class ManageDiaryScreen extends StatefulWidget {
  const ManageDiaryScreen({super.key});

  @override
  State<ManageDiaryScreen> createState() => _ManageDiaryScreenState();
}

class _ManageDiaryScreenState extends State<ManageDiaryScreen> {
  bool _membersExpanded = false;

  // TODO: API 연동 시 실제 삭제 상태로 교체
  bool _isDeleted = false;

  static const List<_MemberData> _mockMembers = [
    _MemberData(name: '김민지', color: AppColors.primary, isOwner: true),
    _MemberData(name: '이수현', color: AppColors.blue, isOwner: false),
    _MemberData(name: '박지호', color: AppColors.green, isOwner: false),
    _MemberData(name: '최서연', color: AppColors.purple, isOwner: false),
    _MemberData(name: '정우진', color: Color(0xFFF0A050), isOwner: false),
    _MemberData(name: '한예린', color: Color(0xFF6B82F0), isOwner: false),
    _MemberData(name: '송태민', color: AppColors.primary, isOwner: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '다이어리 관리',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // 다이어리 복구 배너 (삭제된 상태일 때)
                    if (_isDeleted) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.restore_rounded,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '삭제 예정 다이어리',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '이 다이어리는 7일 후에 완전히 삭제됩니다.\n지금 복구하면 모든 데이터가 유지됩니다.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                fontSize: 13,
                                height: 1.5,
                                color: AppColors.gray700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                // TODO: API 연동 시 복구 로직 구현
                                setState(() => _isDeleted = false);
                              },
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Text(
                                    '다이어리 복구하기',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // ── 멤버 관리 ──
                    GestureDetector(
                      onTap: () =>
                          setState(() => _membersExpanded = !_membersExpanded),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gray100),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people_outline_rounded,
                              size: 20,
                              color: AppColors.gray700,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              '멤버 관리',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.gray900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_mockMembers.length}명',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                fontSize: 13,
                                color: AppColors.gray400,
                              ),
                            ),
                            const Spacer(),
                            AnimatedRotation(
                              turns: _membersExpanded ? 0.25 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: AppColors.gray400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 멤버 리스트 (펼침)
                    if (_membersExpanded) ...[
                      const SizedBox(height: 8),
                      ...List.generate(_mockMembers.length, (i) {
                        final member = _mockMembers[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gray100),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      member.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    member.name[0],
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: member.color,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.name,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.gray900,
                                      ),
                                    ),
                                    if (member.isOwner)
                                      const Text(
                                        '방장',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (!member.isOwner)
                                GestureDetector(
                                  onTap: () =>
                                      _showRemoveMemberDialog(member.name),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: AppColors.gray200),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '삭제',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                    // ── 다이어리 삭제 ──
                    if (!_isDeleted)
                      GestureDetector(
                        onTap: _showDeleteRoomDialog,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '다이어리 삭제',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 멤버 삭제 다이얼로그 (2단계) ──

  void _showRemoveMemberDialog(String memberName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '멤버를 삭제할까요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: Text(
          '$memberName님을 이 다이어리에서\n내보내시겠어요?',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showMemberRemoveFinalConfirm(memberName);
            },
            child: const Text(
              '삭제',
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

  void _showMemberRemoveFinalConfirm(String memberName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '정말 내보내시겠어요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: Text(
          '$memberName님은 이 다이어리의 모든\n기록에 접근할 수 없게 됩니다.',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: API 연동 시 실제 삭제 로직
            },
            child: const Text(
              '내보내기',
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

  // ── 방 삭제 다이얼로그 (2단계) ──

  void _showDeleteRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '다이어리를 삭제할까요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: const Text(
          '삭제하면 모든 멤버가 이 다이어리에\n접근할 수 없게 됩니다.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteRoomFinalConfirm();
            },
            child: const Text(
              '삭제',
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

  void _showDeleteRoomFinalConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '정말 삭제하시겠어요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: const Text(
          '다이어리는 7일 후에 완전히 삭제됩니다.\n7일 이내에 복구할 수 있어요.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isDeleted = true);
            },
            child: const Text(
              '삭제하기',
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
}

class _MemberData {
  final String name;
  final Color color;
  final bool isOwner;

  const _MemberData({
    required this.name,
    required this.color,
    required this.isOwner,
  });
}
