import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../features/title/models/title_models.dart';
import '../../features/title/title_catalog.dart';
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
    with SingleTickerProviderStateMixin {
  /// 탭 버킷별 시그니처 색. 선택 패널 액센트·뱃지에 사용.
  static const Map<String, Color> _groupColors = {
    '광역시': Color(0xFFFF8A5B),
    '경기북부': Color(0xFFFF6B6B),
    '경기남부': Color(0xFFE8553D),
    '강원': Color(0xFF5B9BF0),
    '충북': Color(0xFFF4B53C),
    '충남': Color(0xFFE0962B),
    '전북': Color(0xFF33C08A),
    '전남': Color(0xFF1FA876),
    '경북': Color(0xFFA98BF0),
    '경남': Color(0xFF8B6BE0),
    '제주': Color(0xFFF47BB4),
  };

  KoreaMapData? _data;
  Map<String, int> _counts = const {};
  // 어드민이 임의로 채운 지역(실제 일기 아님) — 패널에서 "관리자 채움"으로 구분.
  Set<String> _adminFilled = const {};
  bool _loadingMap = true;
  bool _loadingCounts = false;
  String? _error;
  String? _selectedKey;
  String? _focusGroup; // null = 전체

  // 도(버킷) 단위 색칠 상태 — 모든 시·군·구가 차면 completed, 일부면 partial.
  // _counts 가 바뀔 때만 다시 계산해 페인터에 안정적인 참조로 전달(불필요한 재페인트 방지).
  Set<String> _completedGroups = const {};
  Set<String> _partialGroups = const {};

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

    // 2) 그룹 색칠 데이터는 백그라운드로 — 도착하면 색만 입힌다.
    await _loadCounts();
  }

  /// 그룹 색칠 데이터(region-map)를 받아 지도 색을 갱신한다.
  /// region-map 은 캐시하지 않고 매번 서버 최신을 받으므로, 일기를 삭제한 뒤
  /// 다시 호출하면 색칠이 즉시 사라진다(지역 일기 목록에서 돌아올 때 재호출).
  Future<void> _loadCounts() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    setState(() => _loadingCounts = true);
    try {
      final res = await Di.diaryRepository.regionMap(groupId);
      if (!mounted) return;
      setState(() {
        _counts = res.countByKey;
        _adminFilled = res.adminFilledKeys;
        _loadingCounts = false;
        _computeBucketFill();
      });
      // 정복한 도(시·군 전부 채움)는 지역 칭호로 적재. 실패해도 지도엔 영향 없음.
      _claimConqueredRegions();
    } catch (_) {
      if (mounted) setState(() => _loadingCounts = false);
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

  /// 도(버킷)별로 시·군·구 채움을 집계해 completed/partial 집합을 갱신.
  void _computeBucketFill() {
    final data = _data;
    if (data == null) return;
    final completed = <String>{};
    final partial = <String>{};
    data.keysByFocusGroup.forEach((group, keys) {
      var done = 0;
      for (final k in keys) {
        final meta = data.metaOf(k);
        if (meta != null && meta.isColored(_counts[k] ?? 0)) done++;
      }
      if (done == 0) return;
      if (done == keys.length) {
        completed.add(group);
      } else {
        partial.add(group);
      }
    });
    _completedGroups = completed;
    _partialGroups = partial;
  }

  /// 주어진 색칠 카운트로 완전 정복(모든 시·군·구 채움)된 도(버킷) 집합을 계산.
  /// 표시용 _computeBucketFill 과 달리 임의의 카운트 맵에 대해 순수 계산만 한다.
  Set<String> _completedBucketsFor(Map<String, int> counts) {
    final data = _data;
    if (data == null) return const {};
    final completed = <String>{};
    data.keysByFocusGroup.forEach((group, keys) {
      if (keys.isEmpty) return;
      var done = 0;
      for (final k in keys) {
        final meta = data.metaOf(k);
        if (meta != null && meta.isColored(counts[k] ?? 0)) done++;
      }
      if (done == keys.length) completed.add(group);
    });
    return completed;
  }

  /// 정복 완료된 지역을 칭호로 서버에 적재(멱등). 활성 그룹 맥락으로 기록.
  /// - 도(버킷) 전체 채움 → 도지사(+'광역시' 버킷 전체 → 대도시 정복자 그랜드)
  /// - 광역시·세종 한 도시 채움(임계 10) → 그 도시 '시장'
  ///
  /// 판정 카운트는 지도 표시(_counts, 그룹 전체)가 아니라 **가입 이후 작성분만** 집계한
  /// scope=claim 맵을 쓴다 — 중간 합류한 그룹원이 가입 전 그룹 성과를 소급해서 칭호로
  /// 가져가지 못하게(서버도 동일 기준으로 한 번 더 검증).
  Future<void> _claimConqueredRegions() async {
    final groupId = Di.activeGroup.groupRoomId;
    final gid = groupId == null ? null : int.tryParse(groupId);
    final data = _data;
    if (gid == null || groupId == null || data == null) return;
    try {
      final scoped = await Di.diaryRepository.regionMap(groupId, scope: 'claim');
      final claimCounts = scoped.countByKey;
      await TitleCatalog.ensureLoaded(); // 조건값→코드 매핑은 서버 카탈로그에서
      final map = TitleCatalog.regionBucketToCode;
      final claims = <TitleClaim>[];
      final seen = <String>{};
      void add(String? condition) {
        if (condition == null) return;
        final code = map[condition];
        if (code != null && seen.add(code)) {
          claims.add(TitleClaim(code: code, groupRoomId: gid));
        }
      }

      // 도(권역)·대도시 그랜드 — 버킷 전체 채움(가입 이후 작성분 기준).
      for (final bucket in _completedBucketsFor(claimCounts)) {
        add(bucket);
      }
      // 광역시·세종 — 도시별 채움(임계 달성) 시 그 도시 시장 칭호.
      data.byKey.forEach((key, _) {
        if (data.keyMetro[key] != true) return;
        final meta = data.metaOf(key);
        if (meta != null && meta.isColored(claimCounts[key] ?? 0)) add(key);
      });
      if (claims.isEmpty) return;
      await Di.titleRepository.claim(claims);
    } catch (_) {
      // 칭호 적재 실패는 화면 표시에 영향 없음
    }
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
      if (data.keyFocusGroup[r.key] != group) continue;
      final b = r.path.getBounds();
      acc = acc == null ? b : acc.expandToInclude(b);
    }
    if (acc != null) _groupBoundsCache[group] = acc;
    return acc;
  }

  void _selectGroup(String? group) {
    setState(() {
      _focusGroup = group;
      _selectedKey = null;
    });
    if (_viewport == Size.zero) return;
    if (group == null) {
      _animateTo(Matrix4.identity());
      return;
    }
    final vb = _groupBounds(group);
    final target = vb == null ? null : _matrixForViewBounds(vb);
    if (target != null) _animateTo(target);
  }

  /// 리스트에서 시·군·구 칩을 누르면 — 선택 강조 + 그 조각으로 부드럽게 이동.
  void _selectKey(String key) {
    setState(() => _selectedKey = key);
    if (_viewport == Size.zero) return;
    final vb = _keyBounds(key);
    if (vb == null) return;
    _animateTo(_matrixForViewBounds(vb, maxZoom: 4.0));
  }

  /// 색칠 키 하나(여러 조각)를 감싸는 view 좌표 bounds.
  Rect? _keyBounds(String key) {
    final list = _data?.byKey[key];
    if (list == null || list.isEmpty) return null;
    Rect? acc;
    for (final r in list) {
      final b = r.path.getBounds();
      acc = acc == null ? b : acc.expandToInclude(b);
    }
    return acc;
  }

  /// view 좌표 bounds → 화면 중앙에 맞춰 줌인하는 변환 행렬.
  Matrix4 _matrixForViewBounds(Rect vb, {double maxZoom = 3.5}) {
    final screenRect = Rect.fromLTWH(
      _dx + vb.left * _scale,
      _dy + vb.top * _scale,
      vb.width * _scale,
      vb.height * _scale,
    ).inflate(16);
    final z = (_viewport.width / screenRect.width).clamp(1.0, maxZoom).toDouble();
    final zy =
        (_viewport.height / screenRect.height).clamp(1.0, maxZoom).toDouble();
    final zoom = z < zy ? z : zy;
    final tx = _viewport.width / 2 - zoom * screenRect.center.dx;
    final ty = _viewport.height / 2 - zoom * screenRect.center.dy;
    return Matrix4.identity()
      ..translate(tx, ty)
      ..scale(zoom);
  }

  /// 탭/패널에 보이는 권역 표시 이름. 데이터 키 '광역시' 버킷은 서울(특별시)·세종
  /// (특별자치시)도 포함하므로 표시만 '대도시'로 바로잡는다(키는 그대로).
  static String _groupDisplayName(String group) =>
      group == '광역시' ? '대도시' : group;

  /// '대도시' 칩에서 앞쪽에 고정할 도시 순서(서울 → 인천 → 부산).
  static const List<String> _metroLeadOrder = ['서울', '인천', '부산'];

  /// 선택된 도(버킷)에 속한 색칠 키들 — 라벨 가나다순.
  /// 단, 광역시 버킷은 서울·인천·부산을 앞에 고정하고 나머지를 가나다순으로.
  List<String> _bucketKeys(KoreaMapData data, String group) {
    final keys = data.keyFocusGroup.entries
        .where((e) => e.value == group)
        .map((e) => e.key)
        .toList();
    int rank(String k) {
      if (group != '광역시') return _metroLeadOrder.length;
      final i = _metroLeadOrder.indexOf(data.keyLabel[k] ?? k);
      return i == -1 ? _metroLeadOrder.length : i;
    }

    keys.sort((a, b) {
      final ra = rank(a), rb = rank(b);
      if (ra != rb) return ra.compareTo(rb);
      return (data.keyLabel[a] ?? a).compareTo(data.keyLabel[b] ?? b);
    });
    return keys;
  }

  void _animateTo(Matrix4 target) {
    _matrixAnim = Matrix4Tween(begin: _tc.value, end: target).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic),
    );
    _anim
      ..reset()
      ..forward();
  }

  // 깔끔한 흰 배경 — 점토 지도가 또렷이 떠 보이도록.
  static const Color _warmBg = Color(0xFFFFFFFF);

  /// 지도 채우는 법 안내 팝업 — 헤더 전구 아이콘에서 띄운다.
  void _showMapGuide() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 코랄 헤더 — 아이콘 + 제목
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF8A5B), AppColors.primary],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.map_rounded,
                        size: 30, color: AppColors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '지도 채우는 법',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '우리가 다녀온 곳을 코랄빛으로 물들여요',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            // 단계 안내
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Column(
                children: [
                  _guideStep(
                    Icons.edit_location_alt_rounded,
                    '장소를 남겨요',
                    '일기를 쓸 때 장소를 함께 기록하면\n그 지역이 지도에 표시돼요.',
                  ),
                  _guideStep(
                    Icons.palette_rounded,
                    '지역이 채워져요',
                    '시·군은 일기 1개, 광역시는 10개를\n모으면 코랄빛으로 색칠돼요.',
                  ),
                  _guideStep(
                    Icons.photo_library_rounded,
                    '기록을 다시 봐요',
                    '채운 지역을 누르면 그곳에 남긴\n일기를 모아 볼 수 있어요.',
                  ),
                  _guideStep(
                    Icons.workspace_premium_rounded,
                    '칭호를 받아요',
                    '한 권역을 모두 채우면 그 지역의\n특별한 칭호를 받게 돼요.',
                    last: true,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '알겠어요',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guideStep(IconData icon, String title, String body,
      {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: AppColors.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _warmBg,
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(
              title: '우리 발자취',
              actions: [
                // 지도 채우는 법 안내 — 누르면 도움말 팝업.
                GestureDetector(
                  onTap: _showMapGuide,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            // 헤더와 권역 탭이 붙어 보이지 않도록 살짝 숨 틔우기.
            const SizedBox(height: 10),
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
        // 전체 탭이면 전국 요약, 도 탭이면 그 도의 진행률 카드만 — 위쪽을 가볍게.
        if (_focusGroup == null)
          _buildSummary()
        else
          _buildRegionStrip(data),
        // 점토 지도가 따뜻한 무대 위에 놓인 듯 보이도록 방사형 배경 + 라운드 프레임.
        // (LayoutBuilder 는 프레임 안쪽이라 constraints 가 margin 적용 후 크기 → fit/히트테스트 일치)
        // 첫 진입 시 살짝 줌인+페이드인 인트로(_intro).
        Expanded(
          child: FadeTransition(
            opacity: _intro,
            child: ScaleTransition(
            scale: _introScale,
            child: Container(
            margin: const EdgeInsets.fromLTRB(6, 2, 6, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white,
              border: Border.all(color: const Color(0xFFEFEFF1)),
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
                return InteractiveViewer(
                  transformationController: _tc,
                  minScale: 1.0,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(120),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _handleTap(d.localPosition),
                    child: Stack(
                      children: [
                        // 무거운 지형은 RepaintBoundary 로 캐시 — 패닝/줌·선택 땐 재래스터 안 됨.
                        RepaintBoundary(
                          child: CustomPaint(
                            size: Size(w, h),
                            painter: KoreaBasePainter(
                              data: data,
                              counts: _counts,
                              completedGroups: _completedGroups,
                              partialGroups: _partialGroups,
                              scale: scale,
                              dx: dx,
                              dy: dy,
                              focusGroup: _focusGroup,
                              focusColor: _focusGroup == null
                                  ? null
                                  : (_groupColors[_focusGroup] ??
                                      AppColors.primary),
                            ),
                          ),
                        ),
                        // 가벼운 라벨/선택 오버레이 — 변환에 맞춰 다시 그리고 화면 밖 라벨은 컬링.
                        CustomPaint(
                          size: Size(w, h),
                          painter: KoreaOverlayPainter(
                            data: data,
                            counts: _counts,
                            completedGroups: _completedGroups,
                            scale: scale,
                            dx: dx,
                            dy: dy,
                            transform: _tc,
                            selectedKey: _selectedKey,
                            focusGroup: _focusGroup,
                          ),
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildTabs(KoreaMapData data) {
    final present = KoreaMapData.focusGroupOrder
        .where(data.keyFocusGroup.values.contains)
        .toList();
    final tabs = <String?>[null, ...present];
    // 정확히 2줄로 — 절반씩 나눠 각 줄을 가로 스크롤(넘치면)로. 세로로 퍼지지 않게.
    final half = (tabs.length / 2).ceil();
    final row1 = tabs.sublist(0, half);
    final row2 = tabs.sublist(half);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabRow(row1),
          const SizedBox(height: 6),
          _tabRow(row2),
        ],
      ),
    );
  }

  Widget _tabRow(List<String?> tabs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _buildTab(tabs[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildTab(String? g) {
    final active = _focusGroup == g;
    final dot = g == null ? AppColors.primary : (_groupColors[g] ?? AppColors.primary);
    return GestureDetector(
      onTap: () => _selectGroup(g),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.fromLTRB(11, 7, 13, 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? AppColors.primary : const Color(0xFFEDE3D2),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 권역 시그니처 색 점 — 활성 시엔 흰 점으로 통일감.
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? Colors.white : dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              g == null ? '전체' : _groupDisplayName(g),
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: active ? AppColors.white : AppColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 도(버킷) 탭 선택 시 — 그 도의 진행률 + 시·군·구 칩을 담은 카드.
  /// 채움 여부가 칩 색으로 보이고, 누르면 지도에서 그 지역으로 이동.
  Widget _buildRegionStrip(KoreaMapData data) {
    final group = _focusGroup;
    if (group == null) return const SizedBox.shrink();
    final keys = _bucketKeys(data, group);
    if (keys.isEmpty) return const SizedBox.shrink();

    var done = 0;
    for (final k in keys) {
      final meta = data.metaOf(k);
      if (meta != null && meta.isColored(_counts[k] ?? 0)) done++;
    }
    final frac = (done / keys.length).clamp(0.0, 1.0);
    final pct = (frac * 100).round();
    final accent = _groupColors[group] ?? AppColors.primary;
    final complete = done == keys.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFE6D6)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 도 헤더 — 색 점 + 이름 + (완료 뱃지 or 개수) + 퍼센트
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                _groupDisplayName(group),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.gray900,
                ),
              ),
              const SizedBox(width: 6),
              if (complete)
                Icon(Icons.verified, size: 15, color: accent),
              const Spacer(),
              Text(
                '$done/${keys.length}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.gray400,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$pct%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          // 진행 바
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1E9DC),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 11),
          // 시·군·구 칩
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: keys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final key = keys[i];
                final meta = data.metaOf(key);
                final colored =
                    meta != null && meta.isColored(_counts[key] ?? 0);
                final selected = key == _selectedKey;
                return GestureDetector(
                  onTap: () => _selectKey(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent
                          : (colored
                              ? accent.withValues(alpha: 0.13)
                              : const Color(0xFFFAF6EE)),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: selected
                            ? accent
                            : (colored
                                ? accent.withValues(alpha: 0.35)
                                : const Color(0xFFEDE3D2)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (colored) ...[
                          Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: selected ? AppColors.white : accent,
                          ),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          data.keyLabel[key] ?? key,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 12,
                            color: selected
                                ? AppColors.white
                                : (colored ? accent : AppColors.gray500),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
              width: 230,
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
                    '$done/$total · ${(frac * 100).round()}%',
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
    final group = data.keyFocusGroup[key];
    final accent = _groupColors[group] ?? AppColors.primary;

    final isAdminFilled = _adminFilled.contains(key);
    final String statusText;
    if (isAdminFilled) {
      // 어드민이 임의로 채운 지역 — 실제 일기 수가 아니므로 별도 표기.
      statusText = '관리자가 채운 지역이에요';
    } else if (colored) {
      statusText = '채움 완료! · 일기 $count개';
    } else if (count == 0) {
      statusText = '아직 기록이 없어요';
    } else {
      statusText = '일기 $count개 · 채움까지 $remaining개 더!';
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
                              _groupDisplayName(group),
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
                ).then((_) {
                  // 그 지역에서 일기를 삭제하면 색칠이 줄 수 있으니 돌아오면 지도 갱신.
                  if (mounted) _loadCounts();
                });
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
