// 북한(업데이트 예정) 장식 레이어 생성기.
// 남한 변환기(convert.mjs)와 **동일한 투영 상수**를 sigungu-topo.json 에서 재계산해
// 실제 경위도 기반 북한 실루엣/도경계를 같은 viewBox 좌표로 베이크한다.
// DMZ 접합부는 korea_sigungu.json 에서 남한의 실제 북쪽 경계 컨투어를 추출해
// 그 밑(+overlap)으로 밀어 넣어 남한 위에 빈틈없이 붙는다(북한은 남한 뒤에 그림).
//
// 출력:
//  - lib/features/map/data/north_korea_geometry.dart (생성 코드 — 손으로 수정 금지)
//  - tool/mapgen/nk_preview.svg (모양 검증용 미리보기)
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const TOPO = fileURLToPath(new URL('./sigungu-topo.json', import.meta.url));
const SK_JSON = fileURLToPath(new URL('../../assets/map/korea_sigungu.json', import.meta.url));
const OUT_DART = fileURLToPath(new URL('../../lib/features/map/data/north_korea_geometry.dart', import.meta.url));
const OUT_SVG = fileURLToPath(new URL('./nk_preview.svg', import.meta.url));

// ── 1) convert.mjs 와 동일한 투영 상수 재계산 ────────────────────────────
const topo = JSON.parse(readFileSync(TOPO, 'utf8'));
const obj = topo.objects[Object.keys(topo.objects)[0]];
const [sx, sy] = topo.transform.scale;
const [tx, ty] = topo.transform.translate;
const arcs = topo.arcs.map((arc) => {
  let x = 0, y = 0;
  return arc.map(([dx, dy]) => { x += dx; y += dy; return [x * sx + tx, y * sy + ty]; });
});
let minLon = Infinity, maxLon = -Infinity, minLat = Infinity, maxLat = -Infinity;
for (const arc of arcs) for (const [lon, lat] of arc) {
  if (lon < minLon) minLon = lon; if (lon > maxLon) maxLon = lon;
  if (lat < minLat) minLat = lat; if (lat > maxLat) maxLat = lat;
}
const W = 720, margin = 16;
const midLat = (minLat + maxLat) / 2;
const kx = Math.cos((midLat * Math.PI) / 180);
const scale = (W - margin * 2) / ((maxLon - minLon) * kx);
const H = Math.round((maxLat - minLat) * scale + margin * 2);

// 북한 최북단(온성 부근 lat≈43.0)이 밴드 안에 들어오도록 밴드 높이 산출.
const NK_TOP_LAT = 43.01;
const BAND = Math.ceil((NK_TOP_LAT - maxLat) * scale + 10);

// 투영: 남한과 동일 + 최종 좌표는 남한이 BAND 만큼 내려간 좌표계.
function project(lon, lat) {
  const px = margin + (lon - minLon) * kx * scale;
  const py = margin + (maxLat - lat) * scale + BAND;
  return [px, py];
}

// ── 2) 북한 외곽 실루엣 (경위도, 실제 지리 근사) ──────────────────────────
// 한강하구(DMZ 서단)→황해남도 남해안(해주만·강령·옹진반도) 서진→장산곶→서한만
// 북상→신의주→압록강 국경 동북진(중강진 돌출)→혜산→백두산→두만강(무산·회령·
// 온성 최북단 고리)→두만강 하구→동해안 남서진(청진·김책·신포)→동한만(오목)→
// 원산→DMZ 동단.
const NK_COAST = [
  // 한강하구 북안 (동→서) — 개풍·연안 남해안. 강화·김포와는 바다(한강하구)로
  // 분리돼야 하므로 위도 37.78 밑으로 내려가지 않는다(docs/123.jpg 참조).
  [126.66, 37.79], [126.55, 37.84], [126.40, 37.88], [126.24, 37.87],
  [126.10, 37.83], [125.96, 37.79],
  // 황해남도 남해안 (해주만·강령·옹진반도, 동→서)
  [125.86, 37.88], [125.76, 37.97], [125.62, 37.88], [125.55, 37.75],
  [125.40, 37.80], [125.22, 37.70], [125.05, 37.77], [124.92, 37.87],
  [124.70, 38.00], [124.66, 38.12],
  // 서해안 북상 (장산곶→남포→청천강→신의주)
  [124.90, 38.25], [125.10, 38.32], [125.22, 38.45], [125.32, 38.58],
  [125.36, 38.70], [125.20, 38.85], [125.18, 39.05], [125.28, 39.25],
  [125.36, 39.42], [125.45, 39.52], [125.60, 39.58], [125.35, 39.62],
  [125.05, 39.66], [124.78, 39.74], [124.72, 39.62], [124.55, 39.78],
  [124.42, 39.95], [124.37, 40.08],
  // 압록강 국경 (신의주→중강진 돌출→혜산→백두산)
  [124.55, 40.22], [124.78, 40.32], [124.95, 40.46], [125.20, 40.55],
  [125.42, 40.65], [125.62, 40.78], [125.80, 40.86], [126.00, 40.92],
  [126.18, 41.05], [126.32, 41.18], [126.50, 41.35], [126.62, 41.52],
  [126.75, 41.68], [126.90, 41.79], [127.08, 41.62], [127.30, 41.48],
  [127.55, 41.40], [127.85, 41.40], [128.10, 41.39], [128.16, 41.60],
  [128.08, 41.85], [128.05, 42.02],
  // 두만강 국경 (백두산→무산→회령→온성 최북단→하구)
  [128.30, 42.03], [128.60, 42.04], [128.90, 42.03], [129.10, 42.12],
  [129.22, 42.26], [129.45, 42.32], [129.70, 42.44], [129.85, 42.65],
  [129.96, 42.85], [130.05, 42.98], [130.25, 42.85], [130.42, 42.65],
  [130.58, 42.48], [130.68, 42.32],
  // 동해안 남서진 (라선→청진→김책→신포→동한만→원산→DMZ 동단)
  [130.45, 42.25], [130.25, 42.15], [130.05, 42.00], [129.85, 41.85],
  [129.78, 41.72], [129.65, 41.50], [129.50, 41.30], [129.32, 41.05],
  [129.18, 40.85], [129.05, 40.68], [128.85, 40.50], [128.60, 40.32],
  [128.32, 40.10], [128.18, 40.02], [127.95, 39.92], [127.70, 39.86],
  [127.52, 39.72], [127.46, 39.55], [127.42, 39.38], [127.44, 39.22],
  [127.58, 39.12], [127.78, 38.99], [128.02, 38.85], [128.22, 38.73],
  [128.37, 38.62],
];

// 도(道) 경계 + 시·군 느낌 보조선 (경위도 폴리라인 — 실루엣에 클립됨).
const NK_DIVIDERS = [
  // 황해남/황해북
  [[125.95, 38.00], [126.15, 38.35], [126.10, 38.60]],
  // 평안남도 남계(대동강 라인)
  [[125.37, 38.70], [125.95, 38.78], [126.55, 38.72], [126.95, 38.60]],
  // 강원(북) 서계
  [[126.95, 38.60], [127.10, 38.95], [126.90, 39.25]],
  // 강원/함남
  [[126.90, 39.25], [127.42, 39.38]],
  // 평남/평북
  [[125.60, 39.55], [126.05, 39.50], [126.50, 39.70], [126.80, 39.95]],
  // 평남 동계
  [[126.80, 39.95], [126.95, 39.55], [126.90, 39.25]],
  // 평북/자강
  [[125.40, 40.62], [125.85, 40.30], [126.35, 40.15], [126.80, 39.95]],
  // 자강/함남
  [[126.80, 39.95], [127.20, 40.30], [127.55, 40.55]],
  // 자강/량강
  [[127.55, 40.55], [127.60, 41.00], [127.60, 41.45]],
  // 량강 남계
  [[127.55, 40.55], [128.10, 40.60], [128.60, 40.75], [129.00, 41.00]],
  // 량강/함북
  [[128.95, 42.00], [129.00, 41.50], [129.00, 41.00]],
  // 함북/함남 접속
  [[129.00, 41.00], [129.15, 40.85]],
  // 평양직할시 — 닫힌 고리(docs/123.jpg 의 평양 경계 근사)
  [[125.50, 39.10], [125.88, 39.18], [126.10, 39.04], [125.98, 38.86],
    [125.62, 38.82], [125.42, 38.94], [125.50, 39.10]],
  // 시·군 보조선
  [[124.80, 39.95], [125.25, 39.90], [125.60, 40.00]],
  [[124.90, 38.25], [125.40, 38.20], [125.75, 38.05]],
  [[126.30, 40.55], [126.75, 40.40], [127.20, 40.30]],
  [[127.85, 41.10], [128.30, 41.05], [128.60, 40.75]],
  [[129.40, 41.95], [129.45, 41.55]],
  [[126.10, 39.15], [126.55, 39.05]],
  [[125.40, 39.05], [125.80, 39.12], [126.05, 38.95]],
  [[125.60, 40.00], [125.85, 40.30]],
  // 함북 내부(회령·청진 방향)
  [[129.35, 42.25], [129.55, 41.85], [129.70, 41.55]],
  [[129.95, 42.40], [129.80, 42.05]],
  // 량강 내부
  [[128.10, 41.70], [128.35, 41.30], [128.60, 40.75]],
  // 함남 내부
  [[127.55, 40.55], [127.90, 40.20], [128.15, 40.00]],
  [[127.00, 40.00], [127.40, 39.80], [127.55, 39.70]],
  // 평북 내부
  [[125.05, 40.45], [125.40, 40.10], [125.60, 40.00]],
  // 자강 내부
  [[126.20, 41.05], [126.60, 40.70], [126.75, 40.40]],
  // 강원(북) 내부 — 원산 남쪽
  [[127.10, 38.95], [127.50, 38.85], [127.85, 38.78]],
  // 황해북 내부
  [[126.50, 38.70], [126.55, 38.35]],
  // 평남 내부
  [[125.38, 39.45], [125.90, 39.30], [126.30, 39.25]],
];

// ── 3) 남한 북쪽 경계(DMZ) 컨투어 추출 ──────────────────────────────────
const sk = JSON.parse(readFileSync(SK_JSON, 'utf8'));
const BUCKET = 4, OVERLAP = 12;
// 육상 DMZ 서단 — 한강·임진강 합수부(파주 서쪽). 이 서쪽은 바다(한강하구)라
// 남한 경계에 붙이지 않는다: 강화·김포가 북한과 붙어 보이던 원인 수정.
const DMZ_WEST_LON = 126.67;
const [xWest] = project(DMZ_WEST_LON, 37.79);
const [xEast] = project(...NK_COAST[NK_COAST.length - 1]);
const minY = new Map(); // bucket → 남한 최북단 y(json 좌표, 시프트 전)
for (const r of sk.regions) {
  const re = /[ML](-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/g;
  let m;
  while ((m = re.exec(r.d)) !== null) {
    const x = +m[1], y = +m[2];
    const b = Math.round(x / BUCKET);
    if (!minY.has(b) || y < minY.get(b)) minY.set(b, y);
  }
}
const bWest = Math.round(xWest / BUCKET), bEast = Math.round(xEast / BUCKET);
const contour = [];
for (let b = bEast; b >= bWest; b--) { // 동→서 (외곽 path 닫는 방향)
  if (!minY.has(b)) continue;
  // json 좌표 → 최종 좌표(+BAND), 남한 밑으로 OVERLAP 만큼 파묻기
  contour.push([b * BUCKET, minY.get(b) + BAND + OVERLAP]);
}
// 컨투어 단순화: 3버킷마다 1점 (양 끝은 유지)
const dmz = contour.filter((_, i) => i % 3 === 0 || i === contour.length - 1);

// ── 4) 최종 좌표 생성 ───────────────────────────────────────────────────
const outline = [...NK_COAST.map(([lo, la]) => project(lo, la)), ...dmz];
const dividers = NK_DIVIDERS.map((line) => line.map(([lo, la]) => project(lo, la)));
const labelCenter = project(127.0, 40.45);

const f = (v) => Math.round(v * 10) / 10;
const fmtPts = (pts, indent) =>
  pts.map(([x, y]) => `${indent}Offset(${f(x)}, ${f(y)}),`).join('\n');

const dart = `// GENERATED by tool/mapgen/nk_gen.mjs — 손으로 수정하지 말 것.
// 북한(업데이트 예정) 장식 레이어 좌표. 남한 지도(convert.mjs)와 동일한 투영으로
// 실제 경위도(압록강·두만강 국경, 동·서해안)를 근사 베이크했고, 남쪽 변은
// korea_sigungu.json 에서 추출한 남한 실제 북쪽 경계(+${OVERLAP}px 파묻기)라
// 남한 위에 빈틈없이 붙는다(북한은 남한보다 먼저=뒤에 그린다).
import 'dart:ui';

/// 남한 path 를 아래로 내려 위쪽에 북한 밴드를 확보하는 높이(viewBox 단위).
const double kNorthKoreaBand = ${BAND};

/// 북한 외곽 실루엣(최종 viewBox 좌표, 닫힌 폴리곤).
const List<Offset> kNkOutline = [
${fmtPts(outline, '  ')}
];

/// 도 경계 + 시·군 보조 분할선(실루엣에 클립해 그린다).
const List<List<Offset>> kNkDividers = [
${dividers.map((l) => `  [\n${fmtPts(l, '    ')}\n  ],`).join('\n')}
];

/// "업데이트 예정" 배지 중심.
const Offset kNkLabelCenter = Offset(${f(labelCenter[0])}, ${f(labelCenter[1])});
`;
writeFileSync(OUT_DART, dart);

// ── 5) SVG 미리보기 (남한 회색 + 북한 슬레이트 + 분할선) ─────────────────
const skPaths = sk.regions
  .map((r) => `<path d="${r.d}" fill="#f1f4f9" stroke="#8d9eb8" stroke-width="0.8" transform="translate(0 ${BAND})"/>`)
  .join('\n');
const nkD = 'M' + outline.map(([x, y]) => `${f(x)},${f(y)}`).join('L') + 'Z';
const divD = dividers
  .map((l) => `<path d="M${l.map(([x, y]) => `${f(x)},${f(y)}`).join('L')}" fill="none" stroke="#8d9eb8" stroke-width="1.4"/>`)
  .join('\n');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H + BAND}" viewBox="0 0 ${W} ${H + BAND}">
<rect width="100%" height="100%" fill="white"/>
<clipPath id="nk"><path d="${nkD}"/></clipPath>
<path d="${nkD}" fill="#dce4ef" stroke="#6f7f99" stroke-width="2"/>
<g clip-path="url(#nk)">${divD}</g>
${skPaths}
<circle cx="${f(labelCenter[0])}" cy="${f(labelCenter[1])}" r="5" fill="#5b6677"/>
</svg>`;
writeFileSync(OUT_SVG, svg);

console.log('proj:', { minLon: +minLon.toFixed(3), maxLon: +maxLon.toFixed(3), maxLat: +maxLat.toFixed(3), scale: +scale.toFixed(2), H });
console.log('BAND:', BAND, '| outline pts:', outline.length, '| dmz pts:', dmz.length, '| xWest..xEast:', Math.round(xWest), '..', Math.round(xEast));
