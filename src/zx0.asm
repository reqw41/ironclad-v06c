; ============================================================================
; zx0.asm — распаковщик ZX0 (формат v2, как у salvador по умолчанию) для i8080.
; Вход: HL = сжатые данные, DE = приёмник. Регистры на выходе не сохраняются.
; Прерывания можно не запрещать: стек — только call/push, SP не трогается.
;
; Регистры: A = буфер битов (маркер — младшая 1), DE = поток, BC = приёмник,
; HL = гамма-код / счётчик / источник; отрицательное смещение — в zx_off.
; Бит читается «add a,a»: CY = бит, Z = буфер пуст. Пустой буфер всегда даёт CY = 1
; (выпал маркер), поэтому при CY = 0 бит настоящий, и проверка Z нужна только на
; ветке CY = 1. Перезагрузка — «ld a,(de) / inc de / rla» (CY = 1 уходит новым маркером).
; Счётчики копий 16-битные (литералы и совпадения длиннее 256 — кругами по 256).
; Проверка: python3 tools/zx0synth.py; node tools/zx0test.js build/ironclad.rom build/zx0synth
; ============================================================================

dzx0:
            ld   b,d
            ld   c,e                    ; BC = приёмник
            ex   de,hl                  ; DE = поток
            ld   hl,-1                  ; смещение 1
            ld   (zx_off),hl
            ld   a,80h                  ; буфер пуст
; ---------------------------------------------------------------- литералы
zx_lit:     ld   hl,1
            call ze_loop                ; HL = N
            dec  hl                     ; H = старший(N-1), L = младший(N) (0 = 256)
            inc  l
            push af
zl_cp:      ld   a,(de)
            ld   (bc),a
            inc  de
            inc  bc
            dec  l
            jp   nz,zl_cp
            dec  h
            jp   p,zl_cp
            pop  af
            add  a,a                    ; 0 — повтор смещения, 1 — новое смещение
            jp   nc,zl_rep
            jp   nz,zx_new
            ld   a,(de)
            inc  de
            rla
            jp   c,zx_new
; ---------------------------------------------------------------- совпадение с прежним смещением
zl_rep:     ld   hl,1
            call ze_loop
            dec  hl                     ; HL = N-1
; HL = N-1: копировать N байт с (BC + zx_off) в BC, по два за оборот
zr_go:      push de
            push af
            ex   de,hl                  ; D = число кругов по 256 после первого
            ld   hl,(zx_off)
            add  hl,bc                  ; HL = источник; CY = 1 (источник >= 0)
            ld   a,e                    ; E = 80h + пар-1 первого круга (цикл до E < 80h),
            rra                         ; CY = N чётно
            ld   e,a
            jp   nc,zr_2                ; N нечётно: первый оборот — с одного байта
zr_1:       ld   a,(hl)
            ld   (bc),a
            inc  hl
            inc  bc
zr_2:       ld   a,(hl)
            ld   (bc),a
            inc  hl
            inc  bc
            dec  e
            jp   m,zr_1
            dec  d
            jp   p,zr_rnd
            pop  af
            pop  de
            add  a,a                    ; 0 — литералы, 1 — новое смещение
            jp   nc,zx_lit
            jp   nz,zx_new
            ld   a,(de)
            inc  de
            rla
            jp   nc,zx_lit
; ---------------------------------------------------------------- новое смещение
; старший байт — гамма-кодом с L = FEh на входе (даёт -MSB-1, 0 после inc — конец потока),
; младший бит байта смещения — первый управляющий бит длины
zx_new:     ld   l,0FEh
            call ze_loop
            inc  l
            ret  z
            ld   h,a                    ; смещение = (1:L:байт) >> 1 (CY = 1 после ze_loop)
            ld   a,l
            rra
            ld   (zx_off+1),a
            ld   a,(de)
            inc  de
            rra
            ld   (zx_off),a
            ld   a,h
            ld   hl,1
            call nc,ze_dat              ; HL = N-1
            jp   zr_go
zr_rnd:     ld   e,0FFh                 ; ещё 256 байт
            jp   zr_1

; ---------------------------------------------------------------- гамма-код Элиаса
; HL = HL * 2^k + k бит данных (чередуются с управляющими: 0 — дальше, 1 — конец).
; ze_loop — с управляющего бита, ze_dat — с бита данных. На выходе CY = 1.
ze_d1:      inc  l
ze_loop:    add  a,a
            jp   nc,ze_dat
            ret  nz
            ld   a,(de)
            inc  de
            rla
            ret  c
ze_dat:     add  hl,hl
            add  a,a
            jp   nc,ze_loop
            jp   nz,ze_d1
            ld   a,(de)
            inc  de
            rla
            jp   nc,ze_loop
            jp   ze_d1
