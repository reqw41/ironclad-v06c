'use strict';
// Генераторы состояний для сверки.
//
// 1. playSession — правдоподобные состояния: маленькая модель вражеской
//    стороны BASIC (строки IRONCLAD.BAS 4097-4110 начало партии, 3840-3857
//    ход врага, 4000-4096 выбор залпа, 4300-4339 свёртка и распространение,
//    910-981 учёт попаданий), которая ведёт партии, вызывая движок через
//    переданный call(S, entry, arg) -> S'.  Каждый вызов — случай сверки.
// 2. randomState — случайные состояния в пределах инвариантов, при которых
//    оригинал не выходит за свои данные (иначе сравнивать нечего: он читал бы
//    заголовки массивов BASIC или собственный код).
const { blank, MSX_LEN } = require('./state.js');

class Rng {
  constructor(seed) { this.s = (seed >>> 0) || 0x9e3779b9; }
  u32() { // mulberry32
    let t = (this.s = (this.s + 0x6D2B79F5) >>> 0);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0);
  }
  int(n) { return this.u32() % n; }
  f() { return this.u32() / 4294967296; }
  pick(a) { return a[this.int(a.length)]; }
  chance(p) { return this.f() < p; }
  shuffle(a) { for (let i = a.length - 1; i > 0; i--) { const j = this.int(i + 1); [a[i], a[j]] = [a[j], a[i]]; } return a; }
}

const FLEET = { salvo: [5, 4, 3, 3, 2], sp: [5, 4, 3, 3, 2, 2, 2, 1, 1, 1, 1], bar: [5, 4, 3, 3, 2] };
const ZTOF = { salvo: 5, sp: 7, bar: 5 };

const s16 = x => (x & 0x8000 ? x - 0x10000 : x);
const u16 = x => x & 0xffff;
const P9 = (c, r) => c * 12 + r + 13;

// случайный мусор во всех рабочих переменных (одинаковый для обеих сторон)
function scrambleVars(S, rng) {
  for (const n of Object.keys(S.vars)) {
    if (typeof S.vars[n] === 'number') continue;
    for (let i = 0; i < S.vars[n].length; i++) S.vars[n][i] = rng.int(256);
  }
  S.vars.vFAP = rng.int(1121);
  S.vars.vSOP = rng.int(8);
  // «застоявшиеся» значения, которые оригинал может прочесть как вход, —
  // в пределах, где он не пишет за свои данные
  S.vars.vBX[0] = rng.int(10); S.vars.vBY[0] = rng.int(10);
  const bxw = 13 + rng.int(118); S.vars.vBXW[0] = bxw; S.vars.vBXW[1] = 0;
}
function setv(S, n, v) { const b = S.vars[n]; b[0] = v & 255; if (b.length > 1) b[1] = (v >> 8) & 255; }
function getv(S, n) { const b = S.vars[n]; return b.length > 1 ? b[0] | (b[1] << 8) : b[0]; }

// ============================================================ модель партии
function placeFleet(rng, sizes, rimBias) {
  for (;;) {
    const occ = Array.from({ length: 10 }, () => new Int8Array(10)); // номер корабля
    const near = Array.from({ length: 10 }, () => new Uint8Array(10));
    const ships = [];
    let ok = true;
    for (let k = 0; k < sizes.length && ok; k++) {
      const L = sizes[k];
      let placed = false;
      for (let t = 0; t < 400 && !placed; t++) {
        const o = rng.int(2);
        const x = rng.int(o ? 10 : 11 - L), y = rng.int(o ? 11 - L : 10);
        const cells = [];
        for (let i = 0; i < L; i++) cells.push(o ? [x, y + i] : [x + i, y]);
        if (cells.some(([u, v]) => near[u][v])) continue;
        if (rimBias && t < 200 && !cells.some(([u, v]) => u === 0 || u === 9 || v === 0 || v === 9)) continue;
        for (const [u, v] of cells) {
          occ[u][v] = k + 1;
          for (let du = -1; du <= 1; du++) for (let dv = -1; dv <= 1; dv++) {
            const a = u + du, b = v + dv;
            if (a >= 0 && a < 10 && b >= 0 && b < 10) near[a][b] = 1;
          }
        }
        ships.push(cells); placed = true;
      }
      if (!placed) ok = false;
    }
    if (ok) return { occ, ships };
  }
}

// Сессия: несколько партий подряд (счётчики SMEM и семя живут между ними).
// call(S, entry, arg, tag) -> S'  (S' — состояние после вызова оригинала)
function playSession(v, rng, call, opts = {}) {
  const ZT = ZTOF[v], SZ = FLEET[v], NK = SZ.length;
  let S = blank(v);
  scrambleVars(S, rng);
  S.jiffy = rng.chance(0.2) ? 0 : rng.int(65536);
  if (rng.chance(0.5)) setv(S, 'vSEED', 0);
  // сессионные счётчики: как после power-on (138) или «со стажем»
  if (rng.chance(0.5)) { S.SMEM[0] = 0; S.SMEM[1] = 0; S.SMEM[2] = 0; }
  else { S.SMEM[0] = rng.int(15); S.SMEM[1] = Math.min(255, S.SMEM[0] * (8 + rng.int(12))); }
  const games = opts.games || (1 + rng.int(3));
  const hooks = opts.hooks || { turn() {}, game() {} };
  const maxNF = opts.maxNF || 5;
  for (let g = 0; g < games; g++) S = playGame(v, rng, call, S, ZT, SZ, NK, hooks, maxNF);
  return S;
}

function playGame(v, rng, call, S, ZT, SZ, NK, hooks, maxNF) {
  const A = S.arr;
  const rimBias = rng.chance(0.35);
  const { occ } = placeFleet(rng, SZ, rimBias);
  const TT = SZ.reduce((a, b) => a + b, 0);
  // DIM обнуляет массивы: игровые массивы в начале партии — нули (MG — мусор
  // прошлой партии, оставляем)
  A.PM.fill(0); A.BZ.fill(0); A.PH.fill(0); A.HK.fill(0); A.TX.fill(0); A.TY.fill(0);
  for (let k = 1; k <= NK; k++) A.SZ[k] = SZ[k - 1];
  const PD = new Array(ZT + 1).fill(0), CT = new Array(ZT + 1).fill(0);
  // 4097: OS/CT/CC/PD; 4107: SMEMB из счётчиков
  let t = 0;
  for (let k = 1; k <= ZT; k++) { A.OS[k] = t; CT[k] = 20 * (11 - SZ[k - 1]); A.CC[k] = CT[k]; t += CT[k]; PD[k] = 0; }
  {
    const T2 = S.SMEM[0]; S.SMEM[2] = 0;
    if (T2 >= 2) { const T3 = T2 === 2 ? 63 : 55; if (S.SMEM[1] * 100 > T3 * TT * T2) S.SMEM[2] = 1; }
  }
  S = call(S, 'fainit', rng.int(65536), 'fainit');
  let SN = 0, FP = 0;
  // «личность — край» (в этой версии BASIC R8 всегда 0; включаем для покрытия)
  const R8 = rng.chance(0.3) ? 1 : 0;
  // 4099-4102: начальное покрытие MC = RU(C)+RU(R)
  const RU = [];
  for (let i = 0; i <= 9; i++) {
    let T = 0;
    for (let k = 1; k <= ZT; k++) {
      let W = i; if (W > 10 - SZ[k - 1]) W = 10 - SZ[k - 1];
      let T3 = i - SZ[k - 1] + 1; if (T3 < 0) T3 = 0;
      if (W >= T3) T += W - T3 + 1;
    }
    RU[i] = T;
  }
  for (let c = 0; c <= 9; c++) for (let r = 0; r <= 9; r++) S.MC[P9(c, r)] = (RU[c] + RU[r]) & 255;
  let BL = NK - ZT, TP = 0;
  // NF: у MSX TX(4) — до 5 выстрелов; у Вектора TX[11] — до 11 (SALVO PLUS, SV=1)
  let NF = maxNF > 5 && rng.chance(0.7) ? 6 + rng.int(maxNF - 5) : 1 + rng.int(Math.min(5, maxNF));
  const shrink = rng.chance(0.5);
  let NS = 0;
  for (let turn = 0; turn < 200 && TP < TT; turn++) {
    const A = S.arr;
    // 3840
    SN++;
    if (shrink && NF > 1 && rng.chance(0.08)) NF--;
    if (FP === 1) {
      FP = 0;
      const r = foldReport(S, v, rng, call, ZT, NK, PD, CT, BL, NS);
      S = r.S;
    }
    // 3843: выбор залпа
    const sel = selectShots(S, v, rng, call, ZT, NK, SN, NF, BL, PD, R8);
    S = sel.S; NS = sel.NS;
    const B = S.arr;
    for (let k = 1; k <= ZT; k++) B.HK[k] = 0;
    // 3844: выстрелы
    for (let nc = 0; nc < NS; nc++) {
      const fx = s16(B.TX[nc]), fy = s16(B.TY[nc]);
      if (fx < 0 || fx > 9 || fy < 0 || fy > 9) { hooks.game('выстрел вне поля', SN); return S; } // BASIC упал бы
      const sh = occ[fx][fy];
      const ci = fx + 10 * fy;
      if (!sh) { B.PM[ci] = u16(1 + 4 * SN); continue; }
      B.PM[ci] = u16(2 + 4 * SN);
      B.PH[sh] = u16(B.PH[sh] + 1); TP++;
      if (sh <= ZT) B.HK[sh] = u16(B.HK[sh] + 1);
      if (B.PH[sh] >= B.SZ[sh] && sh > ZT && B.PH[sh] === B.SZ[sh]) BL--;
      if (TP >= TT) break;
    }
    if (TP < TT) FP = 1;
    hooks.turn(SN);
  }
  hooks.game(TP >= TT ? 'флот потоплен' : 'лимит ходов', SN);
  // 4103-4105: конец партии — счётчики сессии
  if (S.SMEM[0] < 14) {
    let T3 = 0;
    for (let c = 0; c < 10; c++) for (let r = 0; r < 10; r++) if (occ[c][r] && (c === 0 || c === 9 || r === 0 || r === 9)) T3++;
    S.SMEM[0]++; S.SMEM[1] = Math.min(255, S.SMEM[1] + T3);
  }
  return S;
}

// 4301-4339
function foldReport(S, v, rng, call, ZT, NK, PD, CT, BL, NS) {
  S = call(S, 'fold', (rng.int(4096) << 4) | NS, 'fold');
  let J = 0;
  for (;;) {
    let FL = 0;
    for (let K = 1; K <= ZT; K++) {
      const A = S.arr;
      if (PD[K] > 0 || A.CC[K] !== 1) continue;
      const LK = A.SZ[K], W = 11 - LK;
      for (let I = A.OS[K]; I <= A.OS[K] + CT[K] - 1; I++) if (S.FA[I] === 1) { J = I - A.OS[K]; break; }
      const T2 = J; let O, X, Y, j = J;
      if (j < 10 * W) { O = 0; Y = Math.floor(j / W); X = j - Y * W; } else { j -= 10 * W; O = 1; X = Math.floor(j / W); Y = j - X * W; }
      PD[K] = T2 + 1; FL = 1;
      const A1 = X - 1, B1 = Y - 1, A2 = O === 0 ? X + LK : X + 1, B2 = O === 0 ? Y + 1 : Y + LK;
      for (let U = A1; U <= A2; U++) for (let V = B1; V <= B2; V++) {
        if (U < 0 || U > 9 || V < 0 || V > 9) continue;
        for (let KN = 1; KN <= ZT; KN++) if (KN !== K) S = call(S, 'kill1', KN * 256 + U * 16 + V, 'kill1');
        if (O === 0 && V === Y && U >= X && U < X + LK) continue;
        if (O === 1 && U === X && V >= Y && V < Y + LK) continue;
        const ci = U + 10 * V;
        if (S.arr.PM[ci] === 0 && S.arr.BZ[ci] !== 3) S.arr.BZ[ci] = 3;
      }
    }
    if (!FL) break;
  }
  if (BL > 0) return { S };
  for (let C = 0; C <= 9; C++) for (let R = 0; R <= 9; R++) {
    const ci = C + 10 * R;
    if (S.MC[P9(C, R)] !== 0 || S.arr.BZ[ci] === 3 || S.arr.PM[ci] !== 0) continue;
    S.arr.BZ[ci] = 3;
  }
  return { S };
}

// 4000-4096
function selectShots(S, v, rng, call, ZT, NK, SN, NF, BL, PD, R8) {
  const A = S.arr;
  if (SN < 3) { // 4093-4096: случайное начало (без движка)
    for (let T = 0; T < NF; T++) {
      let T2 = 0, C, R;
      for (;;) {
        T2++; C = rng.int(10); R = rng.int(10);
        if (A.PM[C + 10 * R] !== 0) continue;
        if (T2 < 30 && ((C + R + SN) & 1) === 1) continue;
        if (R8 === 1 && T2 < 25 && C > 0 && C < 9 && R > 0 && R < 9) continue;
        let CF = 0;
        for (let j = 0; j < T; j++) if (Math.abs(s16(A.TX[j]) - C) + Math.abs(s16(A.TY[j]) - R) < 3) CF = 1;
        if (CF && T2 < 40) continue;
        break;
      }
      A.TX[T] = C; A.TY[T] = R;
    }
    return { S, NS: NF };
  }
  let KM = 0;
  for (let K = 1; K <= ZT; K++) if (A.PH[K] > 0 && A.PH[K] < A.SZ[K]) KM = 1;
  if (!KM) { // 4070-4071
    setv(S, 'vRD', rng.int(8)); setv(S, 'vNF', NF); setv(S, 'vRIM', R8 === 1 && SN < 14 ? 1 : 0);
    S = call(S, 'explore', rng.int(65536), 'explore');
    return { S, NS: NF };
  }
  let NA = 0, T5 = 0, KL = 0;
  for (let K = 1; K <= NK; K++) if (A.PH[K] < A.SZ[K]) { NA++; KL = K; if (K <= ZT) T5 += A.CC[K] * A.SZ[K]; }
  if (NA === 1 && A.PH[KL] > 0) setv(S, 'vKL', KL);
  if (v !== 'sp') { // 4005-4009: вердикт «флот у края»
    let T2 = 0, T3 = 0, km = 0;
    for (let K = 1; K <= ZT; K++) {
      if (PD[K] === 0 || A.PH[K] === 0 || A.SZ[K] > 3 || A.SZ[K] < 2) continue;
      const LK = A.SZ[K], W = 11 - LK; let J = PD[K] - 1, O, X, Y;
      if (J < 10 * W) { O = 0; Y = Math.floor(J / W); X = J - Y * W; } else { J -= 10 * W; O = 1; X = Math.floor(J / W); Y = J - X * W; }
      if (A.PH[K] >= A.SZ[K]) km++;
      for (let t4 = 0; t4 < LK; t4++) { const U = X + t4 * (1 - O), V = Y + t4 * O; T3++; if (U === 0 || U === 9 || V === 0 || V === 9) T2++; }
    }
    setv(S, 'vRK', km > 1 && T2 * 5 >= T3 * 3 ? 1 : 0);
  }
  let E9 = 0;
  if (NA > 1 && BL === 0 && T5 <= NF + NF) { setv(S, 'vKL', 255); E9 = 1; }
  if (v !== 'sp') {
    S = call(S, NA === 1 || E9 ? 'sample' : 'probesel', 0, 'kill');
  } else {
    S = call(S, 'sample', 0, 'kill');
    if (!E9) {
      const B = S.arr; let kl = 0, t5 = 32767;
      for (let K = 1; K <= ZT; K++) if (B.PH[K] > 0 && B.PH[K] < B.SZ[K] && B.CC[K] > 0 && B.CC[K] < t5) { t5 = B.CC[K]; kl = K; }
      if (kl > 0 && t5 === 1) setv(S, 'vKL', kl);
    }
  }
  setv(S, 'vNF', NF);
  S = call(S, 'pickn', rng.int(65536), 'kill');
  return { S, NS: NF };
}

// ============================================================ случайные
const ENTRIES = { salvo: ['fold', 'kill1', 'explore', 'pickn', 'marg', 'sample', 'fainit', 'probesel'],
  sp: ['fold', 'kill1', 'explore', 'pickn', 'marg', 'sample', 'fainit'] };
ENTRIES.bar = ENTRIES.salvo;

function randomState(v, rng, entry, wide) {
  const S = blank(v), A = S.arr, ZT = ZTOF[v];
  scrambleVars(S, rng);
  // флот: перестановка настоящего (сумма CT та же — FA не выходит за буфер)
  const tracked = rng.shuffle(FLEET[v].slice(0, ZT));
  const sizes = tracked.concat(FLEET[v].slice(ZT));
  for (let k = 1; k < A.SZ.length; k++) A.SZ[k] = k <= sizes.length ? sizes[k - 1] : rng.int(65536);
  A.SZ[0] = rng.int(65536);
  let t = 0;
  for (let k = 1; k <= ZT; k++) { A.OS[k] = t; t += 20 * (11 - A.SZ[k]); }
  A.OS[0] = rng.int(65536);
  // FA: плотность живых по кораблю; CC = число живых (инвариант fold)
  for (let i = 0; i < 1120; i++) S.FA[i] = rng.int(2);
  for (let k = 1; k <= ZT; k++) {
    const ct = 20 * (11 - A.SZ[k]);
    const p = rng.pick([0, 0.003, 0.01, 0.03, 0.1, 0.3, 0.7, 1]);
    let cc = 0;
    for (let i = 0; i < ct; i++) { const f = rng.f() < p ? 1 : 0; S.FA[A.OS[k] + i] = f; cc += f; }
    if (rng.chance(0.15) && cc === 0) { const i = rng.int(ct); S.FA[A.OS[k] + i] = 1; cc = 1; }
    A.CC[k] = cc;
  }
  A.CC[0] = rng.int(65536);
  // MC: либо честное покрытие живыми кандидатами, либо шум
  if (rng.chance(0.6)) {
    S.MC.fill(0);
    for (let k = 1; k <= ZT; k++) {
      const L = A.SZ[k], W = 11 - L;
      for (let j = 0; j < 20 * W; j++) {
        if (!S.FA[A.OS[k] + j]) continue;
        let x, y, o;
        if (j < 10 * W) { o = 0; y = Math.floor(j / W); x = j - y * W; } else { const q = j - 10 * W; o = 1; x = Math.floor(q / W); y = q - x * W; }
        for (let i = 0; i < L; i++) S.MC[P9(x + (o ? 0 : i), y + (o ? i : 0))]++;
      }
    }
  } else for (let i = 0; i < 144; i++) S.MC[i] = rng.pick([0, 0, rng.int(8), rng.int(40), rng.int(256)]);
  // MO / vST
  const st = rng.pick([0, 1, 254, 255, rng.int(256)]);
  setv(S, 'vST', st);
  const mop = rng.f();
  for (let i = 0; i < 144; i++) S.MO[i] = rng.f() < mop ? (rng.chance(0.5) ? st : rng.int(256)) : 0;
  // PM: обстрел (младший байт бывает 0 при ненулевом старшем)
  const fire = rng.pick([0, 0.1, 0.3, 0.6, 0.9, 0.98, 1]);
  for (let i = 0; i < 100; i++) A.PM[i] = rng.f() < fire ? rng.pick([1, 2, 5, 6, 0x100, rng.int(65535) + 1]) : 0;
  for (let i = 0; i < 100; i++) A.BZ[i] = rng.chance(0.3) ? rng.pick([1, 2, 3, 3, 0x103, 0x300, rng.int(65536)]) : 0;
  // MG: разные режимы
  const mgm = rng.int(4);
  for (let i = 0; i < 144; i++) {
    if (mgm === 0) A.MG[i] = u16(rng.int(3000) - 20);
    else if (mgm === 1) A.MG[i] = rng.int(65536);
    else if (mgm === 2) A.MG[i] = rng.chance(0.5) ? 0xffff : rng.int(64);
    else A.MG[i] = rng.pick([0xffff, 0xfff7, 0, 1, 0x7fff, 0x8000, rng.int(200)]);
  }
  for (let k = 0; k < A.PH.length; k++) A.PH[k] = k >= 1 && k <= sizes.length ? rng.pick([0, 0, 1, rng.int(A.SZ[k] + 1), A.SZ[k], A.SZ[k] + 1]) : rng.int(65536);
  for (let k = 0; k < A.HK.length; k++) A.HK[k] = k >= 1 && k <= ZT ? rng.pick([0, 0, 1, rng.int(A.SZ[k] + 1), rng.int(8)]) | (rng.chance(0.1) ? 0x100 : 0) : rng.int(65536);
  for (let i = 0; i < 11; i++) { A.TX[i] = u16(rng.int(13) - 1) | (rng.chance(0.1) ? 0x300 : 0); A.TY[i] = u16(rng.int(13) - 1); }
  setv(S, 'vKL', rng.pick([0, 0, 255, 1 + rng.int(ZT)]));
  setv(S, 'vRK', rng.pick([0, 0, 1, rng.int(256)]));
  setv(S, 'vRD', rng.int(256));
  setv(S, 'vRIM', rng.pick([0, 0, 1, rng.int(256)]));
  setv(S, 'vNF', wide ? 6 + rng.int(6) : rng.pick([0, 1, 2, 3, 4, 5]));
  S.SMEM[0] = rng.int(256); S.SMEM[1] = rng.int(256); S.SMEM[2] = rng.pick([0, 0, 1, rng.int(256)]);
  S.jiffy = rng.chance(0.2) ? 0 : rng.int(65536);
  if (rng.chance(0.2)) setv(S, 'vSEED', 0);
  // BARRAGE probesel: CC=0 у раненого корабля — у оригинала вечный цикл
  // (6000/0 повторным вычитанием); такие состояния не генерируем
  if (v === 'bar' && entry === 'probesel')
    for (let k = 1; k <= ZT; k++) if (A.PH[k] !== 0 && (A.PH[k] & 255) !== (A.SZ[k] & 255) && A.CC[k] === 0) {
      S.FA[A.OS[k]] = 1; A.CC[k] = 1;
    }
  // CC как чистое число (не счётчик для pldraw) можно портить: marg делит на
  // него (CC > 2880 даёт вес 1), probesel сравнивает с 1 и 2n
  if (entry !== 'sample' && rng.chance(0.15))
    for (let k = 1; k <= ZT; k++) if (rng.chance(0.5)) A.CC[k] = rng.pick([rng.int(65536), 256 + rng.int(3000), 2881 + rng.int(1000)]);
  let arg = rng.int(65536);
  if (entry === 'fold') arg = (arg & 0xfff0) | (wide ? 6 + rng.int(6) : rng.int(6));
  if (entry === 'kill1') arg = ((1 + rng.int(ZT)) << 8) | rng.int(256);
  return { S, arg };
}

module.exports = { Rng, playSession, randomState, ENTRIES, FLEET, ZTOF, setv, getv, s16 };
