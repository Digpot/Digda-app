import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../core/config/env.dart';

/// 미니게임 공용 STOMP 세션 — 오목([OmokSocketSession])과 같은 수명 정책을
/// 캐치마인드/탭배틀에서 재사용할 수 있게 토픽/발신을 일반화했다.
///
/// - 연결: `wss://<api>/ws`, CONNECT 프레임에 access token.
/// - 구독: [topic] (예: `/topic/catchmind/123`). 이벤트 JSON 은 [onJson] 으로.
/// - 발신: [send] — `/app/...` destination 에 JSON body.
/// - 끊김 시 5초 자동 재연결, 재연결 후엔 [onConnected] 에서 REST 재동기화.
class GameSocketSession {
  GameSocketSession({
    required this.topic,
    required this.accessToken,
    required this.onJson,
    this.onConnected,
    this.onError,
  });

  final String topic;
  final String accessToken;
  final void Function(Map<String, dynamic> json) onJson;
  final void Function()? onConnected;
  final void Function(Object error)? onError;

  StompClient? _client;
  bool _disposed = false;

  static String get _wsUrl {
    final base = Env.apiBaseUrl;
    final ws = base
        .replaceFirst(RegExp(r'^https://'), 'wss://')
        .replaceFirst(RegExp(r'^http://'), 'ws://');
    return '$ws/ws';
  }

  void connect() {
    if (_disposed || _client != null) return;
    final client = StompClient(
      config: StompConfig(
        url: _wsUrl,
        stompConnectHeaders: {'Authorization': 'Bearer $accessToken'},
        reconnectDelay: const Duration(seconds: 5),
        onConnect: (frame) {
          if (_disposed) return;
          _client?.subscribe(
            destination: topic,
            callback: (frame) {
              final body = frame.body;
              if (_disposed || body == null || body.isEmpty) return;
              try {
                onJson((jsonDecode(body) as Map).cast<String, dynamic>());
              } catch (e) {
                onError?.call(e);
              }
            },
          );
          onConnected?.call();
        },
        onWebSocketError: (error) => onError?.call(error),
        onStompError: (frame) => onError?.call(frame.body ?? 'STOMP error'),
      ),
    );
    _client = client;
    client.activate();
  }

  void send(String destination, [Map<String, dynamic>? body]) {
    _client?.send(
      destination: destination,
      body: body == null ? null : jsonEncode(body),
    );
  }

  void dispose() {
    _disposed = true;
    _client?.deactivate();
    _client = null;
  }
}
