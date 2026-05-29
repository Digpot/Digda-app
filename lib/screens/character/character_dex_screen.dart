import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

class CharacterDexScreen extends StatefulWidget {
  const CharacterDexScreen({super.key});

  @override
  State<CharacterDexScreen> createState() => _CharacterDexScreenState();
}

class _CharacterDexScreenState extends State<CharacterDexScreen> {
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
        _errorMessage = '그룹에 들어간 뒤 도감을 볼 수 있어요.';
      });
      return;
    }
    setState(() {
      if (_tree == null) _loading = true;
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
      if (_tree != null) {
        setState(() => _loading = false);
        showAppSnackBar(context, '새로고침에 실패했어요.', isError: true);
      } else {
        setState(() {
          _loading = false;
          _errorMessage = errorMessageOf(e);
        });
      }
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
          '모찌 도감',
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
              : _buildBody(_tree!, _myState!),
    );
  }

  Widget _buildBody(CharacterStageTree tree, CharacterState me) {
    final unlockedCount = tree.stages.where((s) => s.unlocked).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Row(
            children: [
              const Text(
                '컬렉션',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.gray900,
                ),
              ),
              const Spacer(),
              Text(
                '$unlockedCount / ${tree.stages.length}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.gray700,
                ),
              ),
            ],
          ),
        ),
        // 전체 해금 진행도 바
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: tree.stages.isEmpty ? 0.0 : unlockedCount / tree.stages.length,
              minHeight: 6,
              backgroundColor: AppColors.gray100,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: tree.stages.length,
              itemBuilder: (_, i) {
                final s = tree.stages[i];
                return _DexCard(
                  info: s,
                  appearance: MochiAppearance.fromState(me),
                  isCurrent: s.stage == tree.currentStage,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DexCard extends StatelessWidget {
  const _DexCard({
    required this.info,
    required this.appearance,
    required this.isCurrent,
  });

  final CharacterStageInfo info;
  final MochiAppearance appearance;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final unlocked = info.unlocked;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.white : AppColors.gray50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary
              : (unlocked ? AppColors.gray200 : AppColors.gray100),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: unlocked ? 1.0 : 0.35,
                  child: ColorFiltered(
                    colorFilter: unlocked
                        ? const ColorFilter.mode(
                            Colors.transparent, BlendMode.dst)
                        : const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0, 0, 0, 1, 0,
                          ]),
                    child: MochiCharacterView(
                      appearance: appearance,
                      stage: info.stage,
                      size: 120,
                    ),
                  ),
                ),
                if (!unlocked)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.gray500,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  info.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: unlocked ? AppColors.gray900 : AppColors.gray500,
                  ),
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            unlocked ? '달성' : 'Lv. ${info.requiredLevel}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 11,
              color: unlocked ? AppColors.primary : AppColors.gray500,
            ),
          ),
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
