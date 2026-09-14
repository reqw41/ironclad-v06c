; ============================================================================
; zx0.asm — распаковщик ZX0 (формат v2, как у salvador по умолчанию) для i8080.
; HL = сжатые данные, DE = приёмник. Состояние — в памяти (скорость здесь не важна:
; распаковываются только полноэкранные картинки).
; ============================================================================

dzx0:
            ld   a,80h
            ld   (zx_bits),a
            xor  a
            ld   (zx_bt),a
            push hl
            ld   hl,1
            ld   (zx_off),hl
            pop  hl
zx_lit:     call zx_elias               ; BC = длина литералов
zl_cp:      ld   a,(hl)
            ld   (de),a
            inc  hl
            inc  de
            dec  bc
            ld   a,b
            or   c
            jp   nz,zl_cp
            call zx_bit
            jp   c,zx_new
            call zx_elias               ; повтор с прежним смещением
            call zx_copy
            call zx_bit
            jp   c,zx_new
            jp   zx_lit
zx_new:     call zx_elias_inv           ; старшая часть смещения
            ld   a,b
            dec  a
            or   c
            ret  z                      ; 256 = конец потока
            ld   a,(hl)
            inc  hl
            ld   (zx_lsb),a
            and  1
            or   80h
            ld   (zx_bt),a              ; младший бит байта = первый бит длины
            ld   a,c                    ; смещение = msb*128 - (lsb>>1)
            or   a
            rra
            ld   b,a
            ld   a,0
            rra
            ld   c,a
            ld   a,(zx_lsb)
            or   a
            rra
            push de
            ld   d,a
            ld   a,c
            sub  d
            ld   c,a
            ld   a,b
            sbc  a,0
            ld   b,a
            pop  de
            push hl
            ld   h,b
            ld   l,c
            ld   (zx_off),hl
            pop  hl
            call zx_elias
            inc  bc
            call zx_copy
            call zx_bit
            jp   c,zx_new
            jp   zx_lit

; копировать BC байт с DE-смещение в DE
zx_copy:
            push hl
            ld   hl,(zx_off)
            ld   a,e
            sub  l
            ld   l,a
            ld   a,d
            sbc  a,h
            ld   h,a
zc_lp:      ld   a,(hl)
            ld   (de),a
            inc  hl
            inc  de
            dec  bc
            ld   a,b
            or   c
            jp   nz,zc_lp
            pop  hl
            ret

; BC = чередующийся гамма-код Элиаса (inv: биты значения инвертированы)
zx_elias:
            ld   bc,1
ze_lp:      call zx_bit
            ret  c
            call zx_bit
            ld   a,c
            rla
            ld   c,a
            ld   a,b
            rla
            ld   b,a
            jp   ze_lp
zx_elias_inv:
            ld   bc,1
zi_lp:      call zx_bit
            ret  c
            call zx_bit
            ccf
            ld   a,c
            rla
            ld   c,a
            ld   a,b
            rla
            ld   b,a
            jp   zi_lp

; CY = следующий бит потока
zx_bit:
            ld   a,(zx_bt)
            or   a
            jp   nz,zb_back
            ld   a,(zx_bits)
            add  a,a
            jp   nz,zb_st
            ld   a,(hl)
            inc  hl
            rla
zb_st:      ld   (zx_bits),a
            ret
zb_back:    rra                         ; CY = отложенный бит
            ld   a,0
            ld   (zx_bt),a
            ret
