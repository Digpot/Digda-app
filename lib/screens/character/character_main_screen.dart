import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../core/share/share_service.dart';
import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/animated_mochi_widget.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import '../../features/character/widgets/mochi_diko_stage.dart';
import '../../features/title/models/title_models.dart';
import '../../features/title/title_catalog.dart';
import '../../features/title/widgets/title_badge.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/notification_bell_icon.dart';
import 'character_diko_intro_screen.dart';
import 'character_evolution_screen.dart';
import 'character_levelup_screen.dart';
import 'character_master_game_screen.dart';
import 'character_stage_tree_screen.dart';
import 'character_shop_screen.dart';
import 'character_dex_screen.dart';
import 'character_intro_screen.dart';
import 'games/group_game_list_screen.dart';
import 'quiz/character_quiz_play_screen.dart';
import 'quiz/character_quiz_list_screen.dart';
import '../exhibit/nickname_exhibit_screen.dart';

/// 모찌 키우기 탭의 메인 화면.
/// - 캐릭터 시각화 + 레벨/EXP 진행도 + 코인
/// - 진화 트리·아이템 상점 진입
/// - 첫 진입은 서버가 캐릭터를 lazy 생성
class CharacterMainScreen extends StatefulWidget {
  const CharacterMainScreen({super.key});

  @override
  State<CharacterMainScreen> createState() => _CharacterMainScreenState();
}

class _CharacterMainScreenState extends State<CharacterMainScreen> {
  CharacterState? _state;
  bool _loading = true;
  String? _errorMessage;
  bool _hasLoadedOnce = false;
  // 풀 수 있는 남은 퀴즈 수 — '퀴즈 풀기' 버튼 위 말풍선용 (best-effort, null=미조회).
  int? _remainingQuiz;
  // 역대 별명 전시관 접근 허용 여부 — 어드민이 허용한 사용자만 버튼 노출 (best-effort).
  bool _exhibitAllowed = false;
  // 이 그룹 모찌에 장착된 칭호 (best-effort, null=미장착/미조회).
  EquippedTitle? _equippedTitle;
  bool _petInProgress = false;
  bool _savingImage = false;
  final _mochiCtrl = MochiAnimationController();
  // 꾸민 모찌를 PNG 로 내보내기 위한 오프스크린 캡처 경계.
  final GlobalKey _captureKey = GlobalKey(); // 정보 카드(모찌+레벨+디그팟)
  final GlobalKey _cleanCaptureKey = GlobalKey(); // 배경+모찌만 (글자 없음)

  // 사진 저장 해금 레벨 — 레벨 달성 시 1개씩 풀린다. 마지막(배경+모찌)이 가장 높은 레벨.
  static const int _kInfoCardLevel = 3;
  static const int _kCleanLevel = 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIntro());
  }

  Future<void> _maybeShowIntro() async {
    try {
      final seen = await CharacterIntroScreen.isAlreadySeen();
      if (!mounted) return;
      if (!seen) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const CharacterIntroScreen(),
            fullscreenDialog: true,
          ),
        );
      }
    } catch (_) {
      // secure storage 오류 시 인트로를 건너뛰고 메인 로드 진행
    }
    if (!mounted) return;
    _load();
  }

  /// 활성 그룹의 ID. 미선택이면 null — 화면이 빈 안내로 전환.
  int? get _activeGroupId {
    final raw = Di.activeGroup.groupRoomId;
    return raw == null ? null : int.tryParse(raw);
  }

  // silent: 이미 데이터가 있는 경우 스피너 없이 백그라운드 갱신
  Future<void> _load({bool silent = false}) async {
    final groupId = _activeGroupId;
    if (groupId == null) {
      setState(() {
        _loading = false;
        _errorMessage = '그룹에 들어간 뒤 모찌를 만날 수 있어요.';
      });
      return;
    }
    setState(() {
      if (!silent || _state == null) _loading = true;
      _errorMessage = null;
    });
    try {
      final state = await Di.characterRepository.getMyState(groupRoomId: groupId);
      if (!mounted) return;
      final isFirst = !_hasLoadedOnce;
      setState(() {
        _state = state;
        _loading = false;
        _hasLoadedOnce = true;
      });
      _loadRemainingQuiz(groupId); // 버튼 위 말풍선용 카운트 (best-effort, 비동기)
      _checkExhibitAccess(); // 전시관 버튼 노출 여부 (best-effort, 비동기)
      _loadEquippedTitle(groupId); // 장착 칭호 (best-effort, 비동기)
      _claimCharacterTitles(groupId, state); // 모찌 칭호 적재 (best-effort)
      if (isFirst) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _mochiCtrl.triggerHappy();
        });
      }
      // 디코가 이미 풀려있지만 컷씬을 본 적 없는 경우 (예: 이 기능 배포 전부터 Lv.10+ 이던
      // 기존 그룹) 한 번만 등장 컷씬을 보여준다. markSeen 은 그룹 단위.
      if (isFirst && state.dikoUnlocked) {
        final seen = await CharacterDikoIntroScreen.isAlreadySeen(groupId);
        if (!seen && mounted) {
          await CharacterDikoIntroScreen.show(
            context,
            character: state,
            groupId: groupId,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (_state != null) {
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

  /// 모찌 칭호 적재 — 레벨 마일스톤(서버 카탈로그 기준). 멱등·best-effort.
  Future<void> _claimCharacterTitles(int groupId, CharacterState state) async {
    try {
      await TitleCatalog.ensureLoaded();
      final claims = <TitleClaim>[
        for (final m in TitleCatalog.mochiMilestones)
          if (state.level >= m.level)
            TitleClaim(code: m.code, groupRoomId: groupId),
      ];
      if (claims.isEmpty) return;
      await Di.titleRepository.claim(claims);
    } catch (_) {/* 칭호 적재 실패는 화면에 영향 없음 */}
  }

  /// 이 그룹 모찌에 장착된 칭호를 best-effort 로 받아 모찌 아래 칩에 표시한다.
  Future<void> _loadEquippedTitle(int groupId) async {
    try {
      // 칩 렌더가 카탈로그(defOf)에 의존하므로 먼저 카탈로그를 보장한 뒤 setState.
      await TitleCatalog.ensureLoaded();
      final eq = await Di.titleRepository.equipped(groupId.toString());
      if (mounted) setState(() => _equippedTitle = eq);
    } catch (_) {/* 장착 칭호 조회 실패는 화면에 영향 없음 */}
  }

  /// 풀 수 있는 남은 퀴즈 수를 best-effort 로 받아 '퀴즈 풀기' 버튼 위 말풍선에 쓴다.
  /// 전용 카운트 API 가 없어 random 픽 응답의 remainingCount 를 재사용한다(읽기 전용).
  Future<void> _loadRemainingQuiz(int groupId) async {
    int count;
    try {
      final q = await Di.characterRepository.pickRandomQuiz(groupId);
      count = q.remainingCount ?? 0;
    } catch (_) {
      count = 0; // QUIZ_NO_AVAILABLE 등 — 지금 풀 수 있는 퀴즈 없음
    }
    if (!mounted) return;
    setState(() => _remainingQuiz = count);
  }

  /// 역대 별명 전시관 접근 권한을 best-effort 로 조회해 버튼 노출을 결정한다.
  /// 실패 시(네트워크/미허용) 버튼은 노출하지 않는다.
  Future<void> _checkExhibitAccess() async {
    bool allowed;
    try {
      allowed = await Di.exhibitRepository.checkAccess();
    } catch (_) {
      allowed = false;
    }
    if (!mounted || allowed == _exhibitAllowed) return;
    setState(() => _exhibitAllowed = allowed);
  }

  Future<void> _openExhibit() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const NicknameExhibitScreen()),
    );
  }

  Future<void> _openGames() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const GroupGameListScreen()),
    );
  }

  void _openInfoSheet() {
    if (_state == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CharacterInfoSheet(state: _state!),
    );
  }

  Future<void> _openStageTree() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CharacterStageTreeScreen()),
    );
    _load(silent: true);
  }

  Future<void> _openShop() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CharacterShopScreen()),
    );
    if (changed == true) _load(silent: true);
  }

  Future<void> _openDex() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CharacterDexScreen()),
    );
    _load(silent: true);
  }

  Future<void> _openQuizPlay() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CharacterQuizPlayScreen()),
    );
    // pushReplacement 가 push future 를 즉시 완료시켜, 결과 화면이 열린 채로 여기 도달할 수 있음 — 애니메이션은 결과 화면이 담당.
    _load(silent: true);
  }

  Future<void> _openQuizList() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CharacterQuizListScreen()),
    );
  }

  void _handlePet() {
    if (_petInProgress) return;
    final groupId = _activeGroupId;
    if (groupId == null) return;
    _petInProgress = true;
    Di.characterRepository
        .addExp(groupRoomId: groupId, amount: 5, source: 'pet')
        .then((result) async {
          _petInProgress = false;
          if (!mounted) return;
          setState(() => _state = result.character);
          if (result.stageChanged) {
            _mochiCtrl.triggerProud();
            await CharacterEvolutionScreen.show(
              context,
              character: result.character,
              stageBefore: result.stageBefore,
            );
          } else if (result.levelGained > 0) {
            _mochiCtrl.triggerHappy();
            await CharacterLevelUpScreen.show(
              context,
              character: result.character,
              levelGained: result.levelGained,
            );
          }
          // 진화/레벨업 컷씬을 먼저 보여준 뒤 디코 등장. 동시 발생해도 사용자가 둘 다 본다.
          // markSeen 까지 묶어 처리해 다음 _load 에서 중복 트리거되지 않게 한다.
          if (result.dikoJustUnlocked && mounted) {
            await CharacterDikoIntroScreen.show(
              context,
              character: result.character,
              groupId: groupId,
            );
          }
        })
        .catchError((_) {
          _petInProgress = false;
        });
  }

  /// 사진 저장 옵션 시트 — 해금 상태(레벨)에 따라 2종 중 선택.
  void _openDownloadSheet() {
    final s = _state;
    if (s == null || _savingImage) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DownloadSheet(
        level: s.level,
        infoCardLevel: _kInfoCardLevel,
        cleanLevel: _kCleanLevel,
        onPickInfo: () {
          Navigator.of(context).pop();
          _captureAndShare(_captureKey, '디그팟에서 키운 내 모찌 🐹');
        },
        onPickClean: () {
          Navigator.of(context).pop();
          _captureAndShare(_cleanCaptureKey, '내 모찌 🐹');
        },
      ),
    );
  }

  /// [key] 가 가리키는 오프스크린 카드를 PNG 로 캡처해 저장/공유 시트를 띄운다.
  Future<void> _captureAndShare(GlobalKey key, String text) async {
    if (_savingImage || _state == null) return;
    setState(() => _savingImage = true);
    try {
      // 다음 프레임에 캡처 위젯이 확실히 그려지도록 한 프레임 양보.
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('capture boundary not ready');
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('failed to encode png');
      final file = File(
        '${Directory.systemTemp.path}/mochi_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      await ShareService.shareFiles(
        context,
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, '이미지를 저장하지 못했어요.', isError: true);
    } finally {
      if (mounted) setState(() => _savingImage = false);
    }
  }

  Future<void> _openMasterGame() async {
    final state = _state;
    // 레벨 20(canChallengeMaster) 부터 응시 가능 — 마스터 진화 전에는 "진화 시험".
    if (state == null || !state.canChallengeMaster) return;
    final session = await CharacterMasterGameScreen.open(
      context,
      appearance: MochiAppearance.fromState(state),
      stage: state.stage,
      initialCoin: state.coin,
    );
    if (!mounted) return;
    final reward = session?.reward;
    final latest = reward?.character ?? session?.latestCharacter;
    if (latest != null) {
      setState(() => _state = latest);
    }
    // 이번 도전(훌륭 이상)으로 마스터 진화가 일어났다면 진화 컷씬을 띄운다.
    if (reward?.evolvedToMaster == true && latest != null && mounted) {
      _mochiCtrl.triggerProud();
      await CharacterEvolutionScreen.show(
        context,
        character: latest,
        stageBefore: CharacterStage.glow,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
          // 화면 밖에 모찌 캡처 카드들을 그려둔다 — 레이아웃/페인트는 되지만 사용자에겐
          // 보이지 않는 위치. _captureAndShare 가 해당 경계를 toImage 로 캡처한다.
          if (_state != null) ...[
            Positioned(
              left: -4000,
              top: 0,
              child: RepaintBoundary(
                key: _captureKey,
                child: _MochiCaptureCard(
                  state: _state!,
                  titleDef: TitleCatalog.defOf(_equippedTitle?.code ?? ''),
                ),
              ),
            ),
            // 배경 + 모찌만 (글자 없음)
            Positioned(
              left: -4000,
              top: 600,
              child: RepaintBoundary(
                key: _cleanCaptureKey,
                child: _MochiCleanCard(state: _state!),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            const Text(
              '모찌 키우기',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.gray900,
              ),
            ),
            const Spacer(),
            // 꾸민 모찌 이미지 저장/공유
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _state == null || _savingImage ? null : _openDownloadSheet,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _savingImage
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gray700,
                        ),
                      )
                    : const Icon(Icons.ios_share,
                        size: 22, color: AppColors.gray700),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openInfoSheet,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.info_outline,
                    size: 24, color: AppColors.gray700),
              ),
            ),
            const SizedBox(width: 12),
            const NotificationBellIcon(),
            const SizedBox(width: 16),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pushNamed('/my-page'),
              child: const Icon(
                Icons.settings_outlined,
                size: 22,
                color: AppColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 모찌 아래 장착 칭호 칩 — 탭하면 상점(칭호 장착)으로. 미장착이면 숨김.
  Widget _buildEquippedTitleChip() {
    final code = _equippedTitle?.code;
    if (code == null) return const SizedBox.shrink();
    final def = TitleCatalog.defOf(code);
    if (def == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: GestureDetector(
          onTap: _openShopForTitle,
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 5, 14, 5),
            decoration: BoxDecoration(
              color: def.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: def.accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TitleBadge(def: def, earned: true, size: 26),
                const SizedBox(width: 8),
                Text(
                  def.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: def.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openShopForTitle() async {
    await Navigator.of(context).pushNamed('/character-shop');
    if (!mounted) return;
    final gid = _activeGroupId;
    if (gid != null) _loadEquippedTitle(gid);
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _ErrorRetry(message: _errorMessage!, onRetry: _load);
    }
    final s = _state!;
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          const SizedBox(height: 12),
          MochiHomeScene(
            state: s,
            mochiController: _mochiCtrl,
            onPet: _handlePet,
          ),
          const SizedBox(height: 6),
          Text(
            s.dikoUnlocked
                ? '모찌와 디코를 함께 만나보세요'
                : '탭하거나 꾹 눌러서 쓰다듬어 봐요',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: AppColors.gray400,
            ),
          ),
          _buildEquippedTitleChip(),
          const SizedBox(height: 20),
          _LevelStageRow(state: s),
          const SizedBox(height: 12),
          _ExpProgress(state: s),
          const SizedBox(height: 28),
          _CoinChip(coin: s.coin),
          const SizedBox(height: 24),
          if (s.canChallengeMaster) ...[
            _MasterGameCta(
              onTap: _openMasterGame,
              // 마스터 진화 전(레벨 20·GLOW)에는 "진화 시험"으로 안내.
              isEvolutionExam: s.stage != CharacterStage.master,
            ),
            const SizedBox(height: 12),
          ],
          // 풀 수 있는 퀴즈가 남아 있으면 버튼 위에 알림 말풍선으로 안내.
          if (_remainingQuiz != null && _remainingQuiz! > 0)
            _QuizCountBubble(count: _remainingQuiz!),
          // 핵심 CTA — 퀴즈 풀어서 EXP/코인 얻기
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _openQuizPlay,
              icon: const Icon(Icons.psychology_outlined, size: 22),
              label: const Text(
                '퀴즈 풀기',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 부가 기능 — 2x2 그리드
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.6,
            children: [
              _MiniTile(
                icon: Icons.edit_note,
                label: '퀴즈 목록',
                onTap: _openQuizList,
              ),
              _MiniTile(
                icon: Icons.trending_up,
                label: '진화 트리',
                onTap: _openStageTree,
              ),
              _MiniTile(
                icon: Icons.collections_bookmark_outlined,
                label: '도감',
                onTap: _openDex,
              ),
              _MiniTile(
                icon: Icons.storefront_outlined,
                label: '아이템 상점',
                onTap: _openShop,
              ),
            ],
          ),
          // 그룹원들이 한 폰으로 즐기는 미니게임 목록 진입 버튼.
          const SizedBox(height: 12),
          _GameCta(onTap: _openGames),
          // 어드민이 허용한 사용자만 노출되는 역대 별명 전시관 진입 버튼.
          if (_exhibitAllowed) ...[
            const SizedBox(height: 12),
            _ExhibitCta(onTap: _openExhibit),
          ],
        ],
      ),
    );
  }
}

/// 모찌 화면 하단의 '게임하기' 진입 버튼 — 그룹원 미니게임 목록으로.
class _GameCta extends StatelessWidget {
  const _GameCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF45B7D1), Color(0xFF34D399)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF45B7D1).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            children: [
              Text('🎮', style: TextStyle(fontSize: 22)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '게임하기',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// 모찌 화면 하단의 '디그다 역대 별명 전시관' 진입 버튼.
class _ExhibitCta extends StatelessWidget {
  const _ExhibitCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B7CF6), Color(0xFFB794F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B7CF6).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('🏛️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '디그다 역대 별명 전시관',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// '퀴즈 풀기' 버튼 바로 위에 뜨는 알림 말풍선 — 지금 풀 수 있는 퀴즈 수를 안내한다.
/// 아래쪽 꼬리가 버튼을 가리킨다.
class _QuizCountBubble extends StatelessWidget {
  const _QuizCountBubble({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🧠', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                '지금 풀 수 있는 퀴즈 $count개!',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // 말풍선 꼬리 — 회전한 정사각형을 버블 하단에 살짝 겹쳐 아래(버튼)를 가리킨다.
        Transform.translate(
          offset: const Offset(0, -3),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: 12, height: 12, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MasterGameCta extends StatelessWidget {
  const _MasterGameCta({required this.onTap, this.isEvolutionExam = false});
  final VoidCallback onTap;

  /// true 면 마스터 진화 전 "진화 시험" 안내, false 면 마스터 후 코인 파밍 안내.
  final bool isEvolutionExam;

  @override
  Widget build(BuildContext context) {
    final title = isEvolutionExam ? '마스터 진화 시험' : '챔피언 챌린지';
    final subtitle = isEvolutionExam
        ? '입장료 20코인 · 훌륭 이상이면 마스터로 진화!'
        : '입장료 20코인 · 점수 따라 보상';
    final emoji = isEvolutionExam ? '✨' : '🏆';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFB347), Color(0xFFFF8A65)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB347).withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gray50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.gray900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelStageRow extends StatelessWidget {
  const _LevelStageRow({required this.state});
  final CharacterState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Lv. ${state.level}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          state.stageDisplayName,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.gray900,
          ),
        ),
      ],
    );
  }
}

class _ExpProgress extends StatelessWidget {
  const _ExpProgress({required this.state});
  final CharacterState state;

  @override
  Widget build(BuildContext context) {
    // 레벨 20 도달했지만 아직 진화 시험을 통과하지 못한 상태 — 트로피 대신 시험 안내.
    if (state.maxLevelReached && state.stage != CharacterStage.master) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFCD34D), width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✨', style: TextStyle(fontSize: 15)),
              SizedBox(width: 6),
              Text(
                'Lv.20 · 진화 시험에 도전하세요',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.gray900,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final atMax = state.maxLevelReached;
    if (atMax) {
      // 마스터 — 추가 EXP 불가. 진행도 바 대신 트로피 배지로 마무리.
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFB347)],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB347).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🏆', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                '마스터 도달!',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: state.progress,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'EXP ${state.exp} / ${state.expForNextLevel}',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.gray700,
          ),
        ),
      ],
    );
  }
}

class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.coin});
  final int coin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E2),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFCD34D), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFFFCD34D),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                'C',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$coin 코인',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.gray900,
              ),
            ),
          ],
        ),
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

class _CharacterInfoSheet extends StatelessWidget {
  const _CharacterInfoSheet({required this.state});
  final CharacterState state;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bottomSheetBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '모찌 키우기란?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '디그팟 안에서 함께 키우는 작은 마스코트, 모찌예요.\n'
              '경험치를 모아 레벨업하면 진화 단계가 바뀌고,\n'
              '코인을 모아 상점에서 모자·안경·스킨 같은 아이템을 해금하고\n원하는 조합으로 모찌를 꾸며줄 수 있어요.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.6,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 20),
            const _InfoRow(
              icon: Icons.bolt_outlined,
              title: '경험치',
              body: '활동에 참여하면 EXP가 쌓이고, 임계치에 닿으면 자동으로 레벨업해요.',
            ),
            const _InfoRow(
              icon: Icons.auto_awesome,
              title: '진화',
              body: '레벨이 3·6·10·15·20에 도달할 때마다 모찌가 새로운 모습으로 자라요. Lv.20 은 마스터!',
            ),
            const _InfoRow(
              icon: Icons.storefront_outlined,
              title: '꾸미기',
              body: '코인을 모아 스킨·모자·안경 같은 아이템을 해금하고 언제든 갈아입혀 줄 수 있어요.',
            ),
            const SizedBox(height: 24),
            // 모찌 시스템 첫 진입 때 보여주는 온보딩(소개)을 언제든 다시 볼 수 있는 버튼.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // 시트의 context 가 pop 후 defunct 가 되므로 Navigator 를 미리 잡아둔다.
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push<void>(
                    MaterialPageRoute(
                      builder: (_) => const CharacterIntroScreen(),
                      fullscreenDialog: true,
                    ),
                  );
                },
                icon: const Icon(Icons.auto_stories_outlined,
                    size: 18, color: AppColors.primary),
                label: const Text(
                  '모찌 소개 다시 보기',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 모찌 이미지 내보내기용 정적 카드. 화면 밖에서 RepaintBoundary 로 캡처된다.
/// 흰 배경 + 꾸민 모찌(full) + 단계/레벨 + 장착 칭호 + 디그팟 워터마크.
class _MochiCaptureCard extends StatelessWidget {
  const _MochiCaptureCard({required this.state, this.titleDef});
  final CharacterState state;

  /// 장착 칭호(없으면 null) — 정보 카드에 함께 박제한다.
  final TitleDef? titleDef;

  @override
  Widget build(BuildContext context) {
    final def = titleDef;
    return Material(
      color: Colors.white,
      child: Container(
        width: 360,
        height: 440,
        decoration: const BoxDecoration(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MochiCharacterView(
              appearance: MochiAppearance.fromState(state),
              stage: state.stage,
              size: 224,
            ),
            const SizedBox(height: 18),
            Text(
              state.stageDisplayName,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lv. ${state.level}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
            if (def != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(7, 5, 14, 5),
                decoration: BoxDecoration(
                  color: def.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: def.accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TitleBadge(def: def, earned: true, size: 26),
                    const SizedBox(width: 8),
                    Text(
                      def.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: def.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            const Text(
              '디그팟',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 1.0,
                color: AppColors.gray400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 배경 + 모찌만 — 글자 없이 꽉 채운 내보내기용. 장착된 배경 씬 위에 꾸민 모찌를
/// 그대로 캡처한다 (squircle 바깥은 스킨 톤으로 채워 모서리 빈틈을 없앤다).
class _MochiCleanCard extends StatelessWidget {
  const _MochiCleanCard({required this.state});
  final CharacterState state;

  @override
  Widget build(BuildContext context) {
    final appearance = MochiAppearance.fromState(state);
    return Container(
      width: 360,
      height: 360,
      color: _hexToColor(appearance.skinHex),
      alignment: Alignment.center,
      child: MochiCharacterView(
        appearance: appearance,
        stage: state.stage,
        size: 360,
      ),
    );
  }
}

Color _hexToColor(String hex) {
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16) ?? 0xFFFF6B6B;
  return Color(v);
}

/// 모찌 사진 저장 옵션 시트 — 2종(정보 카드 / 배경+모찌). 레벨 미달 항목은 잠금 표시.
class _DownloadSheet extends StatelessWidget {
  const _DownloadSheet({
    required this.level,
    required this.infoCardLevel,
    required this.cleanLevel,
    required this.onPickInfo,
    required this.onPickClean,
  });

  final int level;
  final int infoCardLevel;
  final int cleanLevel;
  final VoidCallback onPickInfo;
  final VoidCallback onPickClean;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bottomSheetBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '모찌 사진 저장',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.gray900,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '레벨을 올리면 저장할 수 있는 사진이 늘어나요',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: AppColors.gray500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _DownloadOption(
              icon: Icons.badge_outlined,
              title: '정보 카드',
              subtitle: '모찌 + 레벨 + 칭호',
              unlocked: level >= infoCardLevel,
              requiredLevel: infoCardLevel,
              onTap: onPickInfo,
            ),
            const SizedBox(height: 10),
            _DownloadOption(
              icon: Icons.wallpaper_rounded,
              title: '배경 + 모찌',
              subtitle: '글자 없이 깔끔하게',
              unlocked: level >= cleanLevel,
              requiredLevel: cleanLevel,
              onTap: onPickClean,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DownloadOption extends StatelessWidget {
  const _DownloadOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    required this.requiredLevel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool unlocked;
  final int requiredLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: unlocked ? AppColors.gray50 : AppColors.gray100,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: unlocked ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unlocked
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.gray200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  unlocked ? icon : Icons.lock_outline,
                  size: 20,
                  color: unlocked ? AppColors.primary : AppColors.gray500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: unlocked ? AppColors.gray900 : AppColors.gray500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unlocked ? subtitle : 'Lv.$requiredLevel 달성 시 해금',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: unlocked ? AppColors.gray500 : AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                unlocked ? Icons.download_rounded : Icons.lock_outline,
                size: 20,
                color: unlocked ? AppColors.primary : AppColors.gray400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    height: 1.55,
                    color: AppColors.gray700,
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
