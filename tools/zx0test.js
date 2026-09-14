#!/usr/bin/env node
// Проверка распаковщика dzx0 образа: каждый поток ZX0 распаковывается кодом dzx0 на ядре
// vector06js и сравнивается побайтно с исходным .bin; считаются такты Вектора (cpu.vcycles,
// 59904 на кадр).
//   node tools/zx0test.js build/ironclad.rom            — потоки образа (+ title.zx0 с диска,
//                                                        если образ собран без титула)
//   node tools/zx0test.js build/ironclad.rom build/zx0synth — ещё и синтетические потоки
//                                                        (tools/zx0synth.py): каждая пара *.zx0/*.bin
// Потоки образа распаковываются с их места в образе в $8000. Внешние потоки (с диска)
// кладутся на место данных образа (с tiles_zx0, код dzx0 цел), приёмник — $8000..$FFFF
// (до 32 КБ), стек — под $8000. После конца вывода проверяется, что лишнего не записано.
"use strict";
const fs = require("fs"), vm = require("vm");
const base = "/Users/boris/projects/vector06js";
const ROM = process.argv[2] || "build/ironclad.rom", SLD = ROM.replace(/\.rom$/, ".sld");
const SYN = process.argv[3];
const L = {};
for (const l of fs.readFileSync(SLD, "latin1").split("\n")) {
  const p = l.split("|"); if (p.length >= 8 && p[6] === "L") { const n = p[7].split(",")[1]; if (n && !(n in L)) L[n] = +p[5]; } }
const g = {}; g.window = g; g.console = { log() {}, debug() {}, warn() {}, error() {}, info() {} };
g.document = { createElement: () => ({ getContext: () => ({}) }), getElementById: () => ({}) };
const ctx = vm.createContext(g);
for (const f of ["i8080-js/i8080.js", "src/memory.js", "src/io.js", "src/keyboard.js", "src/i8253.js", "src/ay.js", "src/fd1793.js"])
  vm.runInContext(fs.readFileSync(base + "/" + f, "utf8"), ctx, { filename: f });
const memory = new ctx.Memory(), io = new ctx.IO(new ctx.Keyboard(), new ctx.I8253(), memory, new ctx.AY(), new (ctx.Floppy().FD1793)());
const cpu = new ctx.I8080(memory, io);
const rom = new Uint8Array(fs.readFileSync(ROM));
const rd = a => memory.bytes[memory.tobank(a & 0xffff)];
const FILL = 0xA5, DST = 0x8000, STOP = 0x0000;   // адрес возврата = 0: остановиться, когда PC = 0

// src — адрес потока (в образе) или Uint8Array (внешний поток); возвращает {ok, why, ticks}
function run(src, want) {
  const img = new Uint8Array(0x10000).fill(FILL, DST);
  img.set(rom.subarray(0, 0x10000 - 0x100), 0x100);
  let at = src, sp = 0xFFF0;
  if (typeof src !== "number") {
    at = L.tiles_zx0; sp = 0x7FFE;
    if (at + src.length > 0x7F00) return { ok: false, why: "не влезает в область данных образа" };
    if (want.length > 0x10000 - DST) return { ok: false, why: "вывод длиннее 32 КБ" };
    img.set(src, at);
  }
  memory.init_from_array(img, 0); memory.detach_boot && memory.detach_boot();
  cpu.sp = sp; cpu.iff = false;
  memory.write(sp, STOP & 0xff, false); memory.write(sp + 1, STOP >> 8, false);
  cpu.pc = L.dzx0;
  cpu.set_h(at >> 8); cpu.set_l(at & 0xff); cpu.set_d(DST >> 8); cpu.set_e(DST & 0xff);
  let steps = 0, ticks = 0;
  while (cpu.pc !== STOP && steps < 50000000) { cpu.instruction(); ticks += cpu.vcycles; steps++; }
  if (cpu.pc !== STOP) return { ok: false, why: "не вернулся", ticks };
  for (let i = 0; i < want.length; i++) if (rd(DST + i) !== want[i]) return { ok: false, why: "байт " + i, ticks };
  for (let i = want.length; i < want.length + 16 && DST + i < 0x10000; i++)
    if (rd(DST + i) !== FILL) return { ok: false, why: "записан лишний байт " + i, ticks };
  return { ok: true, ticks };
}

const streams = [["tiles_zx0", "build/data/tiles.bin", "build/data/tiles.zx0"], ["font_zx0", "build/data/font.bin", "build/data/font.zx0"],
  ["img_title", "build/data/title.bin", "build/data/title.zx0"], ["img_defeat", "build/data/defeat.bin", "build/data/defeat.zx0"],
  ["img_victory", "build/data/victory.bin", "build/data/victory.zx0"], ["ovl_menu_zx0", "build/ovl_menu.bin", "build/ovl_menu.zx0"],
  ["ovl_end_zx0", "build/ovl_end.bin", "build/ovl_end.zx0"]];
let bad = 0, n = 0;
const fr = t => (t / 59904).toFixed(2);
function report(name, want, r, zlen) {
  n++;
  if (!r.ok) { bad++; console.log(`${name}: ОШИБКА (${r.why})`); return; }
  process.stdout.write(`${name.padEnd(22)} ${String(zlen).padStart(5)} -> ${String(want.length).padStart(5)} Б  верно  ` +
    `${String(r.ticks).padStart(9)} т ${fr(r.ticks).padStart(7)} кадр  ${(r.ticks / Math.max(1, want.length)).toFixed(1).padStart(6)} т/Б\n`);
}
for (const [lab, bin, zx] of streams) {
  if (!fs.existsSync(bin)) continue;
  const want = fs.readFileSync(bin);
  if (L[lab] !== undefined) report(lab, want, run(L[lab], want), fs.existsSync(zx) ? fs.statSync(zx).size : "?");
  else if (fs.existsSync(zx)) { const z = new Uint8Array(fs.readFileSync(zx)); report(lab + " (с диска)", want, run(z, want), z.length); }
}
if (SYN) {
  let tot = 0;
  for (const f of fs.readdirSync(SYN).filter(f => f.endsWith(".zx0")).sort()) {
    const z = new Uint8Array(fs.readFileSync(SYN + "/" + f)), want = fs.readFileSync(SYN + "/" + f.replace(/\.zx0$/, ".bin"));
    const r = run(z, want); tot++;
    if (!r.ok) { bad++; n++; console.log(`${f}: ОШИБКА (${r.why})`); } else n++;
  }
  process.stdout.write(`синтетика: ${tot} потоков из ${SYN}\n`);
}
process.stdout.write(bad ? `РАСПАКОВЩИК: ${bad} из ${n} потоков неверны\n` : `РАСПАКОВЩИК: все ${n} потоков верны\n`);
process.exit(bad ? 1 : 0);
