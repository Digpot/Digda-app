import 'package:flutter/material.dart';

import '../../core/ads/ad_service.dart';
import '../../core/di.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/error_message.dart';
import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/animated_mochi_widget.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import '../../features/title/models/title_models.dart';
import '../../features/title/title_catalog.dart';
import '../../features/title/widgets/title_badge.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

/// 모찌 상점 — 카테고리별 아이템(스킨/모자/안경/머리핀/액세서리/잡화) 구매·장착.
///
/// 화면 구성:
///   1) 상단 미리보기 — 선택한 아이템을 가상으로 입혀본 모찌 표시
///   2) 잔액 코인
///   3) 카테고리 탭 — [ShopItemType] 별 섹션
///   4) 아이템 그리드 — 미보유/보유/장착 상태별로 액션 버튼 변형
class CharacterShopScreen extends StatefulWidget {
  const CharacterShopScreen({super.key});

  @override
  State<CharacterShopScreen> createState() => _CharacterShopScreenState();
}

class _CharacterShopScreenState extends State<CharacterShopScreen>
    with SingleTickerProviderStateMixin {
  CharacterShop? _shop;
  CharacterState? _character;
  bool _loading = true;
  bool _changed = false;
  String? _errorMessage;
  String? _pendingAction;

  /// 카테고리별 미리보기 선택 — 장착되지 않았지만 사용자가 탭한 아이템.
  /// `key=ShopItemType.serverKey`, `value=itemKey`. 실제 장착은 별도 API 호출.
  final Map<ShopItemType, String> _previewByType = {};

  /// 칭호 — 계정 단위로 획득한 칭호 목록 + 이 그룹 모찌에 장착된 칭호.
  List<EarnedTitle> _earnedTitles = const [];
  EquippedTitle? _equippedTitle;
  bool _titlePending = false;
  bool _adLoading = false;

  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: ShopItemType.values.length, vsync: this);
    // 탭을 바꾸면 해당 카테고리 섹션만 다시 그린다(고정 높이 TabBarView 대신
    // 선택 섹션을 바깥 스크롤에 인라인으로 펼쳐 아이템이 많아도 다 보이게).
    _tab.addListener(() {
      if (_tab.indexIsChanging && mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
        _errorMessage = '그룹에 들어간 뒤 상점을 이용할 수 있어요.';
      });
      return;
    }
    setState(() {
      if (_shop == null) _loading = true;
      _errorMessage = null;
    });
    try {
      CharacterState? character;
      try {
        character =
            await Di.characterRepository.getMyState(groupRoomId: groupId);
      } catch (_) {
        character = null;
      }
      final shop = await Di.characterRepository.getShop(groupRoomId: groupId);
      // 칭호(획득 목록 + 장착) — 실패해도 상점 표시엔 영향 없음.
      List<EarnedTitle> earnedTitles = _earnedTitles;
      EquippedTitle? equippedTitle = _equippedTitle;
      try {
        await TitleCatalog.ensureLoaded();
        earnedTitles = await Di.titleRepository.list();
        final gstr = Di.activeGroup.groupRoomId;
        if (gstr != null) equippedTitle = await Di.titleRepository.equipped(gstr);
      } catch (_) {/* 칭호 로드 실패 무시 */}
      if (!mounted) return;
      setState(() {
        _character = character;
        _shop = shop;
        _earnedTitles = earnedTitles;
        _equippedTitle = equippedTitle;
        // 미리보기 초기 동기화 — 현재 장착된 아이템을 미리보기로 표시
        if (character != null) {
          for (final eq in character.equippedItems) {
            _previewByType[eq.itemType] = eq.itemKey;
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_shop != null) {
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

  /// 미리보기에 반영되는 외형 — 실제 장착된 아이템 + 사용자가 탭으로 갈아끼운 미리보기.
  MochiAppearance _buildPreviewAppearance() {
    final state = _character;
    if (state == null) return MochiAppearance.coral;
    final base = MochiAppearance.fromState(state);

    // 카테고리별로 _previewByType 에 있으면 그 아이템으로 덮어쓴다.
    final allItems = _shop?.sections
            .expand((s) => s.items)
            .where((it) => it.owned)
            .toList() ??
        const <ShopItem>[];

    String? previewSkinHex = base.skinHex;
    String? previewSkinAsset = base.skinAssetKey;
    String previewBackground = base.backgroundAssetKey;
    final overlays = <EquippedItem>[];
    overlays.addAll(base.overlays);

    for (final entry in _previewByType.entries) {
      final type = entry.key;
      final itemKey = entry.value;
      final item = allItems.firstWhere(
        (it) => it.itemKey == itemKey,
        orElse: () => ShopItem(
          itemKey: itemKey,
          itemType: type,
          itemTypeDisplayName: type.displayName,
          displayName: '',
          cost: 0,
          assetKey: '',
          layerOrder: 0,
          sortOrder: 0,
          isDefault: false,
          owned: false,
          equipped: false,
        ),
      );
      if (item.assetKey.isEmpty) continue;
      if (type == ShopItemType.skin) {
        previewSkinHex = item.accentColor ?? previewSkinHex;
        previewSkinAsset = item.assetKey;
      } else if (type == ShopItemType.background) {
        previewBackground = item.assetKey;
      } else {
        overlays.removeWhere((e) => e.itemType == type);
        overlays.add(item.toEquipped());
      }
    }

    overlays.sort((a, b) => a.layerOrder.compareTo(b.layerOrder));
    return MochiAppearance(
      skinHex: previewSkinHex ?? '#FF6B6B',
      skinAssetKey: previewSkinAsset ?? 'skin/coral',
      backgroundAssetKey: previewBackground,
      overlays: overlays,
    );
  }

  // ── 액션 핸들러 ────────────────────────────────────────────

  void _buy(ShopItem item) {
    if (_pendingAction != null) return;
    showConfirmDialog(
      context,
      title: '${item.displayName} 구매',
      message: '${item.cost} 코인을 사용해 해금할까요?',
      confirmLabel: '구매',
      onConfirm: () => _doBuy(item),
    );
  }

  Future<void> _doBuy(ShopItem item) async {
    if (_pendingAction != null) return;
    final groupId = _activeGroupId;
    if (groupId == null) return;
    setState(() => _pendingAction = 'buy:${item.itemKey}');
    try {
      final updated = await Di.characterRepository.buyItem(
        groupRoomId: groupId,
        itemKey: item.itemKey,
      );
      if (!mounted) return;
      setState(() {
        _shop = updated;
        _changed = true;
      });
      showAppSnackBar(context, '${item.displayName} 을(를) 해금했어요!');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  Future<void> _equip(ShopItem item) async {
    if (_pendingAction != null) return;
    final groupId = _activeGroupId;
    if (groupId == null) return;
    setState(() => _pendingAction = 'equip:${item.itemKey}');
    try {
      final updated = await Di.characterRepository.equipItem(
        groupRoomId: groupId,
        itemKey: item.itemKey,
      );
      if (!mounted) return;
      // 미리보기 / 상점 / 캐릭터 상태 동기화
      setState(() {
        _character = updated;
        _previewByType[item.itemType] = item.itemKey;
        _changed = true;
      });
      try {
        final shop =
            await Di.characterRepository.getShop(groupRoomId: groupId);
        if (!mounted) return;
        setState(() => _shop = shop);
      } catch (_) {/* 시각 동기화 실패는 무시 — pull-to-refresh 로 복구 가능 */}
      showAppSnackBar(context, '${item.displayName} 을(를) 장착했어요!');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  Future<void> _unequipSlot(ShopItemType type) async {
    if (_pendingAction != null) return;
    final groupId = _activeGroupId;
    if (groupId == null) return;
    setState(() => _pendingAction = 'unequip:${type.serverKey}');
    try {
      final updated = await Di.characterRepository.unequipSlot(
        groupRoomId: groupId,
        itemType: type,
      );
      if (!mounted) return;
      setState(() {
        _character = updated;
        // 스킨은 default 로 자동 복귀, 그 외는 미리보기에서 제거
        if (type == ShopItemType.skin) {
          // 서버가 default 스킨을 다시 장착했어야 하지만, 시드 누락 같은
          // 비정상 상황에서 list 가 비어있을 수 있어 방어적으로 처리.
          EquippedItem? defaultSkin;
          for (final e in updated.equippedItems) {
            if (e.itemType == ShopItemType.skin) {
              defaultSkin = e;
              break;
            }
          }
          if (defaultSkin != null) {
            _previewByType[type] = defaultSkin.itemKey;
          } else {
            _previewByType.remove(type);
          }
        } else {
          _previewByType.remove(type);
        }
        _changed = true;
      });
      try {
        final shop =
            await Di.characterRepository.getShop(groupRoomId: groupId);
        if (!mounted) return;
        setState(() => _shop = shop);
      } catch (_) {}
      showAppSnackBar(context, '${type.displayName} 슬롯을 해제했어요.');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  void _onSelectPreview(ShopItem item) {
    setState(() {
      _previewByType[item.itemType] = item.itemKey;
    });
  }

  /// 칭호 장착/해제([code]=null 이면 해제). 그룹 모찌에 표시된다.
  Future<void> _equipTitle(String? code) async {
    if (_titlePending) return;
    final gstr = Di.activeGroup.groupRoomId;
    if (gstr == null) return;
    setState(() => _titlePending = true);
    try {
      final result = await Di.titleRepository.equip(gstr, code);
      if (!mounted) return;
      setState(() {
        _equippedTitle = result;
        _changed = true;
      });
      showAppSnackBar(
        context,
        code == null ? '칭호를 해제했어요.' : '칭호를 장착했어요!',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _titlePending = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          title: const Text(
            '모찌 상점',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppColors.gray900,
            ),
          ),
          centerTitle: false,
          titleSpacing: 0,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _ErrorRetry(message: _errorMessage!, onRetry: _load)
                : _shop == null
                    ? const SizedBox.shrink()
                    : _buildBody(_shop!),
      ),
    );
  }

  Widget _buildBody(CharacterShop shop) {
    final character = _character;
    final stage = character?.stage ?? CharacterStage.bloom;
    final appearance = _buildPreviewAppearance();

    // 하단 패딩에 시스템 제스처/네비 인셋을 더해, 각 탭의 마지막 아이템(하늘 모찌 등)이
    // 화면 아래에 살짝 잘리지 않게 한다.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 48 + bottomInset),
        children: [
          _PreviewCard(appearance: appearance, stage: stage),
          const SizedBox(height: 16),
          _CoinHeader(coin: shop.coin),
          const SizedBox(height: 10),
          _buildAdRewardButton(),
          const SizedBox(height: 16),
          _buildTitleSection(),
          const SizedBox(height: 16),
          TabBar(
            controller: _tab,
            isScrollable: true,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.gray500,
            labelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: ShopItemType.values
                .map((t) => Tab(text: t.displayName))
                .toList(),
          ),
          const SizedBox(height: 12),
          // 선택된 탭의 섹션만 바깥 ListView 에 인라인으로 펼친다 — 고정 높이
          // TabBarView + 중첩 스크롤을 없애 아이템이 많아도(4개+) 끝까지 스크롤된다.
          _buildSection(shop, ShopItemType.values[_tab.index]),
        ],
      ),
    );
  }

  /// 광고 보고 코인 받기 — 보상형 광고 시청 후 서버에 코인 적립을 위임한다.
  Future<void> _watchAdForCoins() async {
    if (_adLoading) return;
    final groupId = _activeGroupId;
    if (groupId == null) return;
    // 하루 한도를 이미 채웠으면 광고를 띄우지 않고 안내만(서버도 막지만 UX 선제 차단).
    final remaining = _shop?.adRewardRemaining;
    if (remaining != null && remaining <= 0) {
      _showAdLimitDialog();
      return;
    }
    setState(() => _adLoading = true);
    try {
      final watched = await AdService.showRewarded();
      if (!watched) {
        if (mounted) setState(() => _adLoading = false);
        return; // 광고 미로드/중도 취소 — 보상 없음
      }
      final reward =
          await Di.characterRepository.claimAdReward(groupRoomId: groupId);
      if (!mounted) return;
      await _load(); // 코인 잔액 갱신
      if (!mounted) return;
      _changed = true;
      setState(() => _adLoading = false);
      final more = reward.dailyRemaining > 0
          ? ' (오늘 ${reward.dailyRemaining}번 더 가능)'
          : '';
      showAppSnackBar(context, '+${reward.coinReward} 코인을 받았어요!$more');
    } catch (e) {
      if (!mounted) return;
      setState(() => _adLoading = false);
      // 하루 한도 초과(429)는 못생긴 오류창 대신 친근한 안내 팝업으로.
      if (e is ApiException && e.code == 'AD_REWARD_LIMIT_EXCEEDED') {
        await _load(); // 남은 횟수 0 으로 동기화 → 버튼도 비활성
        if (!mounted) return;
        _showAdLimitDialog();
        return;
      }
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  /// 하루 광고 보상 한도 소진 안내 — 디그팟 톤의 카드형 팝업(원형 그라데이션 아이콘).
  void _showAdLimitDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFC24B), Color(0xFFFF8A5B)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bedtime_rounded,
                    size: 32, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                '오늘은 여기까지예요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.gray900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '광고 보상은 하루 5번까지 받을 수 있어요.\n내일 다시 코인을 모아보세요 🪙',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppColors.gray700,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdRewardButton() {
    final remaining = _shop?.adRewardRemaining;
    final soldOut = remaining != null && remaining <= 0;

    final String subtitle = soldOut
        ? '내일 다시 받을 수 있어요'
        : (remaining != null
            ? '오늘 $remaining번 더 받을 수 있어요'
            : '짧은 광고 시청하고 코인 적립');

    return GestureDetector(
      onTap: (_adLoading || soldOut) ? null : _watchAdForCoins,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: soldOut
                ? const [Color(0xFFCBD2DA), Color(0xFFAEB6C0)]
                : const [Color(0xFFFFC24B), Color(0xFFFF8A5B)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: soldOut
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFFF8A5B).withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(
                soldOut ? Icons.check_rounded : Icons.play_arrow_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    soldOut ? '오늘 광고 보상을 다 받았어요' : '광고 보고 코인 받기',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                      color: Color(0xE6FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
            if (_adLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(
                soldOut
                    ? Icons.lock_outline_rounded
                    : Icons.chevron_right_rounded,
                size: 22,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }

  /// 칭호 장착 섹션 — 계정에서 획득한 칭호를 그룹 모찌에 끼운다(그룹당 1개).
  Widget _buildTitleSection() {
    final equippedCode = _equippedTitle?.code;
    // 카탈로그에 있는(렌더 가능한) 획득 칭호만.
    final owned = _earnedTitles
        .map((e) => TitleCatalog.defOf(e.code))
        .whereType<TitleDef>()
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                '칭호 장착',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.gray900,
                ),
              ),
              const Spacer(),
              if (equippedCode != null)
                TextButton.icon(
                  onPressed: _titlePending ? null : () => _equipTitle(null),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('해제'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gray700,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (owned.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                '아직 획득한 칭호가 없어요. 지도 정복·기록으로 모아보세요!',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                  color: AppColors.gray400,
                ),
              ),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(top: 8),
                itemCount: owned.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final def = owned[i];
                  final isEquipped = def.code == equippedCode;
                  return GestureDetector(
                    onTap: _titlePending
                        ? null
                        : () => _equipTitle(isEquipped ? null : def.code),
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              TitleBadge(def: def, earned: true, size: 54),
                              if (isEquipped)
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check,
                                        size: 11, color: AppColors.white),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            def.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: isEquipped
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 10.5,
                              color: isEquipped
                                  ? AppColors.primary
                                  : AppColors.gray600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(CharacterShop shop, ShopItemType type) {
    final section = shop.sections.firstWhere(
      (s) => s.itemType == type,
      orElse: () => ShopSection(
        itemType: type,
        itemTypeDisplayName: type.displayName,
        slotOrder: type.index,
        items: const [],
      ),
    );

    if (section.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Text(
          '카테고리에 아이템이 아직 없어요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: AppColors.gray500,
          ),
        ),
      );
    }

    final hasEquipped = section.items.any((it) => it.equipped);
    // 바깥 ListView 의 자식으로 인라인되므로 자체 스크롤(ListView) 을 두면 중첩
    // 스크롤로 화면이 깨진다. 높이를 콘텐츠에 맞추는 Column 으로 펼친다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 스킨/배경은 렌더 필수 슬롯 — 해제 대신 다른 아이템으로만 교체 가능.
        if (hasEquipped &&
            type != ShopItemType.skin &&
            type != ShopItemType.background)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _pendingAction == null
                    ? () => _unequipSlot(type)
                    : null,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text('${type.displayName} 해제'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gray700,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ...section.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ItemTile(
              item: item,
              coin: shop.coin,
              pendingKey: _pendingAction,
              isPreviewing: _previewByType[item.itemType] == item.itemKey,
              onSelect: () => _onSelectPreview(item),
              onBuy: () => _buy(item),
              onEquip: () => _equip(item),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// 부속 위젯
// ────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.appearance, required this.stage});

  final MochiAppearance appearance;
  final CharacterStage stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF4F1),
            Color(0xFFFDFAF6),
            Color(0xFFFEF1F7),
          ],
        ),
        border: Border.all(color: AppColors.gray100, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              left: -28,
              top: -28,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
            Positioned(
              right: -40,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
            const Positioned(
              top: 22,
              right: 26,
              child: Icon(Icons.star_rounded,
                  size: 16, color: Color(0xFFFCD34D)),
            ),
            const Positioned(
              bottom: 28,
              left: 30,
              child: Icon(Icons.auto_awesome,
                  size: 14, color: Color(0xFFF4B6CD)),
            ),
            Center(
              child: AnimatedMochiWidget(
                appearance: appearance,
                stage: stage,
                size: 160,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinHeader extends StatelessWidget {
  const _CoinHeader({required this.coin});
  final int coin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
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
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$coin 코인',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.gray900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.coin,
    required this.pendingKey,
    required this.isPreviewing,
    required this.onSelect,
    required this.onBuy,
    required this.onEquip,
  });

  final ShopItem item;
  final int coin;
  final String? pendingKey;
  final bool isPreviewing;
  final VoidCallback onSelect;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final pendingBuy = pendingKey == 'buy:${item.itemKey}';
    final pendingEquip = pendingKey == 'equip:${item.itemKey}';
    final disabledByOther =
        pendingKey != null && !pendingBuy && !pendingEquip;

    final Border tileBorder = item.equipped
        ? Border.all(color: AppColors.primary, width: 2)
        : isPreviewing
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.45), width: 1.5)
            : Border.all(color: AppColors.gray100);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.owned ? onSelect : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: tileBorder,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ItemThumb(item: item),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.gray900,
                            ),
                          ),
                        ),
                        if (item.equipped) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '장착 중',
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
                    // 가격은 우측 구매 버튼(코인 필)에만 표시 — 여기 중복 표기하지
                    // 않아 정보가 한 줄씩 깔끔하게 정렬된다.
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.description!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 11.5,
                          color: AppColors.gray500,
                        ),
                      ),
                    ],
                    if (item.owned && !item.equipped) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.isDefault ? '기본 아이템' : '보유 중',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                item: item,
                coin: coin,
                pendingBuy: pendingBuy,
                pendingEquip: pendingEquip,
                disabled: disabledByOther,
                onBuy: onBuy,
                onEquip: onEquip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemThumb extends StatelessWidget {
  const _ItemThumb({required this.item});
  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    // 모든 카테고리에 동일하게 미니 모찌 미리보기를 제공한다.
    // - 스킨: 본인이 적용된 모찌 (기본 배경 하늘 톤/본체 색 적용)
    // - 배경: 해당 배경 씬 + 기본 코랄 모찌
    // - 그 외 카테고리: 기본 코랄 모찌 + 해당 아이템 1개만 overlay
    // 이렇게 통일하면 사용자가 "이 아이템 차면 어떻게 보이지?" 를 한 눈에 가늠 가능.
    final MochiAppearance appearance = switch (item.itemType) {
      ShopItemType.skin => MochiAppearance(
          skinHex: item.accentColor ?? '#FF6B6B',
          skinAssetKey: item.assetKey,
          overlays: const [],
        ),
      ShopItemType.background => MochiAppearance(
          skinHex: '#FF6B6B',
          skinAssetKey: 'skin/coral',
          backgroundAssetKey: item.assetKey,
          overlays: const [],
        ),
      _ => MochiAppearance(
          skinHex: '#FF6B6B',
          skinAssetKey: 'skin/coral',
          overlays: [item.toEquipped()],
        ),
    };
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: MochiCharacterView(
          appearance: appearance,
          stage: CharacterStage.bloom,
          size: 56,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.item,
    required this.coin,
    required this.pendingBuy,
    required this.pendingEquip,
    required this.disabled,
    required this.onBuy,
    required this.onEquip,
  });

  final ShopItem item;
  final int coin;
  final bool pendingBuy;
  final bool pendingEquip;
  final bool disabled;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    if (item.owned) {
      if (item.equipped) {
        return _disabledLabel('장착 중');
      }
      return _filledButton(
        label: pendingEquip ? '장착 중...' : '장착',
        onPressed: (pendingEquip || disabled) ? null : onEquip,
      );
    }
    // 미보유 — 가격이 곧 버튼. 빨간 사각 버튼에 숫자만 있던 걸 코인 아이콘이
    // 함께 있는 골드 필로 바꿔 "코인으로 산다" 는 게 한 눈에 읽히게 한다.
    final canAfford = coin >= item.cost;
    return _pricePill(
      cost: item.cost,
      enabled: canAfford && !pendingBuy && !disabled,
      pending: pendingBuy,
      onTap: (!canAfford || pendingBuy || disabled) ? null : onBuy,
    );
  }

  /// 골드 코인 가격 필 — [enabled] 면 골드 그라디언트, 코인 부족이면 회색.
  Widget _pricePill({
    required int cost,
    required bool enabled,
    required bool pending,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFD166), Color(0xFFF5A623)],
                )
              : null,
          color: enabled ? null : AppColors.gray200,
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pending)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            else
              Container(
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enabled
                      ? Colors.white.withValues(alpha: 0.30)
                      : AppColors.gray300,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  'C',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: enabled ? Colors.white : AppColors.gray500,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              '$cost',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: enabled ? Colors.white : AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filledButton({
    required String label,
    required VoidCallback? onPressed,
    Color? background,
  }) {
    final bg = background ?? AppColors.primary;
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _disabledLabel(String label) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.gray500,
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
