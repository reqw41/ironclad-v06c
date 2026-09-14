; ============================================================================
; zx0.asm — распаковщик ZX0 (формат v2, как у salvador по умолчанию) для i8080.
; HL = сжатые данные, DE = приёмник. Буфер битов — в памяти (zx_bits), смещение —
; отрицательное (zx_off). Порт логики dzx0_standard (Z80, E. Saukas): старший байт
; нового смещения читается гамма-кодом с C = FEh на входе (даёт -MSB-1, 0 после inc —
; конец потока), младший бит байта смещения — первый управляющий бит длины.
; Проверка: node tools/zx0test.js build/ironclad.rom (все потоки образа против .bin).
; ============================================================================

dzx0:
            ld   a,80h
            ld   (zx_bits),a
            push hl
            ld   hl,-1
            ld   (zx_off),hl
            pop  hl
zx_lit:     call zx_elias               ; литералы
            call memcpy
            call zx_bit
            jp   c,zx_new
            call zx_elias               ; повтор с прежним смещением
zx_rep:     push hl
            ld   hl,(zx_off)
            add  hl,de
            call memcpy
            pop  hl
            call zx_bit
            jp   nc,zx_lit
zx_new:     ld   c,0FEh                 ; новое смещение: C = -MSB-1
            call ze_loop
            inc  c
            ret  z                      ; MSB = 256 — конец потока
            ld   b,c
            ld   c,(hl)                 ; младший байт
            inc  hl
            ld   a,b                    ; BC = (1:B:C) >> 1 (CY = 1 после ze_loop), CY = бит 0 байта
            rra
            ld   b,a
            ld   a,c
            rra
            ld   c,a
            push hl
            ld   h,b
            ld   l,c
            ld   (zx_off),hl
            pop  hl
            ld   bc,1                   ; длина: первый управляющий бит — из байта смещения
            call nc,ze_data
            inc  bc
            jp   zx_rep

; BC = чередующийся гамма-код Элиаса (ze_loop — с BC на входе, ze_data — с бита данных)
zx_elias:   ld   bc,1
ze_loop:    call zx_bit
            ret  c
ze_data:    call zx_bit
            ld   a,c
            rla
            ld   c,a
            ld   a,b
            rla
            ld   b,a
            jp   ze_loop

; CY = следующий бит потока
zx_bit:     ld   a,(zx_bits)
            add  a,a
            jp   nz,zb_1
            ld   a,(hl)
            inc  hl
            rla
zb_1:       ld   (zx_bits),a
            ret
