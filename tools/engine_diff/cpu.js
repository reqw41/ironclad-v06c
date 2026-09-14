'use strict';
// Обёртки двух эмуляторов для сверки: Z80 (оригинал FOLD*.BIN) и i8080 (перевод).
// Оба — копии из vector06js (vendor/, происхождение в vendor/README.md).
// Каждая коробка: 64 КБ памяти, карта «куда можно писать» (запись вне неё
// считается и сообщается), вызов подпрограммы до возврата на страж-адрес.
const fs = require('fs');
const path = require('path');

const Z80 = require('./vendor/Z80_v06.js');
const I8080 = new Function(
  fs.readFileSync(path.join(__dirname, 'vendor/i8080.js'), 'utf8') +
  '\nreturn I8080;')();

const SENTINEL = 0x0000;          // адрес возврата: там HALT
const STACK_TOP = 0xF000;
const MAX_INSTR = 60e6;           // зависание = отказ случая

class Box {
  constructor() {
    this.mem = new Uint8Array(65536);
    this.allowed = new Uint8Array(65536);
    this.stray = [];              // адреса записей вне разрешённого
    this.hits = null;             // Int32Array(65536) — счётчик PC, если нужен
  }
  allow(a, n) { for (let i = 0; i < n; i++) this.allowed[(a + i) & 0xffff] = 1; }
  w(a, v) { this.mem[a & 0xffff] = v & 0xff; }
  w16(a, v) { this.w(a, v); this.w(a + 1, v >> 8); }
  r(a) { return this.mem[a & 0xffff]; }
  r16(a) { return this.mem[a & 0xffff] | (this.mem[(a + 1) & 0xffff] << 8); }
  _write(a, v) {
    a &= 0xffff;
    if (!this.allowed[a]) this.stray.push(a);
    this.mem[a] = v & 0xff;
  }
}

class I8080Box extends Box {
  constructor() {
    super();
    const self = this;
    this.memory = {
      read(a) { return self.mem[a & 0xffff]; },
      write(a, v) { self._write(a, v); },
    };
    this.io = { input() { return 0xff; }, output() {}, interrupt() {} };
    this.allow(STACK_TOP - 0x100, 0x100);
  }
  // вызов подпрограммы entry с HL = hl; возвращает {instr, cycles, vcycles}
  call(entry, hl) {
    const cpu = new I8080(this.memory, this.io);
    this.mem[SENTINEL] = 0x76;
    cpu.sp = STACK_TOP - 2;
    this.mem[cpu.sp] = SENTINEL & 0xff; this.mem[cpu.sp + 1] = SENTINEL >> 8;
    cpu.regs[4] = (hl >> 8) & 0xff; cpu.regs[5] = hl & 0xff;
    cpu.pc = entry;
    this.stray = [];
    let n = 0, cyc = 0, vcyc = 0;
    const hits = this.hits;
    while (cpu.pc !== SENTINEL) {
      if (hits) hits[cpu.pc]++;
      cpu.instruction();
      cyc += cpu.cpu_cycles; vcyc += cpu.vcycles;
      if (++n > MAX_INSTR) return { timeout: true, instr: n, cycles: cyc, vcycles: vcyc };
    }
    if (cpu.sp !== STACK_TOP) return { badsp: true, instr: n, cycles: cyc, vcycles: vcyc };
    return { instr: n, cycles: cyc, vcycles: vcyc };
  }
}

class Z80Box extends Box {
  constructor() {
    super();
    const self = this;
    this.cpu = new Z80({
      mem_read(a) { return self.mem[a & 0xffff]; },
      mem_write(a, v) { self._write(a, v); },
      io_read() { return 0xff; },
      io_write() {},
    });
    this.allow(STACK_TOP - 0x100, 0x100);
  }
  call(entry) {
    const cpu = this.cpu;
    cpu.reset();
    this.mem[SENTINEL] = 0x76;
    cpu.sp = STACK_TOP - 2;
    this.mem[cpu.sp] = SENTINEL & 0xff; this.mem[cpu.sp + 1] = SENTINEL >> 8;
    cpu.pc = entry;
    this.stray = [];
    let n = 0, cyc = 0;
    const hits = this.hits;
    while (cpu.pc !== SENTINEL) {
      if (hits) hits[cpu.pc]++;
      cyc += cpu.instruction();
      if (++n > MAX_INSTR) return { timeout: true, instr: n, cycles: cyc };
    }
    if (cpu.sp !== STACK_TOP) return { badsp: true, instr: n, cycles: cyc };
    return { instr: n, cycles: cyc };
  }
}

module.exports = { I8080Box, Z80Box, I8080, Z80, STACK_TOP };
