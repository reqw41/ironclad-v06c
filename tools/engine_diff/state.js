'use strict';
// Состояние движка, общее для обеих сторон, и его раскладка в память каждой.
//
// Z80 (оригинал): массивы BASIC по смещениям offsets*.inc от MG(0), MG(0) =
//   ARYTAB+8, указатель ARYTAB в 0F6C4h; аргумент USR в 0F7F8h (DAC+2);
//   PARM/MO/MC/FA и SMEM — по адресам из .sym оригинала; JIFFY в 0FC9Eh.
// i8080 (перевод): массивы по ARR_* (harness.asm), аргумент в HL, данные — по
//   меткам engine_bss.inc, ENG_JIFFY = 0FC9Eh.
const fs = require('fs');
const path = require('path');
const { REF } = require('./build.js');

const ARYBASE = 0x8000;         // MG(0) у Z80
const JIFFY = 0xFC9E;

// переменные PARM: имя -> размер; ptr — указатель (сравнивается относительно базы)
const VARS = [
  ['vH', 1], ['vLK', 1], ['vW', 1], ['vK', 1], ['vFAP', 2, 'FABUF'], ['vIDX', 2], ['vSTEP', 2],
  ['vRD', 1], ['vNF', 1], ['vRIM', 1], ['vST', 1], ['vJ0F', 1], ['vBS', 2], ['vBX', 1], ['vBY', 1],
  ['vC', 1], ['vR', 1], ['vP9', 2], ['vT', 1], ['vRDL', 1], ['vBXW', 2], ['vMODE', 1], ['vKL', 1],
  ['vWT', 2], ['vSEED', 2], ['vGG', 1], ['vSA', 1], ['vSI', 1], ['vSJ', 1], ['vSCJ', 2], ['vRDS', 1],
  ['vQNC', 1], ['vO2', 1], ['vSOP', 2, 'vSOA'], ['vOSK', 2], ['vT2', 1], ['vJ0', 1], ['vIBB', 2],
  ['vS9', 2], ['vW2', 2], ['vSOA', 8], ['vZX', 42], ['vRK', 1], ['vCCK', 2], ['vNEED', 1],
];

// размерности массивов: у MSX (dims BASIC + 1) и у Вектора (ARR_*)
const ARRS = ['MG', 'PH', 'CC', 'OS', 'SZ', 'HK', 'TX', 'TY', 'BZ', 'PM'];
const VEC_LEN = { MG: 144, PH: 12, CC: 8, OS: 8, SZ: 12, HK: 8, TX: 11, TY: 11, BZ: 100, PM: 100 };
const MSX_LEN = {
  salvo: { MG: 144, PH: 6, CC: 6, OS: 6, SZ: 6, HK: 6, TX: 5, TY: 5, BZ: 100, PM: 100 },
  sp: { MG: 144, PH: 12, CC: 8, OS: 8, SZ: 12, HK: 8, TX: 5, TY: 5, BZ: 100, PM: 100 },
};
MSX_LEN.bar = MSX_LEN.salvo;

const VARIANT = {
  salvo: { sp: 0, bar: 0, nships: 5, fasize: 760, offs: 'offsets.inc' },
  sp: { sp: 1, bar: 0, nships: 7, fasize: 1120, offs: 'offsets_sp.inc' },
  bar: { sp: 0, bar: 1, nships: 5, fasize: 760, offs: 'offsets.inc' },
};

function readOffsets(file) {
  const o = {};
  for (const l of fs.readFileSync(path.join(REF, 'src/z80', file), 'latin1').split('\n')) {
    const m = l.match(/^o(\w+)\s+equ\s+(\d+)/);
    if (m) o[m[1]] = +m[2];
  }
  return o;
}

// Новое пустое состояние варианта v
function blank(v) {
  const S = { v, arr: {}, MO: new Uint8Array(144), MC: new Uint8Array(144), FA: new Uint8Array(1120),
    vars: {}, SMEM: new Uint8Array(3), jiffy: 0, eng: { sp: VARIANT[v].sp, bar: VARIANT[v].bar } };
  for (const a of ARRS) S.arr[a] = new Uint16Array(MSX_LEN[v][a]);
  for (const [n, sz, base] of VARS) S.vars[n] = base ? 0 : new Uint8Array(sz);
  return S;
}

function clone(S) {
  const T = { v: S.v, arr: {}, MO: S.MO.slice(), MC: S.MC.slice(), FA: S.FA.slice(), vars: {},
    SMEM: S.SMEM.slice(), jiffy: S.jiffy, eng: { ...S.eng } };
  for (const a of ARRS) T.arr[a] = S.arr[a].slice();
  for (const [n, sz, base] of VARS) T.vars[n] = base ? S.vars[n] : S.vars[n].slice();
  return T;
}

// ---------------------------------------------------------------- Z80
class Z80Layout {
  constructor(v, orig) {
    this.v = v; this.o = orig; this.off = readOffsets(VARIANT[v].offs);
    this.fasize = VARIANT[v].fasize;
    const s = orig.sym;
    this.addr = {};
    for (const [n] of VARS) this.addr[n] = s[n];
    for (const n of ['MOBUF', 'MCBUF', 'FABUF', 'SMEMG', 'PARM', 'vSOA']) this.addr[n] = s[n];
    this.entry = {};
    for (const e of ['fold', 'kill1', 'explore', 'pickn', 'marg', 'sample', 'fainit', 'probesel', 'samp1'])
      if (s[e] !== undefined) this.entry[e] = s[e];
  }
  arrAddr(a) { return ARYBASE + this.off[a]; }
  // полная подготовка памяти коробки к случаю
  load(box, S, arg, canary) {
    const m = box.mem;
    m.fill(0);
    // зона массивов с «канарейками» между ними (заголовки и чужие массивы BASIC)
    for (let a = ARYBASE - 8; a < ARYBASE + 1200; a++) m[a] = canary(a);
    box.w16(0xF6C4, ARYBASE - 8);
    for (const a of ARRS) {
      const base = this.arrAddr(a), arr = S.arr[a];
      for (let i = 0; i < arr.length; i++) box.w16(base + 2 * i, arr[i]);
    }
    const A = this.addr;
    for (let a = A.PARM; a < A.MOBUF; a++) m[a] = canary(a);
    for (const [n, sz, base] of VARS) {
      if (base) box.w16(A[n], (A[base] + S.vars[n]) & 0xffff);
      else for (let i = 0; i < sz; i++) m[A[n] + i] = S.vars[n][i];
    }
    m.set(S.MO, A.MOBUF); m.set(S.MC, A.MCBUF); m.set(S.FA.subarray(0, this.fasize), A.FABUF);
    m.set(this.o.code, this.o.org);
    m.set(S.SMEM, A.SMEMG);
    box.w16(JIFFY, S.jiffy);
    box.w16(0xF7F8, arg);
    // разрешённые для записи зоны
    box.allowed.fill(0);
    box.allow(0xF000 - 0x100, 0x100);
    for (const a of ARRS) box.allow(this.arrAddr(a), 2 * MSX_LEN[this.v][a]);
    box.allow(A.PARM, A.FABUF + this.fasize - A.PARM);
  }
  extract(box, S0) {
    const S = clone(S0), A = this.addr;
    for (const a of ARRS) {
      const base = this.arrAddr(a), arr = S.arr[a];
      for (let i = 0; i < arr.length; i++) arr[i] = box.r16(base + 2 * i);
    }
    for (const [n, sz, base] of VARS) {
      if (base) S.vars[n] = (box.r16(A[n]) - A[base]) & 0xffff;
      else for (let i = 0; i < sz; i++) S.vars[n][i] = box.mem[A[n] + i];
    }
    S.MO.set(box.mem.subarray(A.MOBUF, A.MOBUF + 144));
    S.MC.set(box.mem.subarray(A.MCBUF, A.MCBUF + 144));
    S.FA.set(box.mem.subarray(A.FABUF, A.FABUF + this.fasize));
    S.SMEM.set(box.mem.subarray(A.SMEMG, A.SMEMG + 3));
    return S;
  }
  codeIntact(box) {
    const c = this.o.code;
    for (let i = 0; i < c.length; i++) if (box.mem[this.o.org + i] !== c[i]) return false;
    return true;
  }
}

// ---------------------------------------------------------------- i8080
class I8080Layout {
  constructor(mine) {
    this.m = mine;
    // глобальные (@) имена важнее: sjasmplus оставляет в .sym мусорные engine.X = 0
    // для ссылок вперёд на глобальные метки из модуля
    const s = mine.sym, g = n => (s[n] !== undefined ? s[n] : s['engine.' + n]);
    this.addr = {};
    for (const [n] of VARS) this.addr[n] = g(n);
    for (const n of ['MOBUF', 'MCBUF', 'FABUF', 'SMEMG', 'eng_sp', 'eng_bar', 'vSOA']) this.addr[n] = g(n);
    this.arr = {};
    for (const a of ARRS) this.arr[a] = s['ARR_' + a];
    this.entry = {};
    for (const e of ['fold', 'kill1', 'explore', 'pickn', 'marg', 'sample', 'fainit', 'probesel'])
      this.entry[e] = s['eng_' + e];
    this.div16 = g('div16');
    for (const [n] of VARS) if (this.addr[n] === undefined) throw new Error('нет переменной ' + n);
  }
  load(box, S, canary) {
    const m = box.mem;
    m.fill(0);
    m.set(this.m.code, this.m.org);
    for (let a = 0x8000; a < 0x8600; a++) m[a] = canary(a);
    for (let a = this.m.sym.bss_start; a < this.m.sym.bss_end; a++) m[a] = canary(a);
    for (const a of ARRS) {
      const base = this.arr[a], arr = S.arr[a];
      for (let i = 0; i < arr.length; i++) box.w16(base + 2 * i, arr[i]);
    }
    const A = this.addr;
    for (const [n, sz, base] of VARS) {
      if (base) box.w16(A[n], (A[base] + S.vars[n]) & 0xffff);
      else for (let i = 0; i < sz; i++) m[A[n] + i] = S.vars[n][i];
    }
    m.set(S.MO, A.MOBUF); m.set(S.MC, A.MCBUF); m.set(S.FA, A.FABUF);
    m.set(S.SMEM, A.SMEMG);
    m[A.eng_sp] = S.eng.sp; m[A.eng_bar] = S.eng.bar;
    box.w16(JIFFY, S.jiffy);
    box.allowed.fill(0);
    box.allow(0xF000 - 0x100, 0x100);
    for (const a of ARRS) box.allow(this.arr[a], 2 * VEC_LEN[a]);
    box.allow(this.m.sym.bss_start, this.m.sym.bss_end - this.m.sym.bss_start);
  }
  extract(box, S0) {
    const S = clone(S0), A = this.addr;
    for (const a of ARRS) {
      const base = this.arr[a], arr = S.arr[a];
      for (let i = 0; i < arr.length; i++) arr[i] = box.r16(base + 2 * i);
    }
    for (const [n, sz, base] of VARS) {
      if (base) S.vars[n] = (box.r16(A[n]) - A[base]) & 0xffff;
      else for (let i = 0; i < sz; i++) S.vars[n][i] = box.mem[A[n] + i];
    }
    S.MO.set(box.mem.subarray(A.MOBUF, A.MOBUF + 144));
    S.MC.set(box.mem.subarray(A.MCBUF, A.MCBUF + 144));
    S.FA.set(box.mem.subarray(A.FABUF, A.FABUF + 1120));
    S.SMEM.set(box.mem.subarray(A.SMEMG, A.SMEMG + 3));
    return S;
  }
  // хвосты массивов Вектора за пределами размерностей MSX не должны меняться
  tailsIntact(box, S, canary) {
    for (const a of ARRS) {
      const n = S.arr[a].length;
      for (let i = 2 * n; i < 2 * VEC_LEN[a]; i++) {
        const ad = this.arr[a] + i;
        if (box.mem[ad] !== canary(ad)) return a;
      }
    }
    return null;
  }
  codeIntact(box) {
    const c = this.m.code;
    for (let i = 0; i < c.length; i++) if (box.mem[this.m.org + i] !== c[i]) return false;
    return true;
  }
}

// Сравнение двух состояний: список расхождений (пустой = совпали).
// faLen — сколько байт FA сравнивать (760 у SALVO/BARRAGE: дальше у Z80 код).
function diff(A, B, faLen) {
  const out = [];
  for (const a of ARRS) {
    const x = A.arr[a], y = B.arr[a];
    for (let i = 0; i < x.length; i++) if (x[i] !== y[i]) { out.push(`${a}(${i}) z80=${x[i]} i8080=${y[i]}`); if (out.length > 12) return out; }
  }
  for (const [nm, buf] of [['MO', 'MO'], ['MC', 'MC']]) {
    for (let i = 0; i < 144; i++) if (A[buf][i] !== B[buf][i]) { out.push(`${nm}[${i}] z80=${A[buf][i]} i8080=${B[buf][i]}`); if (out.length > 12) return out; }
  }
  for (let i = 0; i < faLen; i++) if (A.FA[i] !== B.FA[i]) { out.push(`FA[${i}] z80=${A.FA[i]} i8080=${B.FA[i]}`); if (out.length > 12) return out; }
  for (const [n, sz, base] of VARS) {
    if (base) { if (A.vars[n] !== B.vars[n]) out.push(`${n} z80=+${A.vars[n]} i8080=+${B.vars[n]}`); }
    else for (let i = 0; i < sz; i++) if (A.vars[n][i] !== B.vars[n][i]) { out.push(`${n}[${i}] z80=${A.vars[n][i]} i8080=${B.vars[n][i]}`); break; }
  }
  for (let i = 0; i < 3; i++) if (A.SMEM[i] !== B.SMEM[i]) out.push(`SMEM[${i}]`);
  return out;
}

module.exports = { VARS, ARRS, VEC_LEN, MSX_LEN, VARIANT, blank, clone, Z80Layout, I8080Layout, diff, JIFFY };
