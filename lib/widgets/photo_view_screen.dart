import 'package:flutter/material.dart';

/// 사진 원본 전체화면 뷰어.
///
/// 그림일기 상세의 hero 사진(BoxFit.cover 로 잘려 보임)과 별명 전시관 카드에서
/// 공용으로 사용한다. 검은 배경 위에 사진을 잘리지 않게(BoxFit.contain) 띄우고,
/// 핀치 줌(InteractiveViewer)·좌우 스와이프(PageView)를 지원한다.
/// [title]·[description] 이 있으면 하단에 반투명 캡션으로 함께 노출한다.
Future<void> openPhotoViewer(
  BuildContext context, {
  required List<String> images,
  int initialIndex = 0,
  String? title,
  String? description,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => PhotoViewScreen(
        images: images,
        initialIndex: initialIndex,
        title: title,
        description: description,
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class PhotoViewScreen extends StatefulWidget {
  const PhotoViewScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.title,
    this.description,
  });

  final List<String> images;
  final int initialIndex;
  final String? title;
  final String? description;

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasCaption =>
      (widget.title?.isNotEmpty ?? false) ||
      (widget.description?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 빈 영역 탭으로 닫기. 사진(InteractiveViewer) 위 탭은 자식이 가져간다.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _ZoomablePhoto(url: widget.images[i]),
          ),
          // 상단: 닫기 버튼 + 인덱스 카운터
          Positioned(
            left: 8,
            right: 8,
            top: topInset + 8,
            child: Row(
              children: [
                _CircleButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                if (widget.images.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          if (_hasCaption)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Caption(
                title: widget.title,
                description: widget.description,
                bottomInset: bottomInset,
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoomablePhoto extends StatelessWidget {
  const _ZoomablePhoto({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 44, color: Colors.white38),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({
    required this.title,
    required this.description,
    required this.bottomInset,
  });
  final String? title;
  final String? description;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title?.isNotEmpty ?? false)
            Text(
              title!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          if ((title?.isNotEmpty ?? false) &&
              (description?.isNotEmpty ?? false))
            const SizedBox(height: 8),
          if (description?.isNotEmpty ?? false)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(
                  description!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFFE5E8EB),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
