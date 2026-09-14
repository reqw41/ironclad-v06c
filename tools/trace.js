#!/usr/bin/env node
// Трасса Ironclad для сверки двух сборок (ядро стенда из vshot.js) на ядре vector06js: сценарий клавиш по кадрам + снимки экрана в PNG.
//   node tools/vshot.js build/ironclad.rom 'w60;k space 4;w30;s build/shot.png;...'
// Команды сценария (через ';'):
//   w N            — прокрутить N кадров
//   k KEY [N]      — нажать клавишу на N кадров (по умолчанию 3) и отпустить, потом 3 кадра паузы
//   d KEY / u KEY  — нажать / отпустить (держать между командами)
//   s FILE         — снимок экрана (PNG, x2) из видеопамяти и палитры, которую ISR льёт в чип (vec_pal_live)
//   p ADDR=VAL     — записать байт (адрес или метка из .sld)
//   m ADDR N       — напечатать N байт памяти
//   until LABEL [N] — крутить до исполнения метки (не больше N кадров, по умолчанию 3000)
// Клавиши: space enter tab left right up down a..z 0..9 slash shift(удерживать вместе: d shift).
// Экран: байт = 0x8000 + плоскость*0x2000 + (столбец<<8) + строка памяти; строка 255 = верх кадра.
"use strict";
const fs = require("fs"), vm = require("vm"), zlib = require("zlib"), path = require("path");
const base = "/Users/boris/projects/vector06js";
const [ROM, RULES, OUTJSON] = process.argv.slice(2);
if (!ROM) { console.error("usage: vshot.js rom 'script'"); process.exit(2); }
const SLD = ROM.replace(/\.rom$/, ".sld");
const L = {};
if (fs.existsSync(SLD)) for (const l of fs.readFileSync(SLD, "latin1").split("\n")) {
  const p = l.split("|"); if (p.length >= 8 && p[6] === "L") { const n = p[7].split(",")[1]; if (n && !(n in L)) L[n] = +p[5]; } }
const g = {}; g.window = g; g.document = { createElement: () => fc(), getElementById: () => fc() };
function fcx() { return { createImageData: () => ({ data: new Uint8ClampedArray(4) }), putImageData() {}, getImageData: () => ({ data: new Uint8ClampedArray(4) }), fillRect() {}, drawImage() {} }; }
function fc() { return { width: 0, height: 0, style: {}, getContext: () => fcx() }; }
g.requestAnimationFrame = () => 0; g.setTimeout = () => 0; g.print = () => 0;
g.console = { log() {}, debug() {}, warn() {}, error() {}, info() {} };
const ctx = vm.createContext(g);
for (const f of ["i8080-js/i8080_trace.js", "i8080-js/i8080_disasm.js", "i8080-js/i8080.js", "src/fili.js", "src/ay.js", "src/fd1793.js", "src/fddimage.js", "src/i8253.js", "src/io.js", "src/keyboard.js", "src/memory.js", "src/sound.js", "src/tv.js"])
  vm.runInContext(fs.readFileSync(base + "/" + f, "utf8"), ctx, { filename: f });
const memory = new ctx.Memory(), keyboard = new ctx.Keyboard(), timer = new ctx.I8253(), ay = new ctx.AY(),
  floppy = new (ctx.Floppy().FD1793)(), io = new ctx.IO(keyboard, timer, memory, ay, floppy);
const cpu = new ctx.I8080(memory, io), tape = { advance: () => {}, sample: 0, reset: () => {} },
  v06c = new ctx.Vector06c(cpu, memory, io, ay, tape);
v06c.bmp = new Uint32Array(576 * 288); v06c.displayFrame = () => {}; v06c.check_breakpoint = () => false; v06c.dbg = null;
const rom = new Uint8Array(fs.readFileSync(ROM));
const img = new Uint8Array(0x10000); img.set(rom.subarray(0, 0x10000 - 0x100), 0x100);
memory.init_from_array(img, 0); memory.detach_boot && memory.detach_boot();
cpu.pc = 0x100; cpu.sp = 0xC000; cpu.iff = false;
const rd = a => memory.bytes[memory.tobank(a & 0xffff)];
const wr = (a, v) => memory.write(a & 0xffff, v & 0xff, false);
const addr = s => (/^[0-9]/.test(s) ? parseInt(s) : (L[s] !== undefined ? L[s] : (() => { throw new Error("нет метки " + s); })()));
// ---- клавиатура
const KM = { tab: [0, 0x01], enter: [0, 0x04], left: [0, 0x10], up: [0, 0x20], right: [0, 0x40], down: [0, 0x80],
  slash: [3, 0x80], space: [7, 0x80] };
for (let i = 0; i < 8; i++) KM[String(i)] = [2, 1 << i];
KM["8"] = [3, 1]; KM["9"] = [3, 2];
"abcdefg".split("").forEach((c, i) => KM[c] = [4, 2 << i]);
"hijklmno".split("").forEach((c, i) => KM[c] = [5, 1 << i]);
"pqrstuvw".split("").forEach((c, i) => KM[c] = [6, 1 << i]);
"xyz".split("").forEach((c, i) => KM[c] = [7, 1 << i]);
function key(k, down) {
  if (k === "shift") { keyboard.ss = down; return; }
  const kb = KM[k]; if (!kb) throw new Error("нет клавиши " + k);
  if (down) keyboard.matrix[kb[0]] |= kb[1]; else keyboard.matrix[kb[0]] &= ~kb[1];
}
// ---- прогон
let frames = 0, frc = 0, tacc = 0, steps = 0, hit = null, seedPC = -1, seedHook = null;
function frame(n, stopAt) {
  for (let f = 0; f < n; f++) {
    while (frc < 59904) {
      if (stopAt !== undefined && cpu.pc === stopAt) { hit = stopAt; return; }
      if (cpu.pc === seedPC && seedHook) seedHook();
      const c = (cpu.instruction(), cpu.vcycles); steps++; frc += c; tacc += c;
      if (tacc > 1) { const tn = tacc >> 1; tacc -= tn * 2; timer.Count(tn); }
      if (cpu.last_opcode === 0xd3) io.commit();
    }
    frc -= 59904; frames++; v06c.irq = true; v06c.checkInterrupt();
  }
}
// ---- снимок
function shot(out) {
  const PAL = L.vec_pal_live !== undefined ? L.vec_pal_live : null;
  const pal = [];
  for (let i = 0; i < 16; i++) { const w = PAL !== null ? rd(PAL + i) : i * 17;
    pal.push([(w & 7) * 255 / 7 | 0, ((w >> 3) & 7) * 255 / 7 | 0, ((w >> 6) & 3) * 255 / 3 | 0]); }
  const S = 2, W = 256 * S, H = 256 * S, buf = Buffer.alloc(W * H * 3);
  for (let sy = 0; sy < 256; sy++) { const mrow = 255 - sy;
    for (let col = 0; col < 32; col++) {
      const b = [rd(0x8000 + (col << 8) + mrow), rd(0xA000 + (col << 8) + mrow), rd(0xC000 + (col << 8) + mrow), rd(0xE000 + (col << 8) + mrow)];
      for (let bit = 7; bit >= 0; bit--) {
        const idx = (((b[0] >> bit) & 1) << 3) | (((b[1] >> bit) & 1) << 2) | (((b[2] >> bit) & 1) << 1) | ((b[3] >> bit) & 1);
        const c = pal[idx], x = col * 8 + (7 - bit);
        for (let dy = 0; dy < S; dy++) for (let dx = 0; dx < S; dx++) { const o = ((sy * S + dy) * W + x * S + dx) * 3; buf[o] = c[0]; buf[o + 1] = c[1]; buf[o + 2] = c[2]; }
      } } }
  const raw = Buffer.alloc(H * (W * 3 + 1));
  for (let y = 0; y < H; y++) { raw[y * (W * 3 + 1)] = 0; buf.copy(raw, y * (W * 3 + 1) + 1, y * W * 3, (y + 1) * W * 3); }
  let T = null; const crc32 = b => { if (!T) { T = new Int32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; T[n] = c; } }
    let c = 0xFFFFFFFF; for (const x of b) c = T[(c ^ x) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; };
  const chunk = (t, d) => { const len = Buffer.alloc(4); len.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t, "latin1"), d]);
    const cr = Buffer.alloc(4); cr.writeUInt32BE(crc32(td)); return Buffer.concat([len, td, cr]); };
  const ih = Buffer.alloc(13); ih.writeUInt32BE(W, 0); ih.writeUInt32BE(H, 4); ih[8] = 8; ih[9] = 2;
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ih), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]));
  console.log(`кадр ${frames}: снимок -> ${out}`);
}

// ---------------------------------------------------------------- трасса
// node tools/trace.js build/ironclad.rom <правило 0..6> out.json
// Детерминированная партия: семена ГСЧ игры и движка фиксируются на старте партии,
// решения — по состоянию игры в момент ожидания клавиши (не по кадрам). В каждой точке
// ожидания пишется: номер, что ждём, значения ВСЕХ переменных/массивов BASIC по именам,
// хэш видимого экрана (плоскости $8000..$DFFF). Две сборки с одинаковой логикой дают
// одинаковую трассу, даже если раскладка памяти и такты разные.
const crypto = require("crypto");
const rw = a => rd(a) | (rd(a + 1) << 8);
const R = +(RULES || 0);
// переменные BASIC: метки b??, s??, ARR_* и граница game_vars_end (по порядку адресов)
const names = Object.keys(L).filter(n => /^(b[A-Z][A-Z0-9_]*|s[A-Z][A-Z0-9]?|ARR_[A-Z]+)$/.test(n) && L[n] >= 0xE000).sort((a, b) => L[a] - L[b]);
const ends = names.map((n, i) => (i + 1 < names.length ? L[names[i + 1]] : L.game_vars_end));
// переменные-указатели на данные в ПЗУ сравниваются по содержимому (адреса сдвигаются вместе с кодом)
const PTR1 = { sRN: 1, sBM: 1 }, PTRARR = { ARR_N: 12 };
function cstr(p) { let t = ""; for (let k = 0; k < 40; k++) { const c = rd(p + k); if (!c) break; t += String.fromCharCode(c); } return t; }
function snapVars() { const o = {}; names.forEach((n, i) => {
  if (n === "bRT") { o[n] = cstr(rw(rw(L.bRT))); return; }                 // запись таблицы правил -> имя набора
  if (PTR1[n]) { o[n] = cstr(rw(L[n])); return; }
  if (PTRARR[n]) { const t = []; for (let k = 0; k < PTRARR[n]; k++) t.push(cstr(rw(L[n] + 2 * k))); o[n] = t.join("|"); return; }
  let b = []; for (let a = L[n]; a < ends[i] && a - L[n] < 400; a++) b.push(rd(a)); o[n] = Buffer.from(b).toString("hex"); });
  // отладка: TRACE_EXTRA="метка:байт,..." — добавить в запись произвольные метки (в сверку не идут, если не заданы в обеих)
  if (process.env.TRACE_EXTRA) for (const e of process.env.TRACE_EXTRA.split(",")) { const [lb, nn] = e.split(":"); const b = [];
    for (let k = 0; k < (+nn || 1); k++) b.push(rd(L[lb] + k)); o["@" + lb] = Buffer.from(b).toString("hex"); }
  return o; }
function vramHash() { const h = crypto.createHash("md5"); const b = Buffer.alloc(0x6000); for (let i = 0; i < 0x6000; i++) b[i] = rd(0x8000 + i); h.update(b); return h.digest("hex").slice(0, 12); }
function ipc() { return cpu.pc === 0x38 ? rw(cpu.sp) : cpu.pc; }
function retaddr() { return cpu.pc === 0x38 ? rw(cpu.sp + 2) : rw(cpu.sp); }
function nm(a) { let best = "?", bv = -1; for (const k in L) if (L[k] <= a && L[k] > bv && !/^[bs][A-Z]|^ARR_/.test(k)) { bv = L[k]; best = k; } return best; }
function tap(k) { key(k, true); frame(2); key(k, false); frame(2); }
function qEmpty() { return rd(L.kq_head) === rd(L.kq_tail); }
function inGetkey() { const p = ipc(); return p >= L.getkey && p < L.getkey + 12; }
// ждёт клавишу = INKEY$ вернул "" (1416..1417, до обработки клавиши L1425); на входе в 1415a
// K$ ещё прежний — там не записывать
function inPoll() { const p = ipc(); return p >= L.L1416 && p < L.L1425; }
const trace = []; let seeded = false, shots = 0, step = 0, endScreens = 0, script = [];
if (R === 3) script = ["r", "right", "down", "space", "u", "slash", "space", "tab", "tab", "z"];   // расстановка вручную, отмена, помощь, TAB
let menuDone = false, finished = false, guard = 0;
// семена: ровно при первом исполнении L195 после меню (после L172 — зерно от таймера, до первого
// RND партии) — подменить на постоянные: ГСЧ игры и движка (vSEED; иначе движок берёт семя из
// счётчика кадров). Ловушка в цикле команд: переход меню->игра проходит внутри нажатия пробела,
// а граница кадра приходится на середину расстановки — число RND до неё зависело бы от тактов.
seedPC = L.L195;
seedHook = () => { if (seeded || !menuDone) return;
  wr(L.rnd_seed, 0x34); wr(L.rnd_seed + 1, 0x12); if (L.ENG_SEED !== undefined) { wr(L.ENG_SEED, 0x78); wr(L.ENG_SEED + 1, 0x56); } seeded = true; };
while (!finished && frames < 400000 && guard++ < 2000000) {
  frame(1);
  if (!qEmpty() || !(inGetkey() || inPoll())) continue;
  const where = inGetkey() ? "getkey<" + nm(retaddr()) : "poll";
  const rec = { i: step++, where, vram: vramHash(), vars: snapVars() };
  if (!menuDone) {
    if (inGetkey() && nm(retaddr()).startsWith("S354")) { for (let i = 0; i < R; i++) tap("right"); menuDone = true; tap("space"); rec.key = "menu"; trace.push(rec); }
    continue;
  }
  if (inGetkey() && nm(retaddr()).startsWith("S354")) { rec.key = "END(меню)"; trace.push(rec); finished = true; break; }
  let k;
  if (script.length && inPoll()) k = script.shift();
  else if (inPoll() && rd(L.bFB) === 1) {
    let tc = -1, tr2 = -1;
    for (let r = 0; r < 10 && tc < 0; r++) for (let q = 0; q < 10; q++) { const c = r % 2 ? 9 - q : q;
      const v = rw(L.ARR_CM + (c + 10 * r) * 2); if (v === 0 || v >= 0x8000) { tc = c; tr2 = r; break; } }   // буй (CM<0) — не стрелял (650: >0)
    const cx = rd(L.bCX), cy = rd(L.bCY);
    if (tc < 0) k = "space";
    else if (cx < tc) k = "right"; else if (cx > tc) k = "left"; else if (cy < tr2) k = "down"; else if (cy > tr2) k = "up";
    else { shots++; k = (shots % 11 === 5 && !rec.didx) ? "x" : "space"; if (shots % 13 === 7) k = "tab"; }
  } else if (inPoll()) k = "z";
  else { const ra = nm(retaddr()); if (ra.startsWith("L226")) { endScreens++; k = endScreens % 4 === 0 ? "space" : "tab"; } else k = "space"; }
  rec.key = k; trace.push(rec); tap(k);
}
if (process.env.TRACE_DBG) { const t = trace.slice(-12).map(r => r.i + " " + r.where + " " + r.key); console.log(t.join("\n")); }
fs.writeFileSync(OUTJSON || "build/trace.json", JSON.stringify({ rules: R, steps: trace.length, shots, frames, trace }));
console.log(`правило ${R}: шагов ${trace.length}, выстрелов ${shots}, кадров ${frames}, конец: ${finished}, семена: ${seeded}`);
