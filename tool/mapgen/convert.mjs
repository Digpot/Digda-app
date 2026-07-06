// 시군구 TopoJSON → 앱용 평면 JSON(viewBox 좌표 path) 변환기.
// 입력: tool/mapgen/sigungu-topo.json (southkorea-maps kostat 2018, simplified)
// 출력: assets/map/korea_sigungu.json
//
// - TopoJSON arc 디코드(quantized delta) → lon/lat 절대좌표
// - 등장방형(equirectangular, midlat 보정) 투영 → viewBox(W×H) fit
// - 시도/권역/광역시 여부/색칠키 계산
// - 좌표 소수 1자리로 축약
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const SRC = fileURLToPath(new URL('./sigungu-topo.json', import.meta.url));
const OUT = fileURLToPath(new URL('../../assets/map/korea_sigungu.json', import.meta.url));
const W = 720; // 목표 viewBox 너비(높이는 종횡비로 계산)

const topo = JSON.parse(readFileSync(SRC, 'utf8'));
const obj = topo.objects[Object.keys(topo.objects)[0]];
const [sx, sy] = topo.transform.scale;
const [tx, ty] = topo.transform.translate;

// 1) arc 디코드: 각 arc → [[lon,lat],...] 절대좌표
const arcs = topo.arcs.map((arc) => {
  let x = 0, y = 0;
  return arc.map(([dx, dy]) => {
    x += dx; y += dy;
    return [x * sx + tx, y * sy + ty];
  });
});

// 음수 인덱스(~i)는 해당 arc의 역방향
function arcPoints(idx) {
  if (idx >= 0) return arcs[idx];
  return arcs[~idx].slice().reverse();
}

// 링(arc 인덱스 배열) → 좌표 시퀀스(중복 조인점 제거)
function ringCoords(ring) {
  const pts = [];
  for (const idx of ring) {
    const seg = arcPoints(idx);
    const start = pts.length ? 1 : 0; // 이어붙일 때 첫 점은 직전 arc 끝점과 중복
    for (let i = start; i < seg.length; i++) pts.push(seg[i]);
  }
  return pts;
}

// geometry → polygons: [[ring,...],...]  (ring = [[lon,lat],...])
function geomPolygons(g) {
  if (g.type === 'Polygon') return [g.arcs.map(ringCoords)];
  if (g.type === 'MultiPolygon') return g.arcs.map((poly) => poly.map(ringCoords));
  return [];
}

// 2) 전체 bbox 계산(투영 fit용)
let minLon = Infinity, maxLon = -Infinity, minLat = Infinity, maxLat = -Infinity;
const decoded = obj.geometries.map((g) => {
  const polys = geomPolygons(g);
  for (const poly of polys) for (const ring of poly) for (const [lon, lat] of ring) {
    if (lon < minLon) minLon = lon; if (lon > maxLon) maxLon = lon;
    if (lat < minLat) minLat = lat; if (lat > maxLat) maxLat = lat;
  }
  return { props: g.properties, polys };
});

const midLat = (minLat + maxLat) / 2;
const kx = Math.cos((midLat * Math.PI) / 180); // 경도 압축 보정
const spanX = (maxLon - minLon) * kx;
const spanY = maxLat - minLat;
const margin = 16;
const scale = (W - margin * 2) / spanX;
const H = Math.round(spanY * scale + margin * 2);

function project(lon, lat) {
  const px = margin + (lon - minLon) * kx * scale;
  const py = margin + (maxLat - lat) * scale; // 위도↑ = 화면 y↓
  return [Math.round(px), Math.round(py)];
}

// 시도/권역/색칠키 메타
const PREFIX_SIDO = {
  '11': '서울', '21': '부산', '22': '대구', '23': '인천', '24': '광주',
  '25': '대전', '26': '울산', '29': '세종', '31': '경기', '32': '강원',
  '33': '충북', '34': '충남', '35': '전북', '36': '전남', '37': '경북',
  '38': '경남', '39': '제주',
};
const METRO = new Set(['11', '21', '22', '23', '24', '25', '26', '29']);
const PREFIX_GROUP = {
  '11': '수도권', '23': '수도권', '31': '수도권',
  '32': '강원',
  '25': '충청', '29': '충청', '33': '충청', '34': '충청',
  '24': '전라', '35': '전라', '36': '전라',
  '21': '경상', '22': '경상', '26': '경상', '37': '경상', '38': '경상',
  '39': '제주',
};

// 통합시 일반구 → 모시(母市): "수원시장안구"→"수원시", "포항시남구"→"포항시"
function parentSi(name) {
  const m = name.match(/^(.+?시).+[구]$/);
  return m ? m[1] : name;
}

function ringArea(ring) {
  let a = 0;
  for (let i = 0, n = ring.length; i < n; i++) {
    const [x1, y1] = ring[i];
    const [x2, y2] = ring[(i + 1) % n];
    a += x1 * y2 - x2 * y1;
  }
  return Math.abs(a) / 2;
}
function ringCentroid(ring) {
  let cx = 0, cy = 0, a = 0;
  for (let i = 0, n = ring.length; i < n; i++) {
    const [x1, y1] = ring[i];
    const [x2, y2] = ring[(i + 1) % n];
    const cross = x1 * y2 - x2 * y1;
    a += cross; cx += (x1 + x2) * cross; cy += (y1 + y2) * cross;
  }
  a /= 2;
  if (Math.abs(a) < 1e-6) { // 면적 0이면 평균점
    const avg = ring.reduce((s, [x, y]) => [s[0] + x, s[1] + y], [0, 0]);
    return [avg[0] / ring.length, avg[1] / ring.length];
  }
  return [cx / (6 * a), cy / (6 * a)];
}

const regions = decoded.map(({ props, polys }) => {
  const code = props.code;
  const prefix = code.slice(0, 2);
  const sido = PREFIX_SIDO[prefix] ?? prefix;
  const metro = METRO.has(prefix);
  const key = metro ? sido : parentSi(props.name);

  // path d 생성 + 최대 링(라벨 중심용) 추적
  let d = '';
  let bestArea = -1, bestRing = null;
  for (const poly of polys) {
    for (const ring of poly) {
      // 투영 후 연속 중복점 제거
      const proj = [];
      for (const [lon, lat] of ring) {
        const p = project(lon, lat);
        const last = proj[proj.length - 1];
        if (!last || last[0] !== p[0] || last[1] !== p[1]) proj.push(p);
      }
      // 닫힘 중복 끝점 제거
      if (proj.length > 1) {
        const f = proj[0], l = proj[proj.length - 1];
        if (f[0] === l[0] && f[1] === l[1]) proj.pop();
      }
      if (proj.length < 3) continue; // 퇴화 링 스킵
      const area = ringArea(proj);
      if (poly[0] === ring && area > bestArea) { bestArea = area; bestRing = proj; }
      d += 'M' + proj.map(([x, y]) => x + ',' + y).join('L') + 'Z';
    }
  }
  const [cx, cy] = bestRing ? ringCentroid(bestRing) : [0, 0];

  return {
    code,
    name: props.name,
    sido,
    group: PREFIX_GROUP[prefix] ?? '기타',
    metro,
    key,
    d,
    cx: Math.round(cx),
    cy: Math.round(cy),
  };
});

const out = { W, H, regions };
mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(out));

// 통계
const keys = new Set(regions.map((r) => r.key));
const bytes = readFileSync(OUT).length;
console.log('regions:', regions.length, '| color keys:', keys.size, '| W×H:', W + '×' + H);
console.log('out bytes:', (bytes / 1024).toFixed(1) + 'KB');
console.log('sample keys:', [...keys].slice(0, 12).join(', '));
