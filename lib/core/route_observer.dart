import 'package:flutter/material.dart';

/// 전역 [RouteObserver]. 화면이 다른 라우트 위로 가려졌다가 다시 노출될 때
/// (`didPopNext`) 등을 감지해야 하는 화면에서 [RouteAware] 와 함께 사용한다.
///
/// [MaterialApp.navigatorObservers] 에 등록되어 있으며,
/// 사용 측에서는 `didChangeDependencies` 에서 subscribe, `dispose` 에서
/// unsubscribe 해야 한다.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
