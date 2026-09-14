; ============================================================================
; gfx.asm — графические примитивы в координатах экрана MSX (x 0..255, y 0..211).
; Строка MSX y -> строка памяти Вектора 233-y (сдвиг 22 строки вниз), столбец = x>>3,
; плоскость p (0..3) = бит (3-p) номера цвета, страница H = $80 + p*$20 + столбец.
; ============================================================================

MSX_TOP     equ 233             ; строка памяти для y = 0

; ---------------------------------------------------------------- LINE ...,BF
; B=x1 C=y1 D=x2 E=y2 A=цвет. Порядок углов любой, y > 211 отсекается.
gfx_fill:
            ld   (gf_col),a
            ld   a,d
            cp   b
            jp   nc,gf_1
            ld   a,b
            ld   b,d
            ld   d,a
gf_1:       ld   a,e
            cp   c
            jp   nc,gf_2
            ld   a,c
            ld   c,e
            ld   e,a
gf_2:       ld   a,c
            cp   212
            ret  nc
            ld   a,e
            cp   212
            jp   c,gf_3
            ld   e,211
gf_3:       ld   a,e
            sub  c
            inc  a
            ld   (gf_h),a
            ld   a,MSX_TOP
            sub  c
            ld   (gf_row),a
            ; маски краёв
            ld   a,b
            and  7
            ld   hl,lmask_tab
            call tab_a
            ld   (gf_lm),a
            ld   a,d
            and  7
            ld   hl,rmask_tab
            call tab_a
            ld   (gf_rm),a
            ; столбцы
            ld   a,b
            rrca
            rrca
            rrca
            and  1Fh
            ld   b,a                    ; c1
            ld   a,d
            rrca
            rrca
            rrca
            and  1Fh
            ld   d,a                    ; c2
            ld   a,b
            ld   (gf_c1),a
gf_col_lp:
            ld   c,0FFh
            ld   a,(gf_c1)
            cp   b
            jp   nz,gf_nf
            ld   a,(gf_lm)              ; первый столбец — левая маска
            ld   c,a
gf_nf:      ld   a,b
            cp   d
            jp   nz,gf_nl
            ld   a,(gf_rm)              ; последний — правая
            and  c
            ld   c,a
gf_nl:      push bc
            push de
            ld   h,b
            ld   a,c
            call fill_col
            pop  de
            pop  bc
            ld   a,b
            cp   d
            ret  z
            inc  b
            jp   gf_col_lp

; A = маска, H = столбец; строки gf_row.. вниз gf_h штук, цвет gf_col
fill_col:
            ld   e,a
            cpl
            ld   d,a
            ld   a,h
            add  a,80h
            ld   h,a
            ld   a,(gf_col)
            rlca
            rlca
            rlca
            rlca
            ld   c,a
            ld   a,4
            ld   (fc_pl),a
fc_pl_lp:
            ld   a,(gf_row)
            ld   l,a
            ld   a,(gf_h)
            ld   b,a
            ld   a,c
            rlca
            ld   c,a
            jp   nc,fc_clr
fc_set:     ld   a,(hl)
            or   e
            ld   (hl),a
            dec  l
            dec  b
            jp   nz,fc_set
            jp   fc_next
fc_clr:     ld   a,(hl)
            and  d
            ld   (hl),a
            dec  l
            dec  b
            jp   nz,fc_clr
fc_next:    ld   a,h
            add  a,20h
            ld   h,a
            ld   a,(fc_pl)
            dec  a
            ld   (fc_pl),a
            jp   nz,fc_pl_lp
            ret

; A = (HL + A)
tab_a:
            add  a,l
            ld   l,a
            jp   nc,ta_1
            inc  h
ta_1:       ld   a,(hl)
            ret

lmask_tab:  db 0FFh,7Fh,3Fh,1Fh,0Fh,07h,03h,01h
rmask_tab:  db 80h,0C0h,0E0h,0F0h,0F8h,0FCh,0FEh,0FFh

; ---------------------------------------------------------------- LINE ...,B
; B=x1 C=y1 D=x2 E=y2 A=цвет
gfx_box:
            ld   (gb_col),a
            push bc
            push de
            ld   a,(gb_col)
            ld   e,c                    ; верх: (x1,y1)-(x2,y1)
            call gfx_fill
            pop  de
            pop  bc
            push bc
            push de
            ld   c,e                    ; низ: (x1,y2)-(x2,y2)
            ld   a,(gb_col)
            call gfx_fill
            pop  de
            pop  bc
            push bc
            push de
            ld   d,b                    ; лево: (x1,y1)-(x1,y2)
            ld   a,(gb_col)
            call gfx_fill
            pop  de
            pop  bc
            ld   b,d                    ; право: (x2,y1)-(x2,y2)
            ld   a,(gb_col)
            jp   gfx_fill

; ---------------------------------------------------------------- PSET (x,y),c
; B=x C=y A=цвет. Ставит и графический курсор (для PRINT#1).
gfx_pset:
            ld   (gp_col),a
            ld   a,b
            ld   (gfx_x),a
            ld   a,c
            ld   (gfx_y),a
            cp   212
            ret  nc
            ld   a,MSX_TOP
            sub  c
            ld   (gp_row),a
            ld   a,b
            and  7
            ld   (gs_n),a
            ld   a,b
            rrca
            rrca
            rrca
            and  1Fh
            ld   (gp_cx),a
            ld   a,80h
            call shift_bits             ; D = точка, E = 0
            ld   a,(gp_cx)
            ld   h,a
            ld   a,(gp_row)
            ld   l,a
            ld   a,(gp_col)
            ld   c,a
            jp   put_bits

; ---------------------------------------------------------------- биты в 4 плоскости
; H = столбец (0..31), L = строка памяти, D = биты столбца, E = биты столбца+1,
; C = цвет (0..15). Единичные биты красятся цветом, прочие не трогаются.
put_bits:
            ld   a,h
            add  a,80h
            ld   h,a
            ld   a,c
            rlca
            rlca
            rlca
            rlca
            ld   c,a
            ld   b,4
pb_1:       ld   a,c
            rlca
            ld   c,a
            jp   nc,pb_clr
            ld   a,(hl)
            or   d
            ld   (hl),a
            inc  h
            ld   a,(hl)
            or   e
            ld   (hl),a
            dec  h
            jp   pb_next
pb_clr:     ld   a,d
            cpl
            and  (hl)
            ld   (hl),a
            inc  h
            ld   a,e
            cpl
            and  (hl)
            ld   (hl),a
            dec  h
pb_next:    ld   a,h
            add  a,20h
            ld   h,a
            dec  b
            jp   nz,pb_1
            ret

; сдвинуть байт A вправо на gs_n точек: D = левый байт, E = правый
shift_bits:
            ld   d,a
            ld   e,0
            ld   a,(gs_n)
            or   a
            ret  z
            ld   b,a
sb_1:       ld   a,d
            or   a
            rra
            ld   d,a
            ld   a,e
            rra
            ld   e,a
            dec  b
            jp   nz,sb_1
            ret

; ---------------------------------------------------------------- PRINT#1
; Строка HL (0 в конце) с графического курсора (gfx_x, gfx_y) цветом gfx_fg.
; Фон знакомест не трогается (как GRPPRT MSX). Курсор сдвигается на 8 точек на знак.
gfx_puts:
            ld   a,(hl)
            or   a
            ret  z
            push hl
            call gfx_putc
            pop  hl
            inc  hl
            jp   gfx_puts

; знак A
gfx_putc:
            sub  32
            ret  c
            ld   l,a
            ld   h,0
            add  hl,hl
            add  hl,hl
            add  hl,hl
            ld   de,font_data
            add  hl,de
            ld   (gc_src),hl
            ld   a,(gfx_x)
            ld   b,a
            and  7
            ld   (gs_n),a
            ld   a,b
            rrca
            rrca
            rrca
            and  1Fh
            ld   (gc_colx),a
            ld   a,(gfx_y)
            ld   (gc_y),a
            ld   a,7
            ld   (gc_cnt),a
gc_row:
            ld   a,(gc_y)
            cp   212
            jp   nc,gc_skip
            ld   hl,(gc_src)
            ld   a,(hl)
            or   a
            jp   z,gc_skip
            call shift_bits
            ld   a,(gc_colx)
            cp   31
            jp   nz,gc_ok
            ld   e,0
gc_ok:      ld   h,a
            ld   a,(gc_y)
            ld   b,a
            ld   a,MSX_TOP
            sub  b
            ld   l,a
            ld   a,(gfx_fg)
            ld   c,a
            call put_bits
gc_skip:    ld   hl,(gc_src)
            inc  hl
            ld   (gc_src),hl
            ld   hl,gc_y
            inc  (hl)
            ld   hl,gc_cnt
            dec  (hl)
            jp   nz,gc_row
            ld   a,(gfx_x)
            add  a,8
            ld   (gfx_x),a
            ret

; ---------------------------------------------------------------- глиф 8x10
; A = номер глифа (0..31), B = x, C = y, E = цвет заливки (обводка — цвет 10), TPSET.
gfx_glyph:
            push de
            ld   l,a
            ld   h,0
            add  hl,hl
            add  hl,hl
            ld   d,h
            ld   e,l
            add  hl,hl
            add  hl,hl
            add  hl,de                  ; *20
            ld   de,glyph_data
            add  hl,de
            ld   (gc_src),hl
            pop  de
            ld   a,e
            ld   (gl_fill),a
            ld   a,b
            and  7
            ld   (gs_n),a
            ld   a,b
            rrca
            rrca
            rrca
            and  1Fh
            ld   (gc_colx),a
            ld   a,c
            ld   (gc_y),a
            ld   a,10
            ld   (gc_cnt),a
gg_row:
            ld   hl,(gc_src)
            ld   a,(hl)                 ; заливка
            or   a
            jp   z,gg_o
            call shift_bits
            call gg_put_fill
gg_o:       ld   hl,(gc_src)
            inc  hl
            ld   a,(hl)                 ; обводка
            or   a
            jp   z,gg_n
            call shift_bits
            ld   c,10
            call gg_put
gg_n:       ld   hl,(gc_src)
            inc  hl
            inc  hl
            ld   (gc_src),hl
            ld   hl,gc_y
            inc  (hl)
            ld   hl,gc_cnt
            dec  (hl)
            jp   nz,gg_row
            ret
gg_put_fill:
            ld   a,(gl_fill)
            ld   c,a
gg_put:     ld   a,(gc_colx)
            cp   31
            jp   nz,gg_p1
            ld   e,0
gg_p1:      ld   h,a
            ld   a,(gc_y)
            ld   b,a
            ld   a,MSX_TOP
            sub  b
            ld   l,a
            jp   put_bits

; ---------------------------------------------------------------- тайл 16x16
; A = тайл, B = x (кратно 8), C = y. gfx_tile — непрозрачно, gfx_tile_tp — TPSET (цвет 0 прозрачен).
tile_addr:                              ; -> DE = данные тайла, HL = видеоадрес плоскости 0 (верх-лево)
            ld   l,a
            ld   h,0
            add  hl,hl
            add  hl,hl
            add  hl,hl
            add  hl,hl
            add  hl,hl
            add  hl,hl
            add  hl,hl                  ; *128
            ld   de,tiles_data
            add  hl,de
            ex   de,hl
            ld   a,b
            rrca
            rrca
            rrca
            and  1Fh
            add  a,80h
            ld   h,a
            ld   a,MSX_TOP
            sub  c
            ld   l,a
            ret

gfx_tile:
            call tile_addr
            ld   a,l
            ld   (gt_row),a
            ld   c,4                    ; плоскости
gt_pl:
            REPT 16
            ld   a,(de)
            ld   (hl),a
            inc  de
            dec  l
            ENDR
            ld   a,(gt_row)
            ld   l,a
            inc  h                      ; второй столбец плоскости
            REPT 16
            ld   a,(de)
            ld   (hl),a
            inc  de
            dec  l
            ENDR
            ld   a,(gt_row)
            ld   l,a
            ld   a,h
            add  a,20h-1                ; первый столбец следующей плоскости
            ld   h,a
            dec  c
            jp   nz,gt_pl
            ret

gfx_tile_tp:
            call tile_addr
            ld   a,l
            ld   (gt_row),a
            ; проход 1: маска = OR четырёх плоскостей
            push hl
            ld   h,d
            ld   l,e
            ld   de,tmask
tm_1:       push hl
            ld   bc,32
            ld   a,(hl)
            add  hl,bc
            or   (hl)
            add  hl,bc
            or   (hl)
            add  hl,bc
            or   (hl)
            ld   (de),a
            pop  hl
            inc  hl
            inc  e
            ld   a,e
            cp   32
            jp   nz,tm_1
            ld   de,-32
            add  hl,de
            ex   de,hl                  ; DE = данные тайла
            pop  hl                     ; HL = видео
            ; проход 2: vram = (vram & ~m) | d
            ld   a,4
            ld   (gt_pln),a
tp_pl:      ld   bc,tmask
tp_col:     ld   a,(bc)
            cpl
            and  (hl)
            ex   de,hl
            or   (hl)
            ex   de,hl
            ld   (hl),a
            inc  de
            inc  c
            dec  l
            ld   a,c
            and  15
            jp   nz,tp_col
            ld   a,(gt_row)             ; столбец пройден
            ld   l,a
            inc  h
            ld   a,c
            cp   32
            jp   nz,tp_col              ; второй столбец той же плоскости
            ld   a,h
            add  a,20h-2
            ld   h,a
            ld   a,(gt_pln)
            dec  a
            ld   (gt_pln),a
            jp   nz,tp_pl
            ret
