import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/character/models/character_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

/// 모찌 진화 트리.
/// 각 단계 카드: 단계명·필요 레벨·잠금/도달 표시.
class CharacterStageTreeScreen extends StatefulWidget {
  const CharacterStageTreeScreen({super.key});

  @override
  State<CharacterStageTreeScreen> createState() =>
      _CharacterStageTreeScreenState();
}

class _CharacterStageTreeScreenState extends State<CharacterStageTreeScreen> {
  CharacterStageTree? _tree;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tree = await Di.characterRepository.getStageTree();
      if (!mounted) return;
      setState(() {
        _tree = tree;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '진화 트리',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tree == null
              ? const SizedBox.shrink()
              : _buildTree(_tree!),
    );
  }

  Widget _buildTree(CharacterStageTree tree) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      itemCount: tree.stages.length,
      separatorBuilder: (_, __) => _Connector(),
      itemBuilder: (_, i) {
        final s = tree.stages[i];
        final isCurrent = s.stage == tree.currentStage;
        return _StageCard(
          info: s,
          currentLevel: tree.currentLevel,
          isCurrent: isCurrent,
        );
      },
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.info,
    required this.currentLevel,
    required this.isCurrent,
  });

  final CharacterStageInfo info;
  final int currentLevel;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final unlocked = info.unlocked;
    final borderColor = isCurrent
        ? AppColors.primary
        : (unlocked ? AppColors.gray200 : AppColors.gray100);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.white : AppColors.gray50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.gray100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              unlocked ? Icons.check_circle : Icons.lock_outline,
              color: unlocked ? AppColors.primary : AppColors.gray400,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      info.displayName,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: unlocked
                            ? AppColors.gray900
                            : AppColors.gray500,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '현재',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked
                      ? '도달 · 필요 레벨 ${info.requiredLevel}'
                      : '잠김 · Lv. ${info.requiredLevel} 도달 시 해금 (현재 Lv. $currentLevel)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: unlocked ? AppColors.gray700 : AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            width: 2,
            height: 18,
            color: AppColors.gray200,
          ),
        ],
      ),
    );
  }
}
