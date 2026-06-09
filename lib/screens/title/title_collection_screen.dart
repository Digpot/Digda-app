import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/title/models/title_models.dart';
import '../../features/title/title_catalog.dart';
import '../../features/title/widgets/title_badge.dart';
import '../../theme/colors.dart';
import '../../widgets/back_header.dart';

/// 칭호 수집·조회 화면(마이페이지). 계정 단위로 보관되어 그룹방 탈퇴와 무관하게 유지된다.
class TitleCollectionScreen extends StatefulWidget {
  const TitleCollectionScreen({super.key});

  @override
  State<TitleCollectionScreen> createState() => _TitleCollectionScreenState();
}

class _TitleCollectionScreenState extends State<TitleCollectionScreen> {
  bool _loading = true;
  String? _error;
  Map<String, EarnedTitle> _earned = const {};

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
      await TitleCatalog.ensureLoaded(); // 서버 카탈로그(메타) 로드
      final list = await Di.titleRepository.list();
      if (!mounted) return;
      setState(() {
        _earned = {for (final t in list) t.code: t};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessageOf(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const BackHeader(title: '칭호 수집가'),
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
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 13, color: AppColors.gray500)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    final total = TitleCatalog.all.length;
    final owned = TitleCatalog.all.where((t) => _earned.containsKey(t.code)).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummary(owned, total),
          const SizedBox(height: 8),
          for (final cat in TitleCategory.values) _buildCategory(cat),
        ],
      ),
    );
  }

  Widget _buildSummary(int owned, int total) {
    final frac = total == 0 ? 0.0 : (owned / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                '내 칭호',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.gray900,
                ),
              ),
              const Spacer(),
              Text(
                '$owned / $total',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 7,
              backgroundColor: Colors.white,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(TitleCategory cat) {
    final defs = TitleCatalog.ofCategory(cat);
    if (defs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cat.label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(height: 12),
          // 그리드 블록 전체를 중앙 정렬(좌우 여백 균등) + 부분 줄(2개짜리)은 왼쪽 정렬.
          LayoutBuilder(
            builder: (context, c) {
              const tile = 88.0;
              const gap = 14.0;
              final cols = ((c.maxWidth + gap) / (tile + gap))
                  .floor()
                  .clamp(1, defs.length);
              final gridW = cols * tile + (cols - 1) * gap;
              return Center(
                child: SizedBox(
                  width: gridW,
                  child: Wrap(
                    spacing: gap,
                    runSpacing: 18,
                    children: defs.map(_buildTile).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTile(TitleDef def) {
    final e = _earned[def.code];
    final earned = e != null;
    return GestureDetector(
      onTap: () => _showDetail(def),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            TitleBadge(def: def, earned: earned, size: 78),
            const SizedBox(height: 8),
            Text(
              earned ? def.name : '???',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                height: 1.2,
                color: earned ? AppColors.gray900 : AppColors.gray400,
              ),
            ),
            if (e != null) ...[
              const SizedBox(height: 2),
              Text(
                _shortDate(e.earnedAt),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                  color: AppColors.gray400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _shortDate(DateTime d) =>
      '${d.year % 100}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  void _showDetail(TitleDef def) {
    final earnedTitle = _earned[def.code];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TitleDetailSheet(def: def, earned: earnedTitle),
    );
  }
}

class _TitleDetailSheet extends StatefulWidget {
  const _TitleDetailSheet({required this.def, required this.earned});

  final TitleDef def;
  final EarnedTitle? earned;

  @override
  State<_TitleDetailSheet> createState() => _TitleDetailSheetState();
}

class _TitleDetailSheetState extends State<_TitleDetailSheet> {
  final GlobalKey _captureKey = GlobalKey();
  bool _sharing = false;

  bool get _isEarned => widget.earned != null;

  String get _earnedText {
    final e = widget.earned;
    if (e == null) return '아직 획득하지 못한 칭호예요';
    final d = e.earnedAt;
    final date =
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    if (e.groupRoomName != null && e.groupRoomName!.isNotEmpty) {
      return '${e.groupRoomName} 그룹방에서 따셨어요 · $date';
    }
    return '$date 획득';
  }

  Future<void> _download() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // 캡처 위젯이 확실히 그려진 뒤 한 프레임 양보.
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final file = File(
        '${Directory.systemTemp.path}/title_${widget.def.code}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: widget.def.name,
      );
    } catch (_) {
      // 공유 취소/실패는 조용히 무시
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final accent = _isEarned ? def.accent : AppColors.gray400;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // 캡처 영역 — 다운로드(공유) 시 이미지로 저장되는 카드.
          RepaintBoundary(
            key: _captureKey,
            child: Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TitleBadge(def: def, earned: _isEarned, size: 132),
                  const SizedBox(height: 16),
                  Text(
                    _isEarned ? def.name : '???',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: _isEarned ? AppColors.gray900 : AppColors.gray400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    def.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isEarned ? Icons.verified_rounded : Icons.lock_rounded,
                    size: 15,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _earnedText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_isEarned)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _sharing ? null : _download,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.gray200,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _sharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded,
                          size: 18, color: AppColors.white),
                  label: Text(
                    _sharing ? '준비 중...' : '칭호 이미지 저장',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
