#!/usr/bin/env node
// Проверка распаковщика dzx0 образа: каждый поток ZX0 из образа распаковывается кодом
// dzx0 на ядре vector06js и сравнивается побайтно с исходным .bin.
//   node tools/zx0test.js build/ironclad.rom
"use strict";
const fs = require("fs"), vm = require("vm");
const base = "/Users/boris/projects/vector06js";
const ROM = process.argv[2] || "build/ironclad.rom", SLD = ROM.replace(/\.rom$/, ".sld");
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
const streams = [["tiles_zx0", "build/data/tiles.bin"], ["font_zx0", "build/data/font.bin"], ["img_title", "build/data/title.bin"],
  ["img_defeat", "build/data/defeat.bin"], ["img_victory", "build/data/victory.bin"], ["ovl_menu_zx0", "build/ovl_menu.bin"],
  ["ovl_end_zx0", "build/ovl_end.bin"]];
let bad = 0, n = 0;
for (const [lab, bin] of streams) {
  if (L[lab] === undefined || !fs.existsSync(bin)) continue;
  const img = new Uint8Array(0x10000); img.set(rom.subarray(0, 0x10000 - 0x100), 0x100);
  memory.init_from_array(img, 0); memory.detach_boot && memory.detach_boot();
  const want = fs.readFileSync(bin), dst = 0x8000;
  const STOP = 0x0000;                       // адрес возврата = 0: остановиться, когда PC = 0
  cpu.sp = 0xFFF0; cpu.iff = false;
  memory.write(0xFFF0, STOP & 0xff, false); memory.write(0xFFF1, STOP >> 8, false);
  cpu.pc = L.dzx0;
  cpu.set_h(L[lab] >> 8); cpu.set_l(L[lab] & 0xff); cpu.set_d(dst >> 8); cpu.set_e(dst & 0xff);
  let steps = 0; while (cpu.pc !== STOP && steps < 50000000) { cpu.instruction(); steps++; }
  let diff = -1; for (let i = 0; i < want.length; i++) if (rd(dst + i) !== want[i]) { diff = i; break; }
  n++;
  if (cpu.pc !== STOP || diff >= 0) { bad++; console.log(`${lab}: ОШИБКА (${cpu.pc !== STOP ? "не вернулся" : "байт " + diff})`); }
  else process.stdout.write(`${lab}: ${want.length} Б — верно\n`);
}
process.stdout.write(bad ? `РАСПАКОВЩИК: ${bad} из ${n} потоков неверны\n` : `РАСПАКОВЩИК: все ${n} потоков верны\n`);
process.exit(bad ? 1 : 0);
