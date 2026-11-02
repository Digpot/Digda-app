import 'package:flutter/material.dart';

import '../core/di.dart';
import '../features/highlight/models/highlight_models.dart';
import '../theme/colors.dart';
import 'retrying_network_image.dart';

/// 그룹 홈 진입 카드 — 가장 최근 월간 하이라이트가 있을 때만 보인다.
/// 스스로 목록을 불러오고, 없거나 실패하면 아무것도 그리지 않아 홈 레이아웃에 영향이 없다.
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4EE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: item.coverImageUrl != null
                      ? RetryingNetworkImage(url: item.coverImageUrl!)
                      : Container(
                          color: const Color(0xFFFFE2D6),
                          alignment: Alignment.center,
                          child:
                              const Text('📖', style: TextStyle(fontSize: 26)),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.monthValue}월의 하이라이트',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.totalDiaryCount}편의 추억을 돌아봐요',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
