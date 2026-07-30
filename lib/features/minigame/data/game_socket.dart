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
    this.onDisconnected,
    this.onError,
  });

  final String topic;
  final String accessToken;
  final void Function(Map<String, dynamic> json) onJson;
  final void Function()? onConnected;

  /// 끊김(또는 CONNECT 실패) 알림 — 화면이 "연결 끊김" 배너를 띄울 수 있게.
  /// 실시간 이벤트가 유일한 진실 출처라, 끊긴 걸 모르면 화면이 멈춘 것처럼 보인다.
  final void Function()? onDisconnected;
  final void Function(Object error)? onError;

  StompClient? _client;
  bool _disposed = false;

  /// 지금 STOMP 세션이 살아 있는지 — 화면 배너/전송 가능 여부 판단에 쓴다.
  bool get connected => _client?.connected ?? false;

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
        onDisconnect: (_) {
          if (!_disposed) onDisconnected?.call();
        },
        onWebSocketDone: () {
          if (!_disposed) onDisconnected?.call();
        },
        onWebSocketError: (error) {
          if (!_disposed) onDisconnected?.call();
          onError?.call(error);
        },
        onStompError: (frame) {
          if (!_disposed) onDisconnected?.call();
          onError?.call(frame.body ?? 'STOMP error');
        },
      ),
    );
    _client = client;
    client.activate();
  }

  /// 전송. 세션이 끊겨 있으면 false — 호출자가 사용자에게 알릴 수 있다.
  bool send(String destination, [Map<String, dynamic>? body]) {
    final client = _client;
    if (client == null || !client.connected) return false;
    client.send(
      destination: destination,
      body: body == null ? null : jsonEncode(body),
    );
    return true;
  }

  void dispose() {
    _disposed = true;
    _client?.deactivate();
    _client = null;
  }
}
