import 'package:flutter/material.dart';

import '../../features/diary/models/diary_models.dart';
import '../../theme/colors.dart';

/// 일기 삭제 확인 bottom sheet — docs/re/reDiary_delete.png 스펙.
class DiaryDeleteSheet extends StatefulWidget {
  const DiaryDeleteSheet({
    super.key,
    required this.diary,
    required this.commentCount,
    required this.onConfirm,
  });

  /// 삭제 대상 일기.
  final Diary diary;

  /// 댓글 수 (미리보기에 노출).
  final int commentCount;

  /// 삭제 처리 콜백. true 반환 시 시트 닫음.
  final Future<bool> Function() onConfirm;

  @override
  State<DiaryDeleteSheet> createState() => _DiaryDeleteSheetState();
}

class _DiaryDeleteSheetState extends State<DiaryDeleteSheet> {
  static const Color _coral = Color(0xFFFF6B6B);
  static const Color _coralSoft = Color(0xFFFFE4E4);
  static const Color _ink = Color(0xFF191F28);
  static const Color _sub = Color(0xFF4E5968);
  static const Color _muted = Color(0xFF8B95A1);
  static const Color _chipBg = Color(0xFFF6F7F9);
  static const Color _cancelBg = Color(0xFFF2F4F6);

  bool _busy = false;

  Future<void> _onDelete() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await widget.onConfirm();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diary = widget.diary;
    final thumb = diary.imageUrls.isNotEmpty ? diary.imageUrls.first : null;
    final dateText =
        '${diary.date.year}.${diary.date.month.toString().padLeft(2, '0')}.${diary.date.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D6DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _coralSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: _coral,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '이 일기를 삭제할까요?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.3,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '삭제한 일기와 사진, 댓글은\n다시 되돌릴 수 없어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 1.5,
              color: _sub,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              color: _chipBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: thumb != null
                        ? Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFE5E8EB),
                              child: const Icon(
                                Icons.image_outlined,
                                color: _muted,
                                size: 24,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFE5E8EB),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: _muted,
                              size: 22,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diary.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateText · 댓글 ${widget.commentCount}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _busy ? null : () => Navigator.of(context).pop(),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _cancelBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _busy ? null : _onDelete,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _coral,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Text(
                            '삭제하기',
                            style: TextStyle(
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
        ],
      ),
    );
  }
}
