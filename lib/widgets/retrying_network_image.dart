import 'dart:async';
import 'package:flutter/material.dart';

/// 네트워크 이미지를 자동으로 몇 차례 재시도하며 불러오는 위젯.
///
/// 일반 [Image.network] 는 첫 로드가 실패하면 errorBuilder 결과로 '고정'되고,
/// 실패가 전역 [imageCache] 에 남아 같은 URL 재요청도 즉시 실패로 반환된다. 그래서
/// 콜드스타트 직후 그리드가 사진 여러 장을 한꺼번에 요청하다 일부가 실패로 굳으면,
/// 그 이미지가 멀쩡히 서버에 있어도 화면을 다시 열기 전까지 안 떴다 — 그림일기
/// 캘린더에서 "첫 진입엔 안 뜨고 상세에 들어갔다 나와야 뜨는" 증상의 원인.
///
/// 이 위젯은 로드 실패 시 [retryDelay] 뒤 캐시에서 해당 항목을 evict 하고 다시
/// 시도하기를 [maxRetries] 회까지 반복하며, 그동안/최종 실패 시 [fallback] 을 보여준다.
class RetryingNetworkImage extends StatefulWidget {
  const RetryingNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallback,
    this.maxRetries = 4,
    this.retryDelay = const Duration(milliseconds: 300),
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// 로딩/실패 중에 보여줄 대체 위젯.
  final Widget? fallback;
  final int maxRetries;
  final Duration retryDelay;

  @override
  State<RetryingNetworkImage> createState() => _RetryingNetworkImageState();
}

class _RetryingNetworkImageState extends State<RetryingNetworkImage> {
  int _attempt = 0;
  Timer? _timer;

  @override
  void didUpdateWidget(RetryingNetworkImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _timer?.cancel();
      _timer = null;
      _attempt = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_attempt >= widget.maxRetries || _timer != null) return;
    // 점증 백오프 — 첫 재시도는 짧게(콜드스타트 동시요청 과부하는 보통 금방 풀림),
    // 이후엔 조금씩 길게.
    final delay = widget.retryDelay * (_attempt + 1);
    _timer = Timer(delay, () {
      _timer = null;
      if (!mounted) return;
      // 실패가 캐시에 남아 있으면 같은 URL 재요청이 즉시 실패로 돌아오므로 비운다.
      imageCache.evict(NetworkImage(widget.url));
      setState(() => _attempt++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.fallback ?? const SizedBox.shrink();
    return Image.network(
      widget.url,
      key: ValueKey('${widget.url}#$_attempt'),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        if (_attempt < widget.maxRetries) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scheduleRetry());
        }
        return fallback;
      },
    );
  }
}
