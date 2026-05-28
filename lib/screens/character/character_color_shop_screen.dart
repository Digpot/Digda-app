import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/character/models/character_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

/// 색상 상점.
/// - 보유 색상: '적용' 버튼 (현재 색은 비활성)
/// - 미보유 색상: 'N 코인' 버튼 (잔액 부족이면 비활성·금액 표시 유지)
class CharacterColorShopScreen extends StatefulWidget {
  const CharacterColorShopScreen({super.key});

  @override
  State<CharacterColorShopScreen> createState() =>
      _CharacterColorShopScreenState();
}

class _CharacterColorShopScreenState extends State<CharacterColorShopScreen> {
  CharacterColorShop? _shop;
  bool _loading = true;
  bool _changed = false;
  String? _errorMessage;
  String? _pendingAction; // 진행 중 행동 키 (이중 탭 방지)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final shop = await Di.characterRepository.getColorShop();
      if (!mounted) return;
      setState(() {
        _shop = shop;
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

  void _buy(CharacterColorInfo item) {
    if (_pendingAction != null) return;
    showConfirmDialog(
      context,
      title: '${item.displayName} 구매',
      message: '${item.cost} 코인을 사용해 해금할까요?',
      confirmLabel: '구매',
      onConfirm: () => _doBuy(item),
    );
  }

  Future<void> _doBuy(CharacterColorInfo item) async {
    setState(() => _pendingAction = 'buy:${item.color.name}');
    try {
      final updated = await Di.characterRepository.buyColor(item.color);
      if (!mounted) return;
      setState(() {
        _shop = updated;
        _changed = true;
      });
      showAppSnackBar(context, '${item.displayName} 색을 해금했어요!');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  Future<void> _apply(CharacterColorInfo item) async {
    if (_pendingAction != null) return;
    setState(() => _pendingAction = 'apply:${item.color.name}');
    try {
      await Di.characterRepository.applyColor(item.color);
      if (!mounted) return;
      final shop = await Di.characterRepository.getColorShop();
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _changed = true;
      });
      showAppSnackBar(context, '${item.displayName} 색으로 변경됐어요!');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 시스템 백 제스처/버튼 모두 변경 여부를 호출자에게 전달해야 메인 화면이 최신 상태로
    // 재조회하므로 PopScope 로 가로채 명시적으로 pop(_changed) 한다.
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
            '색상 상점',
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
                : _shop == null
                    ? const SizedBox.shrink()
                    : _buildBody(_shop!),
      ),
    );
  }

  Widget _buildBody(CharacterColorShop shop) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          _CoinHeader(coin: shop.coin),
          const SizedBox(height: 16),
          ...shop.items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ColorTile(
                  item: it,
                  coin: shop.coin,
                  pendingKey: _pendingAction,
                  onBuy: () => _buy(it),
                  onApply: () => _apply(it),
                ),
              )),
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

class _ColorTile extends StatelessWidget {
  const _ColorTile({
    required this.item,
    required this.coin,
    required this.pendingKey,
    required this.onBuy,
    required this.onApply,
  });

  final CharacterColorInfo item;
  final int coin;
  final String? pendingKey;
  final VoidCallback onBuy;
  final VoidCallback onApply;

  Color _parseHex(String s) {
    final clean = s.replaceAll('#', '');
    final v = int.tryParse(clean, radix: 16) ?? 0xFF6B6B;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final hexColor = _parseHex(item.hex);
    final pendingBuy = pendingKey == 'buy:${item.color.name}';
    final pendingApply = pendingKey == 'apply:${item.color.name}';
    final disabledByOtherAction = pendingKey != null && !pendingBuy && !pendingApply;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
        border: item.isCurrent
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: hexColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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
                      item.displayName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.gray900,
                      ),
                    ),
                    if (item.isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '적용 중',
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
                  item.owned
                      ? (item.isDefault ? '기본 색상' : '보유 중')
                      : '구매 시 ${item.cost} 코인',
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
          const SizedBox(width: 8),
          _ActionButton(
            item: item,
            coin: coin,
            pendingBuy: pendingBuy,
            pendingApply: pendingApply,
            disabled: disabledByOtherAction,
            onBuy: onBuy,
            onApply: onApply,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.item,
    required this.coin,
    required this.pendingBuy,
    required this.pendingApply,
    required this.disabled,
    required this.onBuy,
    required this.onApply,
  });

  final CharacterColorInfo item;
  final int coin;
  final bool pendingBuy;
  final bool pendingApply;
  final bool disabled;
  final VoidCallback onBuy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    if (item.owned) {
      // 이미 적용 중이면 비활성 라벨
      if (item.isCurrent) {
        return _disabledLabel('적용 중');
      }
      return _filledButton(
        label: pendingApply ? '적용 중...' : '적용',
        onPressed: (pendingApply || disabled) ? null : onApply,
      );
    }
    final canAfford = coin >= item.cost;
    return _filledButton(
      label: pendingBuy ? '구매 중...' : '${item.cost}',
      onPressed: (!canAfford || pendingBuy || disabled) ? null : onBuy,
      background:
          canAfford ? AppColors.primary : AppColors.gray300,
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
