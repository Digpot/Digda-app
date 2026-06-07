import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../features/map/data/korea_map_loader.dart';
import '../../features/map/data/korea_map_models.dart';
import '../../features/map/painter/korea_map_painter.dart';
import '../../theme/colors.dart';
import '../../widgets/center_title_header.dart';
import 'region_diary_list_screen.dart';

/// 디그팟 시그니처 지도 — 그룹이 일기를 남긴 지역을 코랄로 채운다.
/// 군·시는 일기 1개, 광역시는 10개로 색칠.
class KoreaMapScreen extends StatefulWidget {
  const KoreaMapScreen({super.key});

  @override
  State<KoreaMapScreen> createState() => _KoreaMapScreenState();
}

class _KoreaMapScreenState extends State<KoreaMapScreen> {
  KoreaMapData? _data;
  Map<String, int> _counts = const {};
  bool _loading = true;
  String? _error;
  String? _selectedKey;

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
      final groupId = Di.activeGroup.groupRoomId;
      final data = await KoreaMapLoader.load();
      Map<String, int> counts = const {};
      if (groupId != null) {
        final res = await Di.diaryRepository.regionMap(groupId);
        counts = res.countByKey;
      }
      if (!mounted) return;
      setState(() {
        _data = data;
        _counts = counts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '지도를 불러오지 못했어요';
        _loading = false;
      });
    }
  }

  /// 채색 완료된 색칠키 수.
  int get _coloredCount {
    final data = _data;
    if (data == null) return 0;
    var n = 0;
    for (final entry in data.byKey.keys) {
      final meta = data.metaOf(entry);
      if (meta != null && meta.isColored(_counts[entry] ?? 0)) n++;
    }
    return n;
  }

  void _handleTap(Offset local, double scale, double dx, double dy) {
    final data = _data;
    if (data == null) return;
    final vx = (local.dx - dx) / scale;
    final vy = (local.dy - dy) / scale;
    final p = Offset(vx, vy);
    String? hit;
    for (final r in data.regions) {
      if (r.path.contains(p)) {
        hit = r.key;
        break;
      }
    }
    setState(() => _selectedKey = hit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CenterTitleHeader(title: '우리가 채운 지도'),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null || _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? '지도를 불러오지 못했어요',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    final data = _data!;
    return Column(
      children: [
        _buildSummary(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final scale = (w / data.width) < (h / data.height)
                  ? w / data.width
                  : h / data.height;
              final dx = (w - data.width * scale) / 2;
              final dy = (h - data.height * scale) / 2;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _handleTap(d.localPosition, scale, dx, dy),
                child: CustomPaint(
                  size: Size(w, h),
                  painter: KoreaMapPainter(
                    data: data,
                    counts: _counts,
                    scale: scale,
                    dx: dx,
                    dy: dy,
                    selectedKey: _selectedKey,
                  ),
                ),
              );
            },
          ),
        ),
        _buildSelectedPanel(),
      ],
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.place, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '전국 $_coloredCount곳을 채웠어요',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.gray900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPanel() {
    final data = _data!;
    final key = _selectedKey;
    if (key == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Text(
          '지역을 눌러 우리가 남긴 기록을 확인해 보세요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppColors.gray400,
          ),
        ),
      );
    }
    final meta = data.metaOf(key);
    final count = _counts[key] ?? 0;
    final label = meta?.label ?? key;
    final threshold = meta?.threshold ?? 1;
    final colored = meta?.isColored(count) ?? false;
    final remaining = (threshold - count).clamp(0, threshold);

    final String statusText;
    if (colored) {
      statusText = '색칠 완료! · 일기 $count개';
    } else if (count == 0) {
      statusText = '아직 기록이 없어요';
    } else {
      statusText = '일기 $count개 · 색칠까지 $remaining개 더!';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colored ? const Color(0xFFFFF1EE) : AppColors.gray50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colored ? const Color(0xFFFFD2C8) : AppColors.gray100,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colored ? AppColors.primary : AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            GestureDetector(
              onTap: () {
                final groupId = Di.activeGroup.groupRoomId;
                if (groupId == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RegionDiaryListScreen(
                      groupRoomId: groupId,
                      regionKey: key,
                      label: label,
                    ),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '일기 보기',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
