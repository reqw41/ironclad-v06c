#!/usr/bin/env node
// Автоигрок Ironclad (ядро стенда из vshot.js) на ядре vector06js: сценарий клавиш по кадрам + снимки экрана в PNG.
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
const [ROM, RULES, MAXF, OUTDIR] = process.argv.slice(2);
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
let frames = 0, frc = 0, tacc = 0, steps = 0, hit = null;
function frame(n, stopAt) {
  for (let f = 0; f < n; f++) {
    while (frc < 59904) {
      if (stopAt !== undefined && cpu.pc === stopAt) { hit = stopAt; return; }
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

// ---------------------------------------------------------------- автоигрок
// node tools/autoplay.js build/ironclad.rom <правило 0..6> <кадров> <каталог>
// расстановка -> Z; свой ход (FB=1) -> курсор к первой клетке с CM=0 и пробел; иное ожидание -> пробел.
// Остановка: вернулись в меню после конца партии/матча или кончились кадры.
const out = OUTDIR || "build/auto"; fs.mkdirSync(out, { recursive: true });
const rw = a => rd(a) | (rd(a + 1) << 8);
const need = ["getkey", "L1415a", "S3540", "bFB", "bCX", "bCY", "ARR_CM", "kq_head", "kq_tail", "L2260", "L3857", "game_run"];
for (const n of need) if (L[n] === undefined) throw new Error("нет метки " + n);
let phase = "menu", rules = +(RULES || 3), shots = 0, games = 0, ends = 0, lastShotFrame = 0, snap = 0;
function tap(k) { key(k, true); frame(2); key(k, false); frame(2); }
function qEmpty() { return rd(L.kq_head) === rd(L.kq_tail); }
function ipc() { return cpu.pc === 0x38 ? rw(cpu.sp) : cpu.pc; }   // прерванный адрес
function retaddr() { return cpu.pc === 0x38 ? rw(cpu.sp + 2) : rw(cpu.sp); }
function waiting() { // PC в цикле ожидания клавиши (getkey или опрос 1415/1417)
  const pc = ipc(); return pc >= L.getkey && pc < L.getkey + 12 || pc >= L.L1415a && pc < L.L1415a + 40; }
until_menu: {
  // меню: выбрать правило и начать
  frame(1); let g = 0; while (!(ipc() >= L.getkey && ipc() < L.getkey + 12) && g++ < 2000) frame(1);
  for (let i = 0; i < rules; i++) tap("right");
  frame(20); shot(out + "/menu.png"); tap("space");
}
let lastScr = 0, maxf = +(MAXF || 200000), inMenuAgain = false;
while (frames < maxf) {
  frame(1);
  if (!qEmpty() || !waiting()) continue;
  const fb = rd(L.bFB);
  // вернулись в меню?
  if (ipc() >= L.getkey && ipc() < L.getkey + 12) {
    const ret = retaddr(); // адрес возврата getkey
    if (ret > L.S3540 && ret < L.S3540 + 12) { inMenuAgain = true; break; }
  }
  if (fb === 1) {
    // найти первую клетку с CM=0 змейкой
    let tc = -1, tr = -1;
    for (let r = 0; r < 10 && tc < 0; r++) for (let k = 0; k < 10; k++) { const c = r % 2 ? 9 - k : k;
      const v = rw(L.ARR_CM + (c + 10 * r) * 2); if (v === 0) { tc = c; tr = r; break; } }
    const cx = rd(L.bCX), cy = rd(L.bCY);
    if (tc < 0) { tap("space"); continue; }
    if (cx < tc) tap("right"); else if (cx > tc) tap("left"); else if (cy < tr) tap("down"); else if (cy > tr) tap("up");
    else { tap("space"); shots++; if (shots % 10 === 0) shot(out + "/s" + String(shots).padStart(3, "0") + ".png"); }
  } else {
    // расстановка (L1410 при FB=0 внутри 305) — Z; остальные ожидания — пробел
    const pc = ipc();
    if (pc >= L.L1415a && pc < L.L1415a + 40 && rd(L.bSH) >= 1 && rd(L.bNP) < rd(L.bNK) && rd(L.bTE) === 0 && rd(L.bTP) === 0 && shots === 0) { tap("z"); }
    else { if (ipc() >= L.getkey && ipc() < L.getkey + 12) { const ret = retaddr(); if (ret >= L.L2260 && ret < L.L2260 + 8) { ends++; shot(out + "/end" + ends + ".png"); } }
      tap("space"); }
  }
}
shot(out + "/final.png");
console.log(`правило ${rules}: кадров ${frames}, выстрелов ${shots}, концов партии ${ends}, в меню: ${inMenuAgain}, TE=${rd(L.bTE)} TP=${rd(L.bTP)} TT=${rd(L.bTT)}`);
