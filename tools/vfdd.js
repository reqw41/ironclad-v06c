#!/usr/bin/env node
// Headless-стенд дисковой версии на ядре vector06js: загрузка С ДИСКЕТЫ через штатное ПЗУ Вектора
// (boots.bin из vector06js/boot), контроллер ВГ93 — fd1793.js. Сценарий и снимки — как у vshot.js.
//   node tools/vfdd.js build/ironclad.fdd 'boot;until bt_splash;s build/disk/splash.png'
// Команды сценария (через ';'):
//   boot           — ПЗУ читает загрузочный сектор (дескриптор), затем БЛК+СБР: вход в $0100
//   w N            — прокрутить N кадров
//   k KEY [N]      — нажать клавишу на N кадров (по умолчанию 3) и отпустить, потом 3 кадра паузы
//   s FILE         — снимок экрана (PNG x2): видеопамять + палитра, которую программа ЗАПИСАЛА в порт
//                    $0C (индекс — порт $02), бордюр — вокруг поля 256x256
//   until LABEL [N] — крутить до исполнения метки/адреса (не больше N кадров, по умолчанию 3000);
//                    печатает кадр с долями (кадр = 59904 такта) и число прочитанных секторов
//   t LABEL        — то же, что until, но ещё печатает время от прошлого t/until
//   m ADDR N       — напечатать N байт памяти;  pc — где сейчас PC
//   cmp FILE ADDR [OFS [LEN]] — сверить память с ADDR с файлом (с байта OFS, LEN байт; по умолчанию весь)
// Метки — из .sld: по умолчанию build/disk/boot.sld (или boot_pictest.sld для pictest.fdd) и
// build/ironclad.sld; свой список — переменная VFDD_SLD=a.sld,b.sld. Метка модуля — res.fdd_read.
"use strict";
const fs = require("fs"), vm = require("vm"), zlib = require("zlib"), path = require("path");
const base = "/Users/boris/projects/vector06js";
const [FDD, SCRIPT] = process.argv.slice(2);
if (!FDD) { console.error("usage: vfdd.js image.fdd 'script'"); process.exit(2); }
const ROOT = path.dirname(__dirname);
const slds = (process.env.VFDD_SLD ? process.env.VFDD_SLD.split(",") :
  [path.join(ROOT, "build/disk", /pictest/.test(FDD) ? "boot_pictest.sld" : "boot.sld"), path.join(ROOT, "build/ironclad.sld")]);
const L = {};
for (const f of slds) if (fs.existsSync(f)) for (const l of fs.readFileSync(f, "latin1").split("\n")) {
  const p = l.split("|"); if (p.length >= 8 && p[6] === "L") { const q = p[7].split(","); const n = (q[0] ? q[0] + "." : "") + q[1];
    if (q[1] && !(n in L)) L[n] = +p[5]; } }
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
// ---- штатное ПЗУ + дискета в приводе A
memory.attach_boot(new Uint8Array(fs.readFileSync(base + "/boot/boots.bin")));
floppy.loadDsk(0, FDD, new Uint8Array(fs.readFileSync(FDD)));
cpu.pc = 0; cpu.sp = 0; cpu.iff = false;
let nread = 0, lastRead = -1;
{ const oc = floppy.command.bind(floppy);
  floppy.command = function (v) { if ((v >> 4) === 8 || (v >> 4) === 9) { nread++; lastRead = frames; } return oc(v); }; }
// ---- палитра, как её пишет программа (порт $02 = индекс, $0C = цвет), и бордюр
const pal = new Array(16).fill(0); let pb = 0, cw = 0;
{ const ro = io.realoutput.bind(io);
  io.realoutput = function (port, w8) { if (port === 2) pb = w8; else if (port === 0) cw = w8;
    else if (port >= 0x0c && port <= 0x0f) pal[pb & 15] = w8; return ro(port, w8); }; }
const rd = a => memory.bytes[memory.tobank(a & 0xffff)];
const addr = s => (/^[0-9]/.test(s) ? parseInt(s) : (L[s] !== undefined ? L[s] : (() => { throw new Error("нет метки " + s); })()));
// ---- клавиатура (как vshot.js)
const KM = { tab: [0, 0x01], enter: [0, 0x04], left: [0, 0x10], up: [0, 0x20], right: [0, 0x40], down: [0, 0x80],
  slash: [3, 0x80], space: [7, 0x80] };
for (let i = 0; i < 8; i++) KM[String(i)] = [2, 1 << i];
KM["8"] = [3, 1]; KM["9"] = [3, 2];
"abcdefg".split("").forEach((c, i) => KM[c] = [4, 2 << i]);
"hijklmno".split("").forEach((c, i) => KM[c] = [5, 1 << i]);
"pqrstuvw".split("").forEach((c, i) => KM[c] = [6, 1 << i]);
"xyz".split("").forEach((c, i) => KM[c] = [7, 1 << i]);
function key(k, down) {
  const kb = KM[k]; if (!kb) throw new Error("нет клавиши " + k);
  if (down) keyboard.matrix[kb[0]] |= kb[1]; else keyboard.matrix[kb[0]] &= ~kb[1];
}
// ---- прогон: кадр = 59904 такта, прерывание в начале кадра
let frames = 0, frc = 0, tacc = 0, steps = 0, hit = null;
const now = () => frames + frc / 59904;
function frame(n, stopAt) {
  for (let f = 0; f < n; f++) {
    while (frc < 59904) {
      if (stopAt !== undefined && cpu.pc === stopAt && !memory.bootbytes) { hit = stopAt; return; }
      const c = (cpu.instruction(), cpu.vcycles); steps++; frc += c; tacc += c;
      if (tacc > 1) { const tn = tacc >> 1; tacc -= tn * 2; timer.Count(tn); }
      if (cpu.last_opcode === 0xd3) io.commit();
    }
    frc -= 59904; frames++; v06c.irq = true; v06c.checkInterrupt();
  }
}
// ---- снимок: поле 256x256 и бордюр по 16 точек
function shot(out) {
  const rgb = w => [(w & 7) * 255 / 7 | 0, ((w >> 3) & 7) * 255 / 7 | 0, ((w >> 6) & 3) * 255 / 3 | 0];
  const P = pal.map(rgb), B = 16, S = 2, W = (256 + 2 * B) * S, H = (256 + 2 * B) * S, buf = Buffer.alloc(W * H * 3);
  const bc = P[pb & 15];
  for (let i = 0; i < W * H; i++) { buf[i * 3] = bc[0]; buf[i * 3 + 1] = bc[1]; buf[i * 3 + 2] = bc[2]; }
  for (let sy = 0; sy < 256; sy++) { const mrow = 255 - sy;
    for (let col = 0; col < 32; col++) {
      const b = [rd(0x8000 + (col << 8) + mrow), rd(0xA000 + (col << 8) + mrow), rd(0xC000 + (col << 8) + mrow), rd(0xE000 + (col << 8) + mrow)];
      for (let bit = 7; bit >= 0; bit--) {
        const idx = (((b[0] >> bit) & 1) << 3) | (((b[1] >> bit) & 1) << 2) | (((b[2] >> bit) & 1) << 1) | ((b[3] >> bit) & 1);
        const c = P[idx], x = B + col * 8 + (7 - bit);
        for (let dy = 0; dy < S; dy++) for (let dx = 0; dx < S; dx++) { const o = (((B + sy) * S + dy) * W + x * S + dx) * 3; buf[o] = c[0]; buf[o + 1] = c[1]; buf[o + 2] = c[2]; }
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
  console.log(`кадр ${now().toFixed(2)}: снимок -> ${out} (палитра ${pal.map(v => v.toString(16).padStart(2, "0")).join(" ")}, бордюр ${pb & 15}, ВВ55 ${cw.toString(16)})`);
}
let tprev = 0;
for (const cmd of (SCRIPT || "boot;w 100;s build/disk/shot.png").split(";").map(s => s.trim()).filter(Boolean)) {
  const a = cmd.split(/\s+/);
  switch (a[0]) {
    case "boot": {
      // ПЗУ: ждать, пока оно прочтёт дескриптор и загрузочные КБ и замрёт (секторы больше не читаются)
      while (frames < 2000 && !(nread > 0 && frames - lastRead > 5)) frame(1);
      const ok = rd(0) === 0xc3 && rd(1) === 0 && rd(2) === 1;
      console.log(`кадр ${now().toFixed(2)}: ПЗУ прочло ${nread} сект., в $0000 ${ok ? "jmp $0100" : "НЕТ jmp $0100"}; БЛК+СБР`);
      memory.detach_boot(); cpu.pc = 0; cpu.sp = 0; cpu.iff = false; nread = 0; tprev = now();
      break; }
    case "w": frame(+a[1]); break;
    case "k": key(a[1], true); frame(+(a[2] || 3)); key(a[1], false); frame(3); break;
    case "s": shot(a[1]); break;
    case "m": { const s = addr(a[1]), n = +(a[2] || 16); const out = [];
      for (let i = 0; i < n; i++) out.push(rd(s + i).toString(16).padStart(2, "0")); console.log(`${a[1]} (${s.toString(16)}): ${out.join(" ")}`); break; }
    case "cmp": { const buf = fs.readFileSync(a[1]), at = addr(a[2]), ofs = +(a[3] || 0), n = +(a[4] || buf.length - ofs);
      let bad = 0, first = -1; for (let i = 0; i < n; i++) if (rd(at + i) !== buf[ofs + i]) { bad++; if (first < 0) first = i; }
      console.log(`кадр ${now().toFixed(2)}: память $${at.toString(16)}+${n} против ${a[1]}@${ofs}: ` +
        (bad ? `РАСХОЖДЕНИЙ ${bad}, первое на $${(at + first).toString(16)}` : "совпадает")); if (bad) process.exitCode = 1; break; }
    case "pc": console.log(`кадр ${now().toFixed(2)}: PC ${cpu.pc.toString(16)}`); break;
    case "until": case "t": { hit = null; const t0 = now(); frame(+(a[2] || 3000), addr(a[1]));
      const t = now();
      console.log(hit !== null ? `кадр ${t.toFixed(2)}: ${a[1]} достигнута (секторов прочитано ${nread}` +
        (a[0] === "t" ? `, от прошлой отметки ${(t - tprev).toFixed(2)} кадра)` : ")") : `кадр ${t.toFixed(2)}: ${a[1]} НЕ достигнута`);
      tprev = t; if (hit === null) process.exitCode = 1; break; }
    default: throw new Error("команда? " + cmd);
  }
}
console.log(`итого кадров ${now().toFixed(2)}, инструкций ${steps}, PC=${cpu.pc.toString(16)}`);
