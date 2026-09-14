#!/usr/bin/env node
'use strict';
// Гейт: дифференциальная сверка движка ИИ залпов.
//   Z80-оригинал (FOLD/FOLDSP/FOLDBAR.BIN, Z80-эмулятор) и i8080-перевод
//   (src/engine/engine.asm, 8080-эмулятор) получают ОДНО состояние; после
//   вызова сравнивается всё: массивы, MO/MC/FA, все переменные PARM, счётчики
//   сессии; плюс запись вне своих данных и порча кода — у обеих сторон.
//
// node tools/engine_diff/run.js [опции]
//   --sessions N   правдоподобных сессий (партий подряд) на вариант   (12)
//   --random N     случайных состояний на точку входа и вариант     (400)
//   --seed S       зерно                                               (1)
//   --variants a,b salvo,sp,bar
//   --engine-dir D каталог с engine.asm/engine_bss.inc (для мутаций)
//   --quiet        только итог
//   --json F       записать сводку в файл
// Код выхода 0 — гейт пройден; 1 — расхождения, пустая выборка, непройденный
// код или недобор сценариев.
const fs = require('fs');
const path = require('path');
const { I8080Box, Z80Box } = require('./cpu.js');
const { buildOrig, buildMine, buildWide, ROOT } = require('./build.js');
const { Z80Layout, I8080Layout, diff, VARIANT } = require('./state.js');
const { Rng, playSession, randomState, ENTRIES, getv } = require('./model.js');

const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf('--' + n); return i < 0 ? d : args[i + 1]; };
const flag = n => args.includes('--' + n);
const SESSIONS = +opt('sessions', 12);
const RANDOM = +opt('random', 400);
// доля «широких» случаев (залп 6..11 выстрелов, эталон с TX/TY на 11)
const WSESS = +opt('wide-sessions', SESSIONS ? Math.max(1, Math.round(SESSIONS / 3)) : 0);
const WRANDOM = +opt('wide-random', RANDOM ? Math.max(1, Math.round(RANDOM / 4)) : 0);
const SEED = +opt('seed', 1);
const VARIANTS = opt('variants', 'salvo,sp,bar').split(',').filter(Boolean);
const QUIET = flag('quiet');
const PROFILE = flag('profile');     // такты по подпрограммам перевода
const prof = {};                     // вход -> Float64Array(65536)
const OUT = path.join(ROOT, 'build');

// минимум случаев на точку входа (пустая или тощая выборка = провал)
const MIN_CASES = +opt('min-cases', 50);

function log(...a) { if (!QUIET) console.log(...a); }

// ---------------------------------------------------------------- сборка
// каталоги сборки — свои у каждого прогона (mutate.js гоняет их параллельно)
const SUB = path.join(OUT, opt('build-sub', 'diff'));
const orig = buildOrig(path.join(SUB, 'orig'));
const wide = buildWide(path.join(SUB, 'orig_wide'));
const mine = buildMine(path.join(OUT, opt('build-sub', 'diff')), opt('engine-dir', null));
log(`оригиналы: ${Object.entries(orig).map(([v, o]) => `${v} ${o.code.length} Б @${o.org.toString(16).toUpperCase()} (${o.release})`).join('; ')}`);
log(`перевод: код ${mine.codeSize} Б, данные ${mine.bssSize} Б`);

// листинг: адрес -> {line, text, len} для всех команд кода перевода
const insns = new Map();
{
  const lst = fs.readFileSync(path.join(OUT, opt('build-sub', 'diff'), 'engine_test.lst'), 'utf8').split('\n');
  const lo = mine.sym['engine.eng_code_start'], hi = mine.sym['engine.eng_code_end'];
  for (const l of lst) {
    const m = l.match(/^\s*(\d+)\+?\s+([0-9A-F]{4})\s+((?:[0-9A-F]{2} )+)\s*(.*)$/);
    if (!m) continue;
    const a = parseInt(m[2], 16);
    if (a < lo || a >= hi) continue;
    const bytes = m[3].trim().split(/\s+/).length;
    insns.set(a, { line: +m[1], text: m[4].replace(/\s+/g, ' ').trim(), len: bytes, op: mine.code[a - mine.org] });
  }
}
const COND = new Set([0xC2, 0xCA, 0xD2, 0xDA, 0xE2, 0xEA, 0xF2, 0xFA, 0xC4, 0xCC, 0xD4, 0xDC, 0xE4, 0xEC, 0xF4, 0xFC,
  0xC0, 0xC8, 0xD0, 0xD8, 0xE0, 0xE8, 0xF0, 0xF8]);

// ---------------------------------------------------------------- прогон
const hits = new Int32Array(65536);
const taken = new Int32Array(65536), notTaken = new Int32Array(65536);
const condLen = new Int8Array(65536);
for (const [a, x] of insns) if (COND.has(x.op)) condLen[a] = x.len;

const stats = {};      // v -> entry -> {n, bad, cyc:[], vcyc:[], zcyc:[]}
const scen = {};       // v -> tag -> n
const fails = [];      // первые расхождения
let invalid = 0;       // случаи, где оригинал писал вне своих данных (генератор виноват)
let total = 0;
const games = {};      // v -> статистика партий модели
let turnV = 0, turnZ = 0, callsInTurn = [];
let minSP = 0xF000;    // глубина стека перевода

function st(v, e) {
  stats[v] = stats[v] || {};
  return (stats[v][e] = stats[v][e] || { n: 0, bad: 0, cyc: [], vcyc: [], zcyc: [] });
}
function tag(v, t) { scen[v] = scen[v] || {}; scen[v][t] = (scen[v][t] || 0) + 1; }

// 8080 с учётом покрытия команд и ветвлений
function run8080(box, entry, hl, pname) {
  const pr = PROFILE ? (prof[pname] = prof[pname] || new Float64Array(65536)) : null;
  const { I8080 } = require('./cpu.js');
  const cpu = new I8080(box.memory, box.io);
  box.mem[0] = 0x76;
  cpu.sp = 0xF000 - 2; box.mem[cpu.sp] = 0; box.mem[cpu.sp + 1] = 0;
  cpu.regs[4] = (hl >> 8) & 255; cpu.regs[5] = hl & 255;
  cpu.pc = entry;
  box.stray = [];
  let n = 0, cyc = 0, vcyc = 0;
  while (cpu.pc !== 0) {
    const pc = cpu.pc;
    hits[pc]++;
    if (cpu.sp < minSP) minSP = cpu.sp;
    cpu.instruction();
    cyc += cpu.cpu_cycles; vcyc += cpu.vcycles;
    if (pr) pr[pc] += cpu.vcycles;
    const cl = condLen[pc];
    if (cl) { if (cpu.pc === ((pc + cl) & 0xffff)) notTaken[pc]++; else taken[pc]++; }
    if (++n > 60e6) return { timeout: true };
  }
  if (cpu.sp !== 0xF000) return { badsp: true };
  return { instr: n, cycles: cyc, vcycles: vcyc };
}

function variantRun(v) {
  const zlG = new Z80Layout(v, orig[v]), zlW = new Z80Layout(v, wide[v], true);
  const il = new I8080Layout(mine);
  const zb = new Z80Box(), ib = new I8080Box();
  const faLen = VARIANT[v].fasize;
  let salt = 0;

  function callW(S, entry, arg, why) { return callAny(S, entry, arg, why, true); }
  function call(S, entry, arg, why) { return callAny(S, entry, arg, why, false); }
  function callAny(S, entry, arg, why, isWide) {
    const zl = isWide ? zlW : zlG;
    total++;
    callsInTurn.push(entry);
    salt = (salt + 0x9E37) & 0xffff;
    const s0 = salt;
    const canary = a => ((a * 0x3D) ^ (a >> 8) ^ s0 ^ (s0 >> 8)) & 0xff;
    zl.load(zb, S, arg, canary);
    il.load(ib, S, canary);
    const rz = zb.call(zl.entry[entry]);
    const ri = run8080(ib, il.entry[entry], arg, entry);
    const s = st(v, isWide ? entry + '*' : entry);
    s.n++;
    const Sz = zl.extract(zb, S);
    if (rz.timeout || rz.badsp || zb.stray.length || !zl.codeIntact(zb)) {
      // оригинал вышел за свои данные — состояние вне инвариантов
      invalid++;
      if (invalid <= 5) console.log(`!! оригинал вне данных: ${v} ${entry} (${why}) ${rz.timeout ? 'timeout' : ''} ${zb.stray.slice(0, 4).map(x => x.toString(16))}`);
      return Sz;
    }
    const Si = il.extract(ib, S);
    let d = diff(Sz, Si, faLen);
    if (ri.timeout) d = ['i8080: зависание'].concat(d);
    if (ri.badsp) d = ['i8080: стек не сошёлся'].concat(d);
    if (ib.stray.length) d = [`i8080: запись вне данных ${[...new Set(ib.stray)].slice(0, 6).map(x => x.toString(16)).join(',')}`].concat(d);
    if (!il.codeIntact(ib)) d = ['i8080: испорчен код'].concat(d);
    // хвост FA 760..1119 в SALVO/BARRAGE: меняет только fainit (заполняет 1)
    if (faLen < 1120) for (let i = faLen; i < 1120; i++) {
      const want = entry === 'fainit' ? 1 : S.FA[i];
      if (Si.FA[i] !== want) { d.push(`FA[${i}] хвост`); break; }
    }
    if (d.length) {
      s.bad++;
      if (fails.length < 20) fails.push({ v, entry: isWide ? entry + '*' : entry, why, arg, d: d.slice(0, 8) });
    } else if (!ri.timeout) {
      s.cyc.push(ri.cycles); s.vcyc.push(ri.vcycles); s.zcyc.push(rz.cycles);
      turnV += ri.vcycles; turnZ += rz.cycles;
    }
    scenarios(v, entry, S, Sz, arg);
    return Sz;
  }

  const rng = new Rng(SEED * 7919 + v.length * 104729 + v.charCodeAt(0));
  const G = games[v] = { n: 0, end: {}, turns: [], tv: [], tz: [], worst: null };
  const hooks = {
    turn(sn) {
      if (sn >= 3) { G.tv.push(turnV); G.tz.push(turnZ); if (!G.worst || turnV > G.worst.v) G.worst = { v: turnV, calls: callsInTurn.slice() }; }
      turnV = 0; turnZ = 0; callsInTurn = [];
    },
    game(why, sn) { G.n++; G.end[why] = (G.end[why] || 0) + 1; G.turns.push(sn); },
  };
  for (let i = 0; i < SESSIONS; i++) { turnV = 0; turnZ = 0; callsInTurn = []; playSession(v, rng, call, { hooks }); }
  for (let i = 0; i < WSESS; i++) { turnV = 0; turnZ = 0; callsInTurn = []; playSession(v, rng, callW, { hooks, maxNF: 11 }); }
  for (const e of ENTRIES[v]) for (let i = 0; i < RANDOM; i++) {
    const { S, arg } = randomState(v, rng, e);
    call(S, e, arg, 'random');
  }
  for (const e of ['fold', 'pickn', 'explore']) for (let i = 0; i < WRANDOM; i++) {
    const { S, arg } = randomState(v, rng, e, true);
    callW(S, e, arg, 'random');
  }
  // div16 напрямую: частное против точного деления
  let dbad = 0, dn = 0;
  const drng = new Rng(SEED + 99);
  for (let i = 0; i < (flag('fast') ? 200 : 3000); i++) {
    const hl = i < 2000 ? drng.pick([2880, 6000, drng.int(65536), drng.int(7000)]) : drng.int(65536);
    const bc = drng.pick([1 + drng.int(255), 1 + drng.int(65535), 1 + drng.int(3), 32768 + drng.int(32768)]);
    ib.mem.fill(0); ib.mem.set(mine.code, mine.org); ib.allowed.fill(1);
    const cpu = new (require('./cpu.js').I8080)(ib.memory, ib.io);
    ib.mem[0] = 0x76; cpu.sp = 0xEFFE; cpu.pc = il.div16;
    cpu.regs[4] = hl >> 8; cpu.regs[5] = hl & 255; cpu.regs[0] = bc >> 8; cpu.regs[1] = bc & 255;
    let n = 0;
    while (cpu.pc !== 0 && n < 10000) { hits[cpu.pc]++; cpu.instruction(); n++; }
    const q = (cpu.regs[4] << 8) | cpu.regs[5];
    dn++;
    if (q !== Math.floor(hl / bc)) { dbad++; if (dbad < 4) fails.push({ v, entry: 'div16', d: [`${hl}/${bc}=${q}`] }); }
  }
  st(v, 'div16').n += dn; st(v, 'div16').bad += dbad;
}

function scenarios(v, e, S, Sz, arg) {
  const A = S.arr;
  if (e === 'fold') tag(v, (arg & 15) === 0 ? 'fold NS=0' : (arg & 15) > 5 ? 'fold NS>5' : 'fold NS>0');
  if ((e === 'pickn' || e === 'explore') && getv(S, 'vNF') > 5) tag(v, e + ' NF>5');
  if (e === 'kill1') tag(v, 'kill1');
  if (e === 'pickn') { const kl = getv(S, 'vKL'); tag(v, kl === 0 ? 'pickn vKL=0' : kl === 255 ? 'pickn vKL=255' : 'pickn vKL=корабль'); }
  if (e === 'explore') {
    const rim = getv(S, 'vRIM'), sm = S.SMEM[2];
    tag(v, `explore vRIM${rim ? '≠0' : '=0'} SMEMB${sm ? '≠0' : '=0'}`);
  }
  if (e === 'sample') {
    const gg = getv(Sz, 'vGG');
    tag(v, gg >= 3 ? 'sample ≥3 выборок' : gg > 0 ? 'sample 1-2 выборки + marg' : 'sample 0 выборок + marg');
    if (getv(S, 'vRK')) tag(v, 'sample vRK≠0');
  }
  if (e === 'probesel') {
    let h = 0, p = 0;
    for (let k = 1; k <= VARIANT[v].nships; k++) {
      const ph = A.PH[k] & 255, sz = A.SZ[k] & 255;
      if (ph === 0 || ph === sz) continue;
      if (A.CC[k] === 1) h++; else p++;
    }
    if (h) tag(v, 'probesel добор (CC=1)');
    if (p) tag(v, 'probesel зонд');
    if (!h && !p) tag(v, 'probesel без раненых');
  }
  if (getv(S, 'vSEED') === 0 && (e === 'sample' || e === 'probesel')) tag(v, S.jiffy ? 'rnd16 семя из JIFFY' : 'rnd16 семя 0ACE1h');
}

// ---------------------------------------------------------------- отчёт
const t0 = Date.now();
for (const v of VARIANTS) variantRun(v);
const secs = ((Date.now() - t0) / 1000).toFixed(1);

const REQUIRED_SCEN = {
  salvo: ['fold NS=0', 'fold NS>0', 'fold NS>5', 'pickn NF>5', 'explore NF>5', 'kill1', 'pickn vKL=0', 'pickn vKL=корабль', 'pickn vKL=255',
    'explore vRIM≠0 SMEMB=0', 'explore vRIM=0 SMEMB≠0', 'explore vRIM≠0 SMEMB≠0', 'explore vRIM=0 SMEMB=0',
    'sample ≥3 выборок', 'sample 1-2 выборки + marg', 'sample 0 выборок + marg', 'sample vRK≠0',
    'probesel добор (CC=1)', 'probesel зонд', 'rnd16 семя из JIFFY', 'rnd16 семя 0ACE1h'],
};
REQUIRED_SCEN.bar = REQUIRED_SCEN.salvo;
REQUIRED_SCEN.sp = REQUIRED_SCEN.salvo.filter(s => !s.startsWith('probesel'));

let gateOk = true;
const why = [];
if (total === 0) { gateOk = false; why.push('пустая выборка'); }
const pct = (a, q) => { if (!a.length) return '-'; const b = a.slice().sort((x, y) => x - y); return b[Math.min(b.length - 1, Math.floor(q * b.length))]; };
const rows = [];
for (const v of VARIANTS) {
  // обязательные: все точки входа (эталон как есть) и «широкие» fold/pickn/explore
  // (только они касаются TX/TY); прочие широкие — попутные, без минимума
  const WREQ = ['fold*', 'pickn*', 'explore*'];
  const extra = ENTRIES[v].map(e => e + '*').filter(e => !WREQ.includes(e) && (stats[v] || {})[e]);
  for (const e of ENTRIES[v].concat(WREQ, extra, ['div16'])) {
    const s = (stats[v] || {})[e] || { n: 0, bad: 0, cyc: [], vcyc: [], zcyc: [] };
    rows.push({ v, e, n: s.n, bad: s.bad, med: pct(s.vcyc, 0.5), p90: pct(s.vcyc, 0.9), max: pct(s.vcyc, 1), cmed: pct(s.cyc, 0.5), cmax: pct(s.cyc, 1), zmed: pct(s.zcyc, 0.5), zmax: pct(s.zcyc, 1) });
    if (s.bad) { gateOk = false; why.push(`${v}/${e}: ${s.bad} расхождений`); }
    const min = extra.includes(e) ? 0 : WREQ.includes(e) ? Math.ceil(MIN_CASES / 2.5) : MIN_CASES;
    if (s.n < min) { gateOk = false; why.push(`${v}/${e}: всего ${s.n} случаев (< ${min})`); }
  }
  for (const t of REQUIRED_SCEN[v]) if (!((scen[v] || {})[t] > 0)) { gateOk = false; why.push(`${v}: сценарий «${t}» не встретился`); }
}
// покрытие: метки, команды, ветвления
const labelHits = Object.entries(mine.labels).map(([a, n]) => [n, hits[a]]).sort((x, y) => x[0] < y[0] ? -1 : 1);
const deadLabels = labelHits.filter(([, h]) => h === 0);
const deadInsn = [...insns].filter(([a]) => hits[a] === 0);
const branchHalf = [...insns].filter(([a, x]) => condLen[a] && hits[a] && (!taken[a] || !notTaken[a]));
// ветвление, одна сторона которого недостижима по построению, помечено в
// исходнике комментарием «[одна сторона: причина]» — оно не валит гейт
const branchBad = branchHalf.filter(([a, x]) => !x.text.includes('[одна сторона'));
if (branchBad.length) { gateOk = false; why.push(`ветвления с одной стороной: ${branchBad.map(([a, x]) => 'стр.' + x.line).join(', ')}`); }
if (deadLabels.length) { gateOk = false; why.push(`непройденные метки: ${deadLabels.map(x => x[0]).join(', ')}`); }
if (deadInsn.length) { gateOk = false; why.push(`непройденные команды: ${deadInsn.length}`); }

console.log(`\nсверка: ${total} вызовов за ${secs} с, вне инвариантов (отброшено): ${invalid}`);
console.log(`перевод: код ${mine.codeSize} Б, данные ${mine.bssSize} Б, стек до ${0xF000 - minSP} Б (включая адрес возврата вызова)`);
console.log('(* — эталон с TX/TY на 11: залп 6..11 выстрелов)');
console.log('вариант  вход       случаев  расх.   такты Вектора (медиана / p90 / макс)      8080 T (мед/макс)     Z80 T (мед/макс)');
for (const r of rows) console.log(`${r.v.padEnd(8)} ${r.e.padEnd(10)} ${String(r.n).padStart(7)} ${String(r.bad).padStart(6)}   ${String(r.med).padStart(9)} ${String(r.p90).padStart(9)} ${String(r.max).padStart(10)}   ${String(r.cmed).padStart(9)} ${String(r.cmax).padStart(10)}   ${String(r.zmed).padStart(9)} ${String(r.zmax).padStart(10)}`);
console.log('\nход противника целиком (свёртка + распространение + выбор залпа; ходы с SN>=3):');
for (const v of VARIANTS) {
  const G = games[v]; if (!G) continue;
  const sec = x => (x / 3e6).toFixed(2);
  const zsec = x => (x / 3.58e6).toFixed(2);
  console.log(`  ${v}: партий ${G.n} (${Object.entries(G.end).map(([k, n]) => k + ' ' + n).join(', ')}), ходов в партии мед. ${pct(G.turns, 0.5)}; ` +
    `Вектор 3 МГц: мед. ${sec(pct(G.tv, 0.5))} с, p90 ${sec(pct(G.tv, 0.9))} с, макс ${sec(pct(G.tv, 1))} с; ` +
    `MSX Z80 3.58 МГц (только машинный код): мед. ${zsec(pct(G.tz, 0.5))} с, макс ${zsec(pct(G.tz, 1))} с`);
  if (G.worst) { const c = {}; for (const e of G.worst.calls) c[e] = (c[e] || 0) + 1; console.log(`     худший ход: ${Object.entries(c).map(([k, n]) => k + '×' + n).join(' ')}`); }
}
if (!QUIET) {
  console.log('\nсценарии:');
  for (const v of VARIANTS) console.log(`  ${v}: ` + Object.entries(scen[v] || {}).sort().map(([t, n]) => `${t}=${n}`).join('; '));
  console.log(`\nпокрытие меток перевода: ${labelHits.length - deadLabels.length}/${labelHits.length}`);
  console.log('  ' + labelHits.map(([n, h]) => `${n}:${h}`).join(' '));
  console.log(`покрытие команд: ${insns.size - deadInsn.length}/${insns.size}`);
  for (const [a, x] of deadInsn.slice(0, 40)) console.log(`  не исполнена ${a.toString(16)} стр.${x.line}: ${x.text}`);
  const nCond = [...insns].filter(([a]) => condLen[a]).length;
  console.log(`условные переходы с обеими сторонами: ${nCond - branchHalf.length - deadInsn.filter(([a]) => condLen[a]).length}/${nCond}`);
  for (const [a, x] of branchHalf) console.log(`  одна сторона ${a.toString(16)} стр.${x.line}: ${x.text}  (перешёл ${taken[a]}, мимо ${notTaken[a]})`);
}
if (PROFILE) {
  const la = Object.keys(mine.labels).map(Number).sort((a, b) => a - b);
  const owner = a => { let lo = 0, hi = la.length - 1, r = la[0]; while (lo <= hi) { const m = (lo + hi) >> 1; if (la[m] <= a) { r = la[m]; lo = m + 1; } else hi = m - 1; } return mine.labels[r]; };
  console.log('\nпрофиль (такты Вектора по меткам, доля от входа):');
  for (const [e, pr] of Object.entries(prof)) {
    const by = {}; let tot = 0;
    for (let a = 0; a < 65536; a++) if (pr[a]) { const o = owner(a); by[o] = (by[o] || 0) + pr[a]; tot += pr[a]; }
    console.log(`  ${e}: ` + Object.entries(by).sort((x, y) => y[1] - x[1]).slice(0, 10).map(([k, x]) => `${k} ${(100 * x / tot).toFixed(1)}%`).join(', '));
  }
}
if (fails.length) {
  console.log('\nпервые расхождения:');
  for (const f of fails) console.log(`  ${f.v}/${f.entry} (${f.why || ''}) arg=${f.arg}: ${f.d.join(' | ')}`);
}
const summary = { total, invalid, stack: 0xF000 - minSP, rows, scen, codeSize: mine.codeSize, bssSize: mine.bssSize,
  labels: labelHits, deadInsn: deadInsn.map(([a, x]) => x), branchHalf: branchHalf.map(([a, x]) => ({ ...x, taken: taken[a], notTaken: notTaken[a] })), gateOk, why };
if (opt('json', null)) fs.writeFileSync(opt('json'), JSON.stringify(summary, null, 1));
console.log(gateOk ? '\nГЕЙТ ПРОЙДЕН' : '\nГЕЙТ НЕ ПРОЙДЕН: ' + why.join('; '));
process.exit(gateOk ? 0 : 1);
