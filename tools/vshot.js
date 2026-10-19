#!/usr/bin/env node
// Headless-стенд Ironclad на ядре vector06js: сценарий клавиш по кадрам + снимки экрана в PNG.
//   node tools/vshot.js build/ironclad.rom 'w60;k space 4;w30;s build/shot.png;...'
// Команды сценария (через ';'):
//   w N            — прокрутить N кадров
//   k KEY [N]      — нажать клавишу на N кадров (по умолчанию 3) и отпустить, потом 3 кадра паузы
//   d KEY / u KEY  — нажать / отпустить (держать между командами)
//   s FILE         — снимок экрана (PNG, x2) из видеопамяти и палитры, которую ISR льёт в чип (vec_pal_live)
//   p ADDR=VAL     — записать байт (адрес или метка из .sld)
//   m ADDR N       — напечатать N байт памяти
//   until LABEL [N] — крутить до исполнения метки (не больше N кадров, по умолчанию 3000)
//   border         — индекс бордюра в порту (io.BorderIndex) и его цвет из vec_pal_live
//   jd BITS / ju BITS — джойстик «П» (порт 6): нажать / отпустить биты (б0 вправо, б1 влево,
//                    б2 вверх, б3 вниз, б6 огонь 1, б7 огонь 2); jk BITS [N] — нажать на N кадров
//                    (по умолчанию 3) и отпустить, потом 3 кадра паузы. Покой порта — FFh, нажатый
//                    бит — 0, как у ядра MiSTer. JOYDEAD=1 — порт молчит (негативный контроль гейта).
// Клавиши: space enter tab left right up down a..z 0..9 slash shift(удерживать вместе: d shift).
// Экран: байт = 0x8000 + плоскость*0x2000 + (столбец<<8) + строка памяти; строка 255 = верх кадра.
"use strict";
const fs = require("fs"), vm = require("vm"), zlib = require("zlib"), path = require("path");
const base = process.env.V06JS || require("path").join(require("os").homedir(), "projects/vector06js");   // ядро эмулятора: github.com/svofski/vector06js
const [ROM, SCRIPT] = process.argv.slice(2);
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
// VFDD=образ.fdd — дискета в приводе A (дисковая версия читает с неё картинки)
if (process.env.VFDD) floppy.loadDsk(0, process.env.VFDD, new Uint8Array(fs.readFileSync(process.env.VFDD)));
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
// ---- джойстик «П»: порт 6, покой FFh, нажатый бит = 0
let joy = 0;
const ioIn = io.input.bind(io);
io.input = p => ((p & 0xff) === 6 ? (process.env.JOYDEAD === "1" ? 0xff : (~joy) & 0xff) : ioIn(p));
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
for (const cmd of (SCRIPT || "w100;s build/shot.png").split(";").map(s => s.trim()).filter(Boolean)) {
  const a = cmd.split(/\s+/);
  { const m = a[0].match(/^([a-z]+)(\d+)$/); if (m) a.splice(0, 1, m[1], m[2]); }
  switch (a[0]) {
    case "w": frame(+a[1]); break;
    case "k": key(a[1], true); frame(+(a[2] || 3)); key(a[1], false); frame(3); break;
    case "jd": joy |= parseInt(a[1]); break;
    case "ju": joy &= ~parseInt(a[1]); break;
    case "jk": joy |= parseInt(a[1]); frame(+(a[2] || 3)); joy &= ~parseInt(a[1]); frame(3); break;
    case "d": key(a[1], true); break;
    case "u": key(a[1], false); break;
    case "s": shot(a[1]); break;
    case "p": { const [x, v] = a[1].split("="); wr(addr(x), parseInt(v)); break; }
    case "m": { const s = addr(a[1]), n = +(a[2] || 16); const out = [];
      for (let i = 0; i < n; i++) out.push(rd(s + i).toString(16).padStart(2, "0")); console.log(`${a[1]} (${s.toString(16)}): ${out.join(" ")}`); break; }
    case "jp": cpu.pc = addr(a[1]); break;
    case "border": { const i = io.BorderIndex(), w = L.vec_pal_live !== undefined ? rd(L.vec_pal_live + i) : -1;
      const rgb = [(w & 7) * 255 / 7 | 0, ((w >> 3) & 7) * 255 / 7 | 0, ((w >> 6) & 3) * 255 / 3 | 0].map(x => x.toString(16).padStart(2, "0")).join("");
      console.log(`кадр ${frames}: бордюр индекс ${i}, цвет ${w} = #${rgb}`); break; }
    case "dump": { const b = Buffer.alloc(0x8000); for (let i = 0; i < 0x8000; i++) b[i] = rd(0x8000 + i); fs.writeFileSync(a[1], b); console.log(`кадр ${frames}: видеопамять -> ${a[1]}`); break; }
    case "pc": { const rw = a => rd(a) | (rd(a + 1) << 8); const nm = a => { let best = null, bv = -1; for (const k in L) if (L[k] <= a && L[k] > bv) { bv = L[k]; best = k; } return best + "+" + (a - bv); };
      const p = cpu.pc === 0x38 ? rw(cpu.sp) : cpu.pc; console.log(`кадр ${frames}: PC ${p.toString(16)} ${nm(p)}; стек: ${[0,2,4,6,8].map(i => nm(rw(cpu.sp + (cpu.pc === 0x38 ? 2 : 0) + i))).join(" ")}`); break; }
    case "until": { hit = null; frame(+(a[2] || 3000), addr(a[1])); console.log(hit !== null ? `кадр ${frames}: ${a[1]} достигнута` : `кадр ${frames}: ${a[1]} НЕ достигнута`); break; }
    default: throw new Error("команда? " + cmd);
  }
}
console.log(`итого кадров ${frames}, инструкций ${steps}, PC=${cpu.pc.toString(16)}`);
