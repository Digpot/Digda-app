import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../features/map/data/korea_map_loader.dart';
import '../../features/map/data/korea_map_models.dart';
import '../../features/map/painter/korea_map_painter.dart';
import '../../theme/colors.dart';
import '../../widgets/back_header.dart';
import 'region_diary_list_screen.dart';

/// 디그팟 시그니처 지도 — 그룹이 일기를 남긴 지역을 코랄로 채운다.
/// 군·시는 일기 1개, 광역시는 10개로 색칠.
///
/// 진입 즉시 지도(+전 지역명)를 그려 두고, 그룹별 색칠 데이터(region-map)는
/// 백그라운드로 받아 도착하면 색만 입힌다 — 느린 조회로 화면이 멈추지 않는다.
/// 상단 권역 탭으로 포커스 이동, 손가락으로 패닝/확대(InteractiveViewer).
class KoreaMapScreen extends StatefulWidget {
  const KoreaMapScreen({super.key});

  @override
  State<KoreaMapScreen> createState() => _KoreaMapScreenState();
}

class _KoreaMapScreenState extends State<KoreaMapScreen>
    with TickerProviderStateMixin {
  /// 권역 탭 표준 순서(데이터에 존재하는 것만 노출).
  static const List<String> _groupOrder = [
    '수도권',
    '강원',
    '충청',
    '전라',
    '경상',
    '제주',
  ];

  /// 권역별 시그니처 색(handoff §3 groupColors). 선택 패널 액센트에 사용.
  static const Map<String, Color> _groupColors = {
    '수도권': Color(0xFFFF6B6B),
    '강원': Color(0xFF5B9BF0),
    '충청': Color(0xFFF4B53C),
    '전라': Color(0xFF33C08A),
    '경상': Color(0xFFA98BF0),
    '제주': Color(0xFFF47BB4),
  };

  KoreaMapData? _data;
  Map<String, int> _counts = const {};
  bool _loadingMap = true;
  bool _loadingCounts = false;
  String? _error;
  String? _selectedKey;
  String? _focusGroup; // null = 전체 (권역 포커스)
  String? _focusKey; // null = 권역/전체 (광역시 포커스 시 그 시 색칠 키)
  bool _interacting = false; // 패닝/줌 제스처 중 — 라벨 경량화

  /// 광역시 탭 표준 순서(데이터에 존재하는 것만 노출).
  static const List<String> _metroOrder = [
    '서울',
    '인천',
    '부산',
    '대구',
    '광주',
    '대전',
    '울산',
    '세종',
  ];

  // 현재 화면에 적용된 fit 변환(탭 포커스 시 좌표 계산에 사용).
  double _scale = 1, _dx = 0, _dy = 0;
  Size _viewport = Size.zero;

  final TransformationController _tc = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Animation<Matrix4>? _matrixAnim;

  // 첫 진입 인트로 — 지도 프레임이 살짝 줌인+페이드인 하며 등장.
  late final AnimationController _introCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _intro =
      CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutCubic);
  late final Animation<double> _introScale =
      Tween<double>(begin: 0.92, end: 1.0).animate(_intro);
  bool _introStarted = false;

  final Map<String, Rect> _groupBoundsCache = {};

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final m = _matrixAnim?.value;
      if (m != null) _tc.value = m;
    });
    // 탭 줌 애니메이션이 끝나면 라벨을 전체(상세) 표시로 복귀.
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.completed && _interacting) {
        setState(() => _interacting = false);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    _introCtrl.dispose();
    _tc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadingMap = true;
      _error = null;
    });
    // 1) 지도 에셋 먼저(캐시 우선, 빠름) — 즉시 표시.
    KoreaMapData data;
    try {
      data = await KoreaMapLoader.load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '지도를 불러오지 못했어요';
        _loadingMap = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _data = data;
      _loadingMap = false;
    });
    // 지도가 처음 그려진 직후 한 번만 인트로 재생.
    if (!_introStarted) {
      _introStarted = true;
      _introCtrl.forward(from: 0);
    }
    // 권역 경계선(union) 캐시를 인트로 이후 미리 데워, 탭 선택 순간의 끊김 방지.
    _warmGroupOutlines(data);

    // 2) 그룹 색칠 데이터는 백그라운드로 — 도착하면 색만 입힌다.
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    setState(() => _loadingCounts = true);
    try {
      final res = await Di.diaryRepository.regionMap(groupId);
      if (!mounted) return;
      setState(() {
        _counts = res.countByKey;
        _loadingCounts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  /// 권역별 경계선 union 을 인트로가 끝난 뒤 한 권역씩 미리 계산해 캐시에 채운다.
  /// 탭을 눌러 줌하는 순간 무거운 union 이 돌지 않도록 비상호작용 시점에 분산 처리.
  void _warmGroupOutlines(KoreaMapData data) {
    final groups = _groupOrder.where(data.keyGroup.values.contains).toList();
    var delay = 750; // 인트로(650ms) 직후부터
    for (final g in groups) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;
        data.groupOutline(g); // 결과는 data 내부 캐시에 저장됨
      });
      delay += 60;
    }
  }

  /// 채색 완료된 색칠키 수.
  int get _coloredCount {
    final data = _data;
    if (data == null) return 0;
    var n = 0;
    for (final entry in data.byKey.keys) {
      final meta = data.metaOf(entry);
      if (meta != null && meta.isColored(_counts[entry] ?? 0)) n++;
    }
    return n;
  }

  void _handleTap(Offset local) {
    final data = _data;
    if (data == null) return;
    final vx = (local.dx - _dx) / _scale;
    final vy = (local.dy - _dy) / _scale;
    final p = Offset(vx, vy);
    String? hit;
    for (final r in data.regions) {
      if (r.path.contains(p)) {
        hit = r.key;
        break;
      }
    }
    setState(() => _selectedKey = hit);
  }

  /// 권역의 모든 조각을 감싸는 view 좌표 bounds(캐시).
  Rect? _groupBounds(String group) {
    final data = _data;
    if (data == null) return null;
    final cached = _groupBoundsCache[group];
    if (cached != null) return cached;
    Rect? acc;
    for (final r in data.regions) {
      if (r.group != group) continue;
      final b = r.path.getBounds();
      acc = acc == null ? b : acc.expandToInclude(b);
    }
    if (acc != null) _groupBoundsCache[group] = acc;
    return acc;
  }

  /// 전체 보기로(포커스 해제).
  void _selectAll() {
    setState(() {
      _focusGroup = null;
      _focusKey = null;
      _selectedKey = null;
    });
    if (_viewport != Size.zero) _animateTo(Matrix4.identity());
  }

  /// 권역(도) 탭 포커스.
  void _selectGroup(String group) {
    setState(() {
      _focusGroup = group;
      _focusKey = null;
      _selectedKey = null;
    });
    final vb = _groupBounds(group);
    if (vb != null) _zoomToViewBounds(vb);
  }

  /// 광역시 탭 포커스 — 그 시 1곳만 또렷하게, 깊게 줌.
  void _selectMetro(String key) {
    setState(() {
      _focusKey = key;
      _focusGroup = null;
      _selectedKey = null;
    });
    final vb = _data?.keyBounds(key);
    if (vb != null) _zoomToViewBounds(vb);
  }

  /// viewBox 좌표 bounds 로 부드럽게 줌(밀집 지역도 글자가 보이도록 상한 14배).
  void _zoomToViewBounds(Rect vb) {
    if (_viewport == Size.zero) return;
    final screenRect = Rect.fromLTWH(
      _dx + vb.left * _scale,
      _dy + vb.top * _scale,
      vb.width * _scale,
      vb.height * _scale,
    ).inflate(16);
    final z = (_viewport.width / screenRect.width).clamp(1.0, 14.0).toDouble();
    final zy =
        (_viewport.height / screenRect.height).clamp(1.0, 14.0).toDouble();
    final zoom = z < zy ? z : zy;
    final tx = _viewport.width / 2 - zoom * screenRect.center.dx;
    final ty = _viewport.height / 2 - zoom * screenRect.center.dy;
    _animateTo(Matrix4.identity()
      ..translate(tx, ty)
      ..scale(zoom));
  }

  /// 현재 포커스(권역/광역시)의 시그니처 색 — 경계선 색으로 쓴다.
  Color? _focusAccent(KoreaMapData data) {
    if (_focusKey != null) {
      return _groupColors[data.keyGroup[_focusKey!]] ?? AppColors.primary;
    }
    if (_focusGroup != null) {
      return _groupColors[_focusGroup!] ?? AppColors.primary;
    }
    return null;
  }

  void _animateTo(Matrix4 target) {
    // 프로그램 줌(탭) 동안에도 라벨을 가볍게 유지.
    if (!_interacting) setState(() => _interacting = true);
    _matrixAnim = Matrix4Tween(begin: _tc.value, end: target).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic),
    );
    _anim
      ..reset()
      ..forward();
  }

  // 모찌 시스템과 맞춘 깨끗한 흰색 화면 배경.
  static const Color _screenBg = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBg,
      body: SafeArea(
        child: Column(
          children: [
            const BackHeader(title: '우리 발자취'),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingMap) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null || _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? '지도를 불러오지 못했어요',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    final data = _data!;
    return Column(
      children: [
        _buildTabs(data),
        _buildSummary(),
        // 점토 지도가 따뜻한 무대 위에 놓인 듯 보이도록 방사형 배경 + 라운드 프레임.
        // (LayoutBuilder 는 프레임 안쪽이라 constraints 가 margin 적용 후 크기 → fit/히트테스트 일치)
        // 첫 진입 시 살짝 줌인+페이드인 인트로(_intro).
        Expanded(
          child: FadeTransition(
            opacity: _intro,
            child: ScaleTransition(
            scale: _introScale,
            child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.gray100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
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
                _scale = scale;
                _dx = dx;
                _dy = dy;
                _viewport = Size(w, h);
                // 지형(무거움)은 InteractiveViewer 안에서 GPU 변환만 → 줌/패닝 매끄럽게.
                // 라벨은 변환 밖 화면 좌표 레이어로 분리해 상수 크기 + 경량 컬링.
                return Stack(
                  children: [
                    InteractiveViewer(
                      transformationController: _tc,
                      minScale: 1.0,
                      // 밀집 지역(수도권·광역시)도 글자가 분리돼 보이도록 깊게 확대.
                      maxScale: 20.0,
                      boundaryMargin: const EdgeInsets.all(120),
                      onInteractionStart: (_) {
                        if (!_interacting) setState(() => _interacting = true);
                      },
                      onInteractionEnd: (_) {
                        if (_interacting) setState(() => _interacting = false);
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _handleTap(d.localPosition),
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: Size(w, h),
                            isComplex: true,
                            willChange: false,
                            painter: KoreaBasePainter(
                              data: data,
                              counts: _counts,
                              scale: scale,
                              dx: dx,
                              dy: dy,
                              selectedKey: _selectedKey,
                              focusGroup: _focusGroup,
                              focusKey: _focusKey,
                              focusColor: _focusAccent(data),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 라벨 레이어 — 변환을 읽어 화면 좌표로 직접 배치(상수 크기). 탭 통과.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          size: Size(w, h),
                          willChange: true,
                          painter: KoreaLabelPainter(
                            data: data,
                            counts: _counts,
                            scale: scale,
                            dx: dx,
                            dy: dy,
                            transform: _tc,
                            selectedKey: _selectedKey,
                            focusGroup: _focusGroup,
                            focusKey: _focusKey,
                            interacting: _interacting,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          ),
        ),
        ),
        _buildSelectedPanel(),
      ],
    );
  }

  /// 탭/칩 표시명 — 내부 권역명(수도권/강원/…)을 친숙한 도 이름으로.
  /// 수도권은 "경기도"로, 나머지는 "도"를 붙인다.
  static const Map<String, String> _groupTabLabels = {
    '수도권': '경기도',
    '강원': '강원도',
    '충청': '충청도',
    '전라': '전라도',
    '경상': '경상도',
    '제주': '제주도',
  };

  String _tabLabel(String? group) =>
      group == null ? '전체' : (_groupTabLabels[group] ?? group);

  /// 단일 탭 알약. 활성은 액센트색, 비활성은 흰 배경에서 보이도록 연회색.
  Widget _tabPill({
    required String label,
    required bool active,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: active ? accent : AppColors.gray50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? accent : AppColors.gray100),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: active ? AppColors.white : AppColors.gray700,
          ),
        ),
      ),
    );
  }

  Widget _buildTabs(KoreaMapData data) {
    final groups = _groupOrder.where(data.keyGroup.values.contains).toList();
    final metros = _metroOrder
        .where((k) => data.keyMetro[k] == true && data.byKey.containsKey(k))
        .toList();

    final children = <Widget>[
      // 전체
      _tabPill(
        label: '전체',
        active: _focusGroup == null && _focusKey == null,
        accent: AppColors.primary,
        onTap: _selectAll,
      ),
      // 권역(도)
      for (final g in groups) ...[
        const SizedBox(width: 8),
        _tabPill(
          label: _tabLabel(g),
          active: _focusGroup == g,
          accent: _groupColors[g] ?? AppColors.primary,
          onTap: () => _selectGroup(g),
        ),
      ],
      // 구분선 + 광역시
      if (metros.isNotEmpty) ...[
        Container(
          width: 1,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: AppColors.gray100,
        ),
        for (final k in metros) ...[
          _tabPill(
            label: data.keyLabel[k] ?? k,
            active: _focusKey == k,
            accent: _groupColors[data.keyGroup[k]] ?? AppColors.primary,
            onTap: () => _selectMetro(k),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ];

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: children,
      ),
    );
  }

  Widget _buildSummary() {
    final total = _data?.byKey.length ?? 0;
    final done = _coloredCount;
    final frac = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFFFD9CF)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.place, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '전국 $done곳을 채웠어요',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.gray900,
                    ),
                  ),
                  if (_loadingCounts) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFEFE6D6),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$done/$total',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPanel() {
    final data = _data!;
    final key = _selectedKey;
    if (key == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Text(
          '지역을 눌러 우리가 남긴 기록을 확인해 보세요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppColors.gray400,
          ),
        ),
      );
    }
    final meta = data.metaOf(key);
    final count = _counts[key] ?? 0;
    final label = meta?.label ?? key;
    final threshold = meta?.threshold ?? 1;
    final colored = meta?.isColored(count) ?? false;
    final remaining = (threshold - count).clamp(0, threshold);
    final group = data.keyGroup[key];
    final accent = _groupColors[group] ?? AppColors.primary;

    final String statusText;
    if (colored) {
      statusText = '색칠 완료! · 일기 $count개';
    } else if (count == 0) {
      statusText = '아직 기록이 없어요';
    } else {
      statusText = '일기 $count개 · 색칠까지 $remaining개 더!';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
      decoration: BoxDecoration(
        color: colored ? const Color(0xFFFFF1EE) : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colored ? const Color(0xFFFFD2C8) : AppColors.gray100,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // 권역 색 액센트 바
            Container(width: 5, color: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.gray900,
                            ),
                          ),
                        ),
                        if (group != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _tabLabel(group),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colored ? accent : AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (count > 0)
            GestureDetector(
              onTap: () {
                final groupId = Di.activeGroup.groupRoomId;
                if (groupId == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RegionDiaryListScreen(
                      groupRoomId: groupId,
                      regionKey: key,
                      label: label,
                    ),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.32),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  '일기 보기',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}
