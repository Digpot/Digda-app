import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../core/config/env.dart';
import '../models/omok_models.dart';

/// 오목 대국 1판의 STOMP 세션.
///
/// - 연결: `wss://<api>/ws` — CONNECT 프레임에 access token 을 실어 서버가 인증.
/// - 구독: `/topic/omok/{gameId}` — 모든 대국 이벤트([OmokEvent])가 여기로 온다.
/// - 발신: `/app/omok/{gameId}/move`, `/app/omok/{gameId}/forfeit`.
///
/// 끊김 시 5초 간격 자동 재연결(라이브러리 기본 동작)되고, 재연결 후엔 호출자가
/// REST 스냅샷으로 재동기화한다([onConnected] 콜백에서).
class OmokSocketSession {
  OmokSocketSession({
    required this.gameId,
    required this.accessToken,
    required this.onEvent,
    this.onConnected,
    this.onDisconnected,
    this.onError,
  });

  final int gameId;
  final String accessToken;
  final void Function(OmokEvent event) onEvent;

  /// (재)연결·구독 완료 시 — 호출자는 REST 로 스냅샷을 다시 받아 놓친 수를 메꾼다.
  final void Function()? onConnected;

  /// 끊김 알림 — 화면이 "연결 끊김" 배너를 띄울 수 있게.
  final void Function()? onDisconnected;
  final void Function(Object error)? onError;

  StompClient? _client;
  bool _disposed = false;

  /// 지금 STOMP 세션이 살아 있는지.
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
            destination: '/topic/omok/$gameId',
            callback: (frame) {
              final body = frame.body;
              if (_disposed || body == null || body.isEmpty) return;
              try {
                final json = (jsonDecode(body) as Map).cast<String, dynamic>();
                onEvent(OmokEvent.fromJson(json));
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

  void sendMove(int x, int y) {
    _client?.send(
      destination: '/app/omok/$gameId/move',
      body: jsonEncode({'x': x, 'y': y}),
    );
  }

  void sendForfeit() {
    _client?.send(destination: '/app/omok/$gameId/forfeit');
  }

  void dispose() {
    _disposed = true;
    _client?.deactivate();
    _client = null;
  }
}
