# 디그팟 시그니처 지도 — Claude Code / Flutter 구현 핸드오프

> 작성: 2026.06.05  
> 컨셉: **말랑 지형 (Soft Terrain)** — 대한민국 시·군·구를 따뜻한 점토로 빚어 올린 입체 지형  
> 레퍼런스: `DigPot Signature Map.html` · `DigPot Korea Map.svg` · `DigPot Korea Map.png` · `digpot-map-data.js`

---

## 0. 절대 원칙

| 항목 | 상태 |
|---|---|
| 지역 위치 | 실제 좌표 그대로 (Mercator 투영 → viewBox 720×880 fit) |
| 행정구역 경계 | 시·군·구 단위 전체 (Douglas–Peucker 단순화 + Chaikin 스무딩) |
| 면적 비율 | 유지 |
| 권역 구조 | 6개 (수도권·강원·충청·전라·경상·제주) |
| 제주 위치 | 남쪽 실제 위치 유지 |
| **네트워크** | **없음.** 좌표는 `digpot-map-data.js`에 정적 임베드. 런타임 fetch 금지 |

> 이 지도는 **채색 전의 빈 지도**가 기준 비주얼이다.  
> 색은 사용자의 기록·필터 같은 *이벤트 순간*에만 번진다.

---

## 1. 데이터 구조 — `digpot-map-data.js`

```js
window.DIGPOT_MAP = {
  W: 720, H: 880,   // SVG viewBox 크기
  regions: [
    {
      p: "수도권/수원",   // 권역/이름 key (중복 지명 구분용)
      n: "수원",          // 표시명
      g: "수도권",        // 권역
      k: "gun",           // "metro"(광역시·세종) | "gun"(시·군)
      d: "M280,...Z"      // SVG path (이미 투영+스무딩 완료)
    },
    ...  // 총 183개 조각
  ],
  labels: [
    { n: "수원", g: "수도권", x: 280, y: 274 },  // 라벨 중심 (최대 조각 기준)
    ...  // 총 163개
  ]
}
```

**주요 특징**
- `d` 패스는 **이미 화면 좌표(720×880)로 베이크**됨 → 투영 라이브러리 불필요
- 광역시·세종(`k="metro"`)은 단일 블록, 나머지 도는 시·군 단위 분리
- 창원처럼 구가 여럿인 도시는 여러 조각이 같은 `n`을 공유 → 렌더 시 합산
- `MultiPolygon`은 하나의 `d` 안에 여러 `M...Z` 서브패스 (섬·울릉도 포함)
- `fill-rule: nonzero` 기준

**권역 매핑**
```
수도권: 서울 인천 + 경기 31개 시·군
강원  : 18개 시·군
충청  : 대전 세종 + 충북·충남 25개 시·군
전라  : 광주 + 전북·전남 31개 시·군
경상  : 부산 대구 울산 + 경북·경남 38개 시·군 + 울릉
제주  : 제주시 서귀포시
```

---

## 2. 레이어 시스템 (아래→위)

지도의 입체감은 **7개 레이어 적층**으로 만든다.

| # | 레이어 | 구현 | 목적 |
|---|---|---|---|
| 1 | **Ambient shadow** | 전체 패스, `translate(0,+16)`, Gaussian blur ~6, `#B89274` opacity .38 | 따뜻한 접지 그림자 |
| 2 | **Side wall (두께)** | 전체 패스, `translate(0,+7.2)`, flat `#E6D8C4` | 슬래브 측면 두께 |
| 3 | **Top face** | 시·군별 패스, **전역 linear gradient 공유** | 상단광 매끈한 면 |
| 4 | **Grain (선택)** | feTurbulence mask, opacity ~.05 | 무광 점토 질감 |
| 5 | **Grooves** | highlight stroke `#fff` (op.55) + shadow stroke `#CBB89B` (op.58), width ~1px | 음각 경계선 |
| 6 | **Labels** | 적응형 폰트 크기 (6~11px) | 시·군명 |
| 7 | **Lift overlay** | hover/선택 시·군만 위로 띄워 재드로잉 | 팝업 강조 |

### 핵심: 전역 그라데이션
Top face를 시·군마다 개별 그라데이션으로 채우면 경계에서 밝기 단차 발생.  
반드시 **userSpaceOnUse 전역 그라데이션 하나**를 모든 패스가 공유해야 함.

```
linear, gradientUnits=userSpaceOnUse
x1=W*0.42, y1=110 → x2=W*0.58, y2=820
stops: #FDFAF4(0) → #F6EEE1(0.5) → #ECE1CF(1)   // 웜 기본값
```

Flutter: `ui.Gradient.linear(Offset(W*.42,110), Offset(W*.58,820), [c0,c1,c2], [0,.5,1])`  
→ 하나만 만들어 모든 시·군 Paint에 공유.

---

## 3. 디자인 토큰

```dart
// ── 빈 지도 (웜 기본값) ──────────────────────────
const topFace   = [Color(0xFFFDFAF4), Color(0xFFF6EEE1), Color(0xFFECE1CF)];
const sideWall  = Color(0xFFE6D8C4);
const grooveLo  = Color(0xFFCBB89B);   // shadow groove
const grooveHi  = Color(0xCCFFFFFF);   // highlight groove
const ambientShadow = Color(0x61B89274);
const stageRadial = [Color(0xFFFAF5EC), Color(0xFFF1EADF), Color(0xFFE9E0D2)];
const labelInk  = Color(0xFF9C8C78);
const labelStroke = Color(0x99FFFDF A); // 라벨 페인트 아웃라인

// ── 권역 컬러 (이벤트 시에만 사용) ─────────────────
class GroupColor {
  final Color full, soft, ink;
  const GroupColor(this.full, this.soft, this.ink);
}
const groupColors = {
  '수도권': GroupColor(Color(0xFFFF6B6B), Color(0xFFFFE2DD), Color(0xFFC2412F)),
  '강원'  : GroupColor(Color(0xFF5B9BF0), Color(0xFFDCEBFE), Color(0xFF1E5FBF)),
  '충청'  : GroupColor(Color(0xFFF4B53C), Color(0xFFFCEFD0), Color(0xFF9A6A12)),
  '전라'  : GroupColor(Color(0xFF33C08A), Color(0xFFD2F4E6), Color(0xFF16704E)),
  '경상'  : GroupColor(Color(0xFFA98BF0), Color(0xFFEAE2FC), Color(0xFF5E3FB0)),
  '제주'  : GroupColor(Color(0xFFF47BB4), Color(0xFFFBDEEC), Color(0xFFA63B72)),
};
// 선택(채색) 그라데이션: #FF9A86 → #FF6B6B (브랜드 코랄)
```

---

## 4. 적응형 라벨 시스템

참고 사진과 동일하게 **전체 163개 라벨을 항상 표시**하되,  
이웃 라벨과의 최단 거리로 폰트 크기를 자동 계산한다.

```dart
// 초기화 시 1회 계산 후 캐시
Map<String, double> buildLabelSizes(List<LabelData> labels) {
  final Map<String, double> result = {};
  for (final l in labels) {
    double minD = double.infinity;
    for (final o in labels) {
      if (o == l) continue;
      final dx = l.x - o.x, dy = l.y - o.y;
      final d = sqrt(dx*dx + dy*dy);
      if (d < minD) minD = d;
    }
    double fs;
    if      (minD < 9)  fs = 6.0;
    else if (minD < 13) fs = 6.5;
    else if (minD < 17) fs = 7.5;
    else if (minD < 23) fs = 8.5;
    else if (minD < 32) fs = 9.5;
    else                fs = 10.5;
    // 광역시 최소 보장
    if (metroSet.contains(l.n)) fs = max(fs, 8.5);
    result[l.n] = fs;
  }
  return result;
}
```

**결과 예시**
| 지역 | 최단거리 | 폰트 |
|---|---|---|
| 군포 (경기 밀집) | ~8px | 6px |
| 수원 | ~12px | 6.5px |
| 파주 | ~20px | 8.5px |
| 영월 (강원 넓음) | ~35px | 10.5px |

라벨에 `paint-order:stroke` + 반투명 아이보리 외곽(stroke 2px)으로 가독성 확보.

---

## 5. 상태 & 인터랙션

| 상태 | 비주얼 |
|---|---|
| **Empty (기본)** | 전 지역 웜 아이보리. 채색 없음. = 기준 비주얼 |
| **Hover** | 해당 시·군 면 `#FFF0EC`, 살짝 위로 lift (-1.5px), 플로팅 readout 표시 |
| **Selected** | 코랄 그라데이션 채움 + 흰 라벨 + 더 큰 lift + dropShadow |
| **Group filter** | 해당 권역 `soft` 컬러, 나머지 opacity .42로 디밍 |
| **Record coloring (향후)** | 사용자 기록에 따라 누적 채색 — soft → mid → full |

### Lift(떠오름) 구현
활성 시·군을 별도 오버레이로 재드로잉:
1. side wall (원위치) → 2. top face (`translateY(-(2+depth*2.4))`) → 3. groove → 4. label  
전체 그룹에 `dropShadow(dx:0, dy:5, blur:6, color:#7a4a2e, opacity:.26)` 적용.

### 히트테스트
- SVG: `[data-n]` 어트리뷰트 → pointermove/click 이벤트
- Flutter: `path.contains(localOffset)` (서브패스 포함 자동 처리)
- 광역시(서울·대전 등) hit 영역은 살짝 dilate 권장 (터치 타깃 최소 44px)

---

## 6. Flutter 구현 권장 — CustomPainter

```
KoreaMap (StatefulWidget)
 └─ LayoutBuilder → FittedBox (720×880 유지)
     └─ GestureDetector (onTapUp / onHover)
         └─ CustomPaint (painter: KoreaMapPainter(state))
```

### KoreaMapPainter.paint() 순서 = §2 레이어 1→7

```dart
@override
void paint(Canvas canvas, Size size) {
  // 1. Ambient shadow (translate + blur)
  // 2. Side wall (translate dY, flat color)
  // 3. Top faces (shared gradient, per-city fill if active)
  // 4. Grain (optional, feTurbulence equivalent)
  // 5. Grooves (highlight + shadow stroke, width ~1)
  // 6. Labels (TextPainter, adaptive font size)
  // 7. Lift overlay for hover/selected city
}
```

### 패스 파싱 & 캐시
```dart
// 앱 시작 시 1회, isolate에서 파싱 권장
import 'package:path_drawing/path_drawing.dart';

class MapRegion {
  final String name, group, key;
  final Path path;
  final Offset labelCenter;
  MapRegion({required this.name, required this.group, required this.key,
             required this.path, required this.labelCenter});
}

// digpot-map-data.js → digpot_map_data.dart 변환 후:
final regions = koreaRegionsRaw.map((r) => MapRegion(
  name: r['n'], group: r['g'], key: r['p'],
  path: parseSvgPathData(r['d']),
  labelCenter: Offset(r['x'].toDouble(), r['y'].toDouble()),
)).toList();
```

### 주의
- `k == 'gun'`이고 같은 `n`을 가진 조각이 여럿이면 모두 같은 색으로 칠해야 함
- 섬(울릉도 등)은 해당 시 `d`에 포함 → 선택 시 함께 칠해져야 정상

---

## 7. 스타일 파라미터 (디자인 합의용)

`DigPot Signature Map.html`의 컨트롤 패널과 동일.

| 파라미터 | 범위 | 기본 | 효과 |
|---|---|---|---|
| `depth` | 0/1/2 | 1 | side dY, ambient shY 조정 |
| `warmth` | 쿨/웜/코랄 | 웜 | top face, side, groove 색 변경 |
| `groove` | 0.5/1/1.4 | 1 | 경계선 opacity 배율 |
| `labels` | auto/all/off | auto | 라벨 표시 (auto = 적응형 항상 표시) |
| `grain` | 0/1/1.8 | 0 | 질감 강도 |

---

## 8. 에셋 목록

| 파일 | 용도 |
|---|---|
| `DigPot Signature Map.html` | 인터랙션·컨트롤 완성본 (상태 전부 확인 가능) |
| `DigPot Korea Map.svg` | 자체 포함 벡터 (빈 상태, 183 regions) |
| `DigPot Korea Map.png` | 1440×1760 @2x |
| `digpot-map-data.js` | 183 pieces · 163 labels · 시군구 좌표 (정적 임베드) |

---

## 9. 체크리스트

- [ ] 그라데이션은 반드시 **전역 1개** 공유 (시·군별 개별 금지)
- [ ] side/ambient는 전 지역 한 번에 깔고 그 위에 top face
- [ ] **빈 지도에 권역 색 기본 채움 금지** — 색은 이벤트 때만
- [ ] 같은 `n`의 여러 조각 (창원 구 등) 모두 동일 색
- [ ] 섬 포함 시·도 선택 시 섬도 함께 채색
- [ ] Pretendard 미존재 환경 대비 라벨 font-family 폴백 설정
- [ ] 터치 타깃 최소 44pt (소도시 hit 영역 dilate 권장)

---

*문서 끝.*
