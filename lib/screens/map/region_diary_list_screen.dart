import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../features/block/models/block_models.dart';
import '../../features/diary/models/diary_models.dart';
import '../../theme/colors.dart';
import '../../widgets/center_title_header.dart';
import '../../widgets/retrying_network_image.dart';

/// 시그니처 지도에서 특정 지역을 선택해 들어오는 그 지역의 일기 목록.
class RegionDiaryListScreen extends StatefulWidget {
  const RegionDiaryListScreen({
    super.key,
    required this.groupRoomId,
    required this.regionKey,
    required this.label,
  });

  final String groupRoomId;
  final String regionKey;
  final String label;

  @override
  State<RegionDiaryListScreen> createState() => _RegionDiaryListScreenState();
}

class _RegionDiaryListScreenState extends State<RegionDiaryListScreen> {
  bool _loading = true;
  String? _error;
  List<DiarySummary> _diaries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Di.diaryRepository.listByRegion(
        widget.groupRoomId,
        widget.regionKey,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _diaries = res.diaries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '일기를 불러오지 못했어요';
        _loading = false;
      });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            CenterTitleHeader(title: widget.label),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.gray500,
          ),
        ),
      );
    }
    if (_diaries.isEmpty) {
      return const Center(
        child: Text(
          '이 지역의 일기가 없어요',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.gray500,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _diaries.length,
      itemBuilder: (context, i) {
        final d = _diaries[i];
        return Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context)
                .pushNamed('/diary-detail', arguments: d.id)
                .then((_) => _load()),
            child: Container(
              width: 361,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.gray100, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.hidden
                              ? hiddenReasonMessage(d.hiddenReason, noun: '일기')
                              : d.title,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: d.hidden
                                ? AppColors.gray500
                                : AppColors.gray900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.hidden
                              ? _fmtDate(d.date)
                              : '${_fmtDate(d.date)}${d.location != null && d.location!.isNotEmpty ? ' · ${d.location}' : ''}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!d.hidden &&
                      d.thumbnailUrl != null &&
                      d.thumbnailUrl!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: RetryingNetworkImage(
                        url: d.thumbnailUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        fallback: Container(
                          width: 56,
                          height: 56,
                          color: AppColors.gray100,
                          child: const Icon(Icons.image_outlined,
                              size: 18, color: AppColors.gray400),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
