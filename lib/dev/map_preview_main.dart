import 'package:flutter/material.dart';

import '../core/config/env.dart';
import '../core/di.dart';
import '../features/map/data/korea_map_loader.dart';
import '../features/map/data/korea_map_models.dart';
import '../features/map/painter/korea_map_painter.dart';
import '../screens/map/korea_map_screen.dart';

/// 지도 UI 확인용 dev 엔트리포인트 — 로그인/서버 없이 지도 화면을 그대로 띄운다.
///
/// 좌우 스와이프 2페이지:
///  1) 실제 KoreaMapScreen (그룹 미선택 → 색칠 0 상태의 전체 크롬)
///  2) 색칠 시뮬레이션 — 지역 1/3 을 채운 것으로 가정한 지도 카드(코랄+글로스 확인)
///
///   flutter run -d <device> -t lib/dev/map_preview_main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Env.load();
  } catch (e) {
    debugPrint('[map_preview] .env 로드 실패(무시): $e');
  }
  Di.bootstrap();
  runApp(const _MapPreviewApp());
}

class _MapPreviewApp extends StatelessWidget {
  const _MapPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // 색칠 시뮬레이션을 첫 페이지로 — 실제 지도 화면(InteractiveViewer)이
      // 가로 스와이프를 소비해 페이지 전환이 안 되므로, 시뮬레이션에서 시작해
      // 오른쪽으로 넘겨 실제 화면을 본다.
      home: PageView(
        controller: PageController(initialPage: 1),
        children: const [
          KoreaMapScreen(),
          _ColoredMapPreview(),
        ],
      ),
    );
  }
}

/// 색칠 시뮬레이션 — 로더 데이터에 가짜 카운트를 넣어 코랄 채색/글로스를 확인.
class _ColoredMapPreview extends StatefulWidget {
  const _ColoredMapPreview();

  @override
  State<_ColoredMapPreview> createState() => _ColoredMapPreviewState();
}

class _ColoredMapPreviewState extends State<_ColoredMapPreview> {
  KoreaMapData? _data;
  Map<String, int> _counts = const {};
  final ValueNotifier<Matrix4> _tc = ValueNotifier(Matrix4.identity());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await KoreaMapLoader.load();
    final keys = data.byKey.keys.toList();
    final counts = <String, int>{};
    for (var i = 0; i < keys.length; i++) {
      if (i % 3 == 0) counts[keys[i]] = 10;
    }
    if (!mounted) return;
    setState(() {
      _data = data;
      _counts = counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '색칠 시뮬레이션 (1/3 채움)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            Expanded(
              child: data == null
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFF1F2F4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final h = constraints.maxHeight;
                          final scale = (w / data.width) < (h / data.height)
                              ? w / data.width
                              : h / data.height;
                          final dx = (w - data.width * scale) / 2;
                          final dy = (h - data.height * scale) / 2;
                          return Stack(
                            children: [
                              CustomPaint(
                                size: Size(w, h),
                                painter: KoreaBasePainter(
                                  data: data,
                                  counts: _counts,
                                  completedGroups: const {},
                                  partialGroups: const {},
                                  scale: scale,
                                  dx: dx,
                                  dy: dy,
                                ),
                              ),
                              CustomPaint(
                                size: Size(w, h),
                                painter: KoreaOverlayPainter(
                                  data: data,
                                  counts: _counts,
                                  completedGroups: const {},
                                  scale: scale,
                                  dx: dx,
                                  dy: dy,
                                  transform: _tc,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
