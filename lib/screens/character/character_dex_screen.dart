import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

/// 모찌 도감 — 5단계 모찌를 그리드(2열)로 모아 보여준다.
/// 도달 단계는 컬러로, 잠긴 단계는 흑백 + 자물쇠 라벨.
class CharacterDexScreen extends StatefulWidget {
  const CharacterDexScreen({super.key});

  @override
  State<CharacterDexScreen> createState() => _CharacterDexScreenState();
}

class _CharacterDexScreenState extends State<CharacterDexScreen> {
  CharacterStageTree? _tree;
  CharacterState? _myState;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Di.characterRepository.getStageTree(),
        Di.characterRepository.getMyState(),
      ]);
      if (!mounted) return;
      setState(() {
        _tree = results[0] as CharacterStageTree;
        _myState = results[1] as CharacterState;
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
          : _tree == null
              ? const SizedBox.shrink()
              : _buildBody(_tree!, _myState!),
    );
  }

  Widget _buildBody(CharacterStageTree tree, CharacterState me) {
    final unlocked = tree.stages.where((s) => s.unlocked).length;
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
                '$unlocked / ${tree.stages.length}',
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
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
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
                myColor: me.color,
                myColorHex: me.colorHex,
                isCurrent: s.stage == tree.currentStage,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DexCard extends StatelessWidget {
  const _DexCard({
    required this.info,
    required this.myColor,
    required this.myColorHex,
    required this.isCurrent,
  });

  final CharacterStageInfo info;
  final CharacterColor myColor;
  final String myColorHex;
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
                      color: myColor,
                      colorHex: myColorHex,
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
            unlocked ? '도달' : 'Lv. ${info.requiredLevel}',
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
