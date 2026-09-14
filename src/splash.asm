; ============================================================================
; splash.asm — загрузочная заставка. Образ .rom — 64 КБ: $8000..$FFFF уже содержит экран
; заставки в 16 цветах (виден во время загрузки). Первым делом ставим её палитру и держим
; до клавиши или SPLASH_FRAMES кадров; всё это — со временным стеком под $0060 и без
; обращения к $E000..$FFFF (там четвёртая плоскость картинки). Потом экран гасится,
; и программа стартует как обычно (переменные в $E000 затирают заставку уже на чёрном).
; ============================================================================
SPLASH_FRAMES equ 150                   ; 3 с

splash_show:
            ld   a,8Ah                  ; ВВ55: клавиатура
            out  (PPI_CW),a
            ld   a,0FFh
            out  (PPI_A),a
            ld   a,0C3h                 ; временный обработчик прерывания: ei / ret
            ld   (38h),a
            ld   hl,spl_isr
            ld   (39h),hl
            ld   hl,splash_pal
            ld   b,SPLASH_FRAMES
spl_1:      ei
            halt
            call spl_pal
            call spl_keys
            jp   nz,spl_rel
            dec  b
            jp   nz,spl_1
            jp   spl_off
spl_rel:    ei                          ; нажали — дождаться отпускания, чтобы клавиша не ушла в меню
            halt
            call spl_pal
            call spl_keys
            jp   nz,spl_rel
spl_off:    ei                          ; погасить: вся палитра чёрная
            halt
            ld   hl,spl_black
            call spl_pal
            di
            ret

; палитра 16 цветов из (HL), бордюр — индекс 0; HL сохраняется
spl_pal:    push hl
            push bc
            ld   c,15
sp_1:       ld   a,c
            out  (PPI_B),a
            ld   e,c
            ld   d,0
            push hl
            add  hl,de
            ld   a,(hl)
            pop  hl
            out  (PAL_PORT),a
            out  (PAL_PORT),a
            out  (PAL_PORT),a
            out  (PAL_PORT),a
            dec  c
            jp   p,sp_1
            xor  a
            out  (PPI_B),a
            pop  bc
            pop  hl
            ret

; NZ = нажата любая клавиша (все ряды разом), порт 3 (он же скролл) — на место
spl_keys:   xor  a
            out  (PPI_A),a
            in   a,(PPI_B)
            ld   c,a
            ld   a,0FFh
            out  (PPI_A),a
            ld   a,c
            cpl
            or   a
            ret

spl_isr:    ei
            ret
spl_black:  ds 16
