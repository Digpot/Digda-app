import 'package:flutter/material.dart';

import '../core/di.dart';
import '../features/highlight/models/highlight_models.dart';
import '../theme/colors.dart';
import 'retrying_network_image.dart';

/// 그룹 홈 진입 카드 — 가장 최근 월간 하이라이트가 있을 때만 보인다.
/// 대표 사진을 배경으로 깔고 월·일기 수를 얹는다. 스스로 목록을 불러오고,
/// 없거나 실패하면 아무것도 그리지 않아 홈 레이아웃에 영향이 없다.
class HighlightEntryCard extends StatefulWidget {
  const HighlightEntryCard({super.key});

  @override
  State<HighlightEntryCard> createState() => _HighlightEntryCardState();
}

class _HighlightEntryCardState extends State<HighlightEntryCard> {
  HighlightListItem? _latest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    try {
      final items = await Di.highlightRepository.list(groupId);
      if (!mounted || items.isEmpty) return;
      setState(() => _latest = items.first);
    } catch (_) {
      // 부가 기능 — 실패해도 홈은 그대로.
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _latest;
    if (item == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: GestureDetector(
        onTap: () => Navigator.of(context)
            .pushNamed('/highlight', arguments: {'month': item.month}),
        child: Container(
          height: 124,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.coverImageUrl != null)
                RetryingNetworkImage(url: item.coverImageUrl!)
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF8E72), AppColors.primary],
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.62),
                      Colors.black.withValues(alpha: 0.12),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'MONTHLY HIGHLIGHT',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                letterSpacing: 1.2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${item.monthValue}월, 우리의 기록',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${item.totalDiaryCount}편의 추억을 돌아봐요',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
