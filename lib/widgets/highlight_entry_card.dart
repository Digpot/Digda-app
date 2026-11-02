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
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF2A1B2E), Color(0xFF4A2C4A)],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (item.coverImageUrl != null)
                SizedBox(
                  width: 92,
                  height: 92,
                  child: RetryingNetworkImage(url: item.coverImageUrl!),
                )
              else
                const SizedBox(
                  width: 92,
                  child: Center(child: Text('📖', style: TextStyle(fontSize: 30))),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.monthValue}월의 디그팟 하이라이트',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.totalDiaryCount}편의 추억을 돌아봐요',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
