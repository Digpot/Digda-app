import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import '../../theme/colors.dart';

class CharacterStageTreeScreen extends StatefulWidget {
  const CharacterStageTreeScreen({super.key});

  @override
  State<CharacterStageTreeScreen> createState() =>
      _CharacterStageTreeScreenState();
}

class _CharacterStageTreeScreenState extends State<CharacterStageTreeScreen> {
  CharacterStageTree? _tree;
  CharacterState? _myState;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  int? get _activeGroupId {
    final raw = Di.activeGroup.groupRoomId;
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> _load() async {
    final groupId = _activeGroupId;
    if (groupId == null) {
      setState(() {
        _loading = false;
        _errorMessage = '그룹에 들어간 뒤 진화 트리를 볼 수 있어요.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        Di.characterRepository.getStageTree(groupRoomId: groupId),
        Di.characterRepository.getMyState(groupRoomId: groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _tree = results[0] as CharacterStageTree;
        _myState = results[1] as CharacterState;
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
          : _errorMessage != null
              ? _ErrorRetry(message: _errorMessage!, onRetry: _load)
              : _buildTree(_tree!, _myState!),
    );
  }

  Widget _buildTree(CharacterStageTree tree, CharacterState me) {
    final nextStage = tree.stages.where((s) => !s.unlocked).firstOrNull;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      itemCount: tree.stages.length + (nextStage != null ? 1 : 0),
      separatorBuilder: (_, i) {
        if (nextStage != null && i == tree.stages.length - 1) {
          return const SizedBox.shrink();
        }
        return _Connector();
      },
      itemBuilder: (_, i) {
        if (i == tree.stages.length) {
          final needed = nextStage!.requiredLevel - tree.currentLevel;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '다음 진화까지 $needed 레벨 남았어요',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final s = tree.stages[i];
        final isCurrent = s.stage == tree.currentStage;
        return _StageCard(
          info: s,
          currentLevel: tree.currentLevel,
          isCurrent: isCurrent,
          appearance: MochiAppearance.fromState(me),
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
    required this.appearance,
  });

  final CharacterStageInfo info;
  final int currentLevel;
  final bool isCurrent;
  final MochiAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final unlocked = info.unlocked;
    final borderColor = isCurrent
        ? AppColors.primary
        : (unlocked ? AppColors.gray200 : AppColors.gray100);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.white : AppColors.gray50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: unlocked ? 1.0 : 0.35,
            child: ColorFiltered(
              colorFilter: unlocked
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
              child: MochiCharacterView(
                appearance: appearance,
                stage: info.stage,
                size: 56,
              ),
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
                        color:
                            unlocked ? AppColors.gray900 : AppColors.gray500,
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
                    ] else if (unlocked) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle,
                          color: AppColors.green, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked
                      ? 'Lv. ${info.requiredLevel} 달성'
                      : 'Lv. ${info.requiredLevel} 도달 시 해금 (현재 Lv. $currentLevel)',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: AppColors.gray500,
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
          Container(width: 2, height: 18, color: AppColors.gray200),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.gray400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
