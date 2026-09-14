#!/usr/bin/env node
'use strict';
// Проверка, что стенд не слеп: в копию перевода вносятся намеренные ошибки
// (по одной), и сверка обязана найти РАСХОЖДЕНИЯ (не просто упасть на
// покрытии).  Плюс гейт обязан упасть на пустой выборке.
//
// node tools/engine_diff/mutate.js [--sessions N] [--random N]
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { ROOT } = require('./build.js');

const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf('--' + n); return i < 0 ? d : args[i + 1]; };
const SESS = opt('sessions', '2'), RND = opt('random', '40');
const SRC = path.join(ROOT, 'src/engine');

// [имя, что заменить (точный фрагмент, обязан встречаться 1 раз), на что]
const MUT = [
  ['pickn: сравнение наоборот', 'call    sgt             ; CY: MG(P9) > BS (со знаком)\n                jp      nc,pnnext', 'call    sgt             ; CY: MG(P9) > BS (со знаком)\n                jp      c,pnnext'],
  ['sgt: потерян ccf (флаг)', 'rla                     ; CY = знак DE\n                ccf', 'rla                     ; CY = знак DE\n                nop'],
  ['explore: край 9 -> 8', 'ld      a,(vR)\n                or      a\n                jp      z,extrim\n                cp      9', 'ld      a,(vR)\n                or      a\n                jp      z,extrim\n                cp      8'],
  ['fold: маска NS 0Fh -> 07h', 'ld      a,l             ; NS\n                and     0Fh', 'ld      a,l             ; NS\n                and     07h'],
  ['cand: отсев наоборот', 'ld      hl,vH\n                cp      (hl)\n                jp      z,cdone', 'ld      hl,vH\n                cp      (hl)\n                jp      nz,cdone'],
  ['candmg: знак клетки наоборот', 'rla                     ; знак: клетка вне игры\n                jp      c,mgskip', 'rla                     ; знак: клетка вне игры\n                jp      nc,mgskip'],
  ['div16: 15 шагов вместо 16', 'ld      hl,0            ; остаток\n                ld      a,16', 'ld      hl,0            ; остаток\n                ld      a,15'],
  ['rnd16: маска 7Fh -> 3Fh', 'and     7Fh', 'and     3Fh'],
  ['rnd16: rrca -> rra (CY течёт)', 'rrca                    ; бит 7 = L.0', 'rra                     ; бит 7 = L.0'],
  ['sgt1: sbc -> sub (потерян заём)', 'sub     e\n                ld      a,h\n                sbc     a,d             ; CY <=> HL < DE', 'sub     e\n                ld      a,h\n                sub     d               ; CY <=> HL < DE'],
  ['place: 7 попыток вместо 8', 'ld      a,8\n                ld      (vT2),a', 'ld      a,7\n                ld      (vT2),a'],
  ['sortso: порядок наоборот', 'jp      nc,ssjnext      ; CC(SO[J]) >= CC(SO[I])', 'jp      c,ssjnext       ; CC(SO[J]) >= CC(SO[I])'],
  ['probesel: 12000 -> 12001', 'ld      hl,12000', 'ld      hl,12001'],
  ['probesel: sbc -> sub (потерян заём)', 'sub     l\n                ld      a,b\n                sbc     a,h             ; CY <=> |d| < BS', 'sub     l\n                ld      a,b\n                sub     h               ; CY <=> |d| < BS'],
  ['BARRAGE: 6000 -> 5000', 'ld      hl,6000', 'ld      hl,5000'],
  ['SALVO PLUS: буй cp 3 -> cp 2', 'ld      a,(hl)\n                cp      3\n                jp      z,extnext', 'ld      a,(hl)\n                cp      2\n                jp      z,extnext'],
  ['SALVO PLUS: NSHIPS 7 -> 6', 'ld      a,NSH_SP+1', 'ld      a,NSH_SP'],
  ['pldraw: r вместо r+1', 'jp      nc,pldr         ; r в [0, CC)\n                inc     a', 'jp      nc,pldr         ; r в [0, CC)\n                nop'],
  ['bumpst: после переполнения 2', 'call    clrmo\n                ld      a,1\nbst1:', 'call    clrmo\n                ld      a,2\nbst1:'],
  ['mapptr: без E+1', 'ld      a,e\n                inc     a\n                ld      c,a\n                ld      b,0', 'ld      a,e\n                nop\n                ld      c,a\n                ld      b,0'],
  ['fainit: FA на 960 байт', 'ld      c,7\nfai1:', 'ld      c,6\nfai1:'],
  ['plstamp: LK+1 вместо LK+2', 'ld      a,(vLK)\n                add     a,2', 'ld      a,(vLK)\n                add     a,1'],
  ['pndiv: jp nc -> jp z (флаг)', 'add     hl,de           ; CY <=> HL >= 12 (до вычитания)\n                jp      nc,pndone', 'add     hl,de           ; CY <=> HL >= 12 (до вычитания)\n                jp      z,pndone'],
];

function runGate(extra) {
  const r = spawnSync(process.execPath, [path.join(__dirname, 'run.js'), '--quiet', ...extra], { encoding: 'utf8' });
  return r;
}

const rows = [];
let ok = true;
// 1) пустая выборка
{
  const js = path.join(ROOT, 'build/mut/empty.json');
  fs.mkdirSync(path.dirname(js), { recursive: true });
  const r = runGate(['--sessions', '0', '--random', '0', '--fast', '--json', js]);
  const s = JSON.parse(fs.readFileSync(js, 'utf8'));
  const caught = r.status !== 0 && s.why.some(w => w.includes('пустая выборка'));
  rows.push(['пустая выборка (0 случаев)', caught ? 'ГЕЙТ УПАЛ' : 'НЕ УПАЛ', s.why[0] || '']);
  if (!caught) ok = false;
}
// 2) мутации
MUT.forEach(([name, from, to], i) => {
  const dir = path.join(ROOT, 'build/mut', String(i));
  fs.mkdirSync(dir, { recursive: true });
  const src = fs.readFileSync(path.join(SRC, 'engine.asm'), 'utf8');
  const n = src.split(from).length - 1;
  if (n !== 1) { rows.push([name, `фрагмент найден ${n} раз`, '']); ok = false; return; }
  fs.writeFileSync(path.join(dir, 'engine.asm'), src.replace(from, to));
  fs.copyFileSync(path.join(SRC, 'engine_bss.inc'), path.join(dir, 'engine_bss.inc'));
  const js = path.join(dir, 'sum.json');
  const r = runGate(['--engine-dir', dir, '--build-sub', 'mut/' + i + '/b', '--sessions', SESS, '--random', RND, '--fast', '--json', js]);
  if (!fs.existsSync(js)) { rows.push([name, 'стенд не отработал', (r.stderr || '').split('\n')[0]]); ok = false; return; }
  const s = JSON.parse(fs.readFileSync(js, 'utf8'));
  const bad = s.rows.filter(x => x.bad > 0);
  const nbad = bad.reduce((a, x) => a + x.bad, 0);
  const where = bad.map(x => `${x.v}/${x.e}:${x.bad}`).join(' ');
  rows.push([name, nbad ? `поймана: ${nbad} случаев` : 'НЕ ПОЙМАНА', where]);
  if (!nbad) ok = false;
});
console.log('мутация | итог | где расхождения (вариант/вход:случаев)');
for (const r of rows) console.log(`${r[0]} | ${r[1]} | ${r[2]}`);
console.log(ok ? '\nСТЕНД НЕ СЛЕП: все мутации пойманы, пустая выборка валит гейт' : '\nПРОБЛЕМА: есть непойманные мутации');
process.exit(ok ? 0 : 1);
