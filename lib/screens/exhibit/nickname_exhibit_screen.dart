import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/exhibit/models/exhibit_models.dart';
import '../../theme/colors.dart';

/// 디그다 역대 별명 전시관.
/// 접근 권한이 허용된 사용자만 모찌 화면 하단 버튼으로 진입한다.
/// 별명 카드를 한 줄 3개 그리드로 보여주고, 탭하면 플립되어 별명의 역사를 보여준다.
class NicknameExhibitScreen extends StatefulWidget {
  const NicknameExhibitScreen({super.key});

  @override
  State<NicknameExhibitScreen> createState() => _NicknameExhibitScreenState();
}

class _NicknameExhibitScreenState extends State<NicknameExhibitScreen> {
  List<NicknameExhibit>? _items;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final items = await Di.exhibitRepository.list();
      if (!mounted) return;
      setState(() {
        _items = items;
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 20, color: AppColors.gray700),
            ),
            const Text(
              '역대 별명 전시관',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.gray900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _ErrorRetry(message: _errorMessage!, onRetry: _load);
    }
    final items = _items ?? const [];
    if (items.isEmpty) {
      return const _EmptyState();
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) =>
            _FlipCard(key: ValueKey(items[i].id), exhibit: items[i]),
      ),
    );
  }
}

/// 탭하면 Y축으로 뒤집히는 카드. 앞면=이미지+별명, 뒷면=별명 역사.
class _FlipCard extends StatefulWidget {
  const _FlipCard({super.key, required this.exhibit});
  final NicknameExhibit exhibit;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  bool _showingBack = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showingBack) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    _showingBack = !_showingBack;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle = _controller.value * math.pi;
          // 절반을 넘기면 뒷면을 보여준다(뒷면은 다시 180° 돌려 거울반전 방지).
          final isBack = angle > math.pi / 2;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0015) // 원근감
            ..rotateY(angle);
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CardBack(exhibit: widget.exhibit),
                  )
                : _CardFront(exhibit: widget.exhibit),
          );
        },
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.exhibit});
  final NicknameExhibit exhibit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _image()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text(
              exhibit.nickname,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.gray900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _image() {
    final url = exhibit.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: AppColors.gray100,
        alignment: Alignment.center,
        child: const Icon(Icons.emoji_emotions_outlined,
            size: 32, color: AppColors.gray400),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.gray100,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, _, __) => Container(
        color: AppColors.gray100,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined,
            size: 28, color: AppColors.gray400),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.exhibit});
  final NicknameExhibit exhibit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exhibit.nickname,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Colors.white24),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                exhibit.history.isEmpty ? '설명이 없어요.' : exhibit.history,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 10.5,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Center(child: Icon(Icons.collections_outlined, size: 44, color: AppColors.gray300)),
        SizedBox(height: 12),
        Text(
          '아직 등록된 별명이 없어요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: AppColors.gray500,
          ),
        ),
      ],
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
