; ============================================================================
; gfx.asm — графические примитивы в координатах экрана MSX (x 0..255, y 0..211).
; Строка MSX y -> строка памяти Вектора 233-y (сдвиг 22 строки вниз), столбец = x>>3.
; 8-цветный режим: экран — плоскости $8000/$A000/$C000, в них биты 2/1/0 номера СЛОТА;
; номер цвета MSX переводится в слот таблицей текущего экрана cur_cmap (col2bits).
; Плоскость $E000 — память программы, её рисование не трогает.
; ============================================================================

MSX_TOP     equ 233             ; строка памяти для y = 0
NPL         equ 3               ; плоскостей экрана

; A = цвет MSX -> A = слот<<5 (биты 7,6,5 — плоскости $8000,$A000,$C000). HL сохраняется.
col2bits:
            push hl
            ld   hl,(cur_cmap)
            rst  00h
            ld   a,(hl)
            rrca
            rrca
            rrca
            pop  hl
            ret
tmask       equ 0040h           ; маска прозрачности тайла: 32 байта в свободной памяти под $0100

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
            cp   0FFh
            jp   z,fill_full
            ld   e,a
            cpl
            ld   d,a
            ld   a,h
            add  a,80h
            ld   h,a
            ld   a,(gf_col)
            call col2bits
            ld   c,a
            ld   a,NPL
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

; целый столбец байтов: запись без чтения
fill_full:
            ld   a,h
            add  a,80h
            ld   h,a
            ld   a,(gf_col)
            call col2bits
            ld   c,a
            ld   e,NPL
ff_pl:      ld   a,(gf_row)
            ld   l,a
            ld   a,(gf_h)
            ld   b,a
            ld   a,c
            rlca
            ld   c,a
            sbc  a,a                    ; FF, если бит цвета 1
ff_1:       ld   (hl),a
            dec  l
            dec  b
            jp   nz,ff_1
            ld   a,h
            add  a,20h
            ld   h,a
            dec  e
            jp   nz,ff_pl
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
            call col2bits
            ld   c,a
            ld   b,NPL
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
; Строка HL (0 в конце) с графического курсора (gfx_x, gfx_y): знак — цветом gfx_fg,
; остальное знакоместо 8x8 — цветом фона gfx_bg (COLOR fg,bg): так рисует SCREEN 5 MSX2,
; точка PSET перед PRINT на скриншотах оригинала не видна. Курсор +8 точек на знак.
; Слова словаря (байт >= 80h, TXT) раскрываются. HL на выходе -> нуль строки.
gfx_puts:
            ld   a,(hl)
            or   a
            ret  z
            jp   m,gp_w
            push hl
            call gfx_putc
            pop  hl
            inc  hl
            jp   gfx_puts
gp_w:       push hl
            call dict_word
gp_w1:      ld   a,(hl)
            push hl
            push af
            and  7Fh
            call gfx_putc
            pop  af
            pop  hl
            inc  hl
            or   a
            jp   p,gp_w1
            pop  hl
            inc  hl
            jp   gfx_puts

; знак A (быстрый путь: строки знака сдвигаются один раз, по плоскостям — 4 вида цикла)
gfx_putc:
            sub  32
            ret  c
            cp   64                     ; коды 96..127 — ячейка из таблицы (строчные)
            jp   c,pc_c
            sub  64
            ld   hl,lc_map
            call tab_a
pc_c:       ld   l,a
            ld   h,0
            ld   d,h
            ld   e,l
            add  hl,hl
            add  hl,de
            add  hl,hl
            add  hl,de                  ; *7
            ld   de,font_data
            add  hl,de                  ; HL -> 7 строк знака (8-я — пустая)
            ld   a,(gfx_x)
            and  7
            ld   c,a                    ; сдвиг s
            ld   de,gc_rows
            ld   b,7
pc_sh:      ld   a,(gfx_bold)           ; жирно: строка | строка>>1 (штрих 2 точки)
            or   a
            ld   a,(hl)
            jp   z,pc_nb
            push de
            ld   d,a
            or   a
            rra
            or   d
            pop  de
pc_nb:      push hl
            ld   h,a
            ld   l,0
            ld   a,c
            or   a
            jp   z,pc_s0
pc_s1:      ld   a,h                    ; HL >>= 1
            or   a
            rra
            ld   h,a
            ld   a,l
            rra
            ld   l,a
            dec  c
            jp   nz,pc_s1
pc_s0:      ld   a,h
            ld   (de),a
            inc  de
            ld   a,l
            ld   (de),a
            inc  de
            ld   a,(gfx_x)
            and  7
            ld   c,a
            pop  hl
            inc  hl
            dec  b
            jp   nz,pc_sh
            xor  a                      ; строка 7 — пустая
            ld   (de),a
            inc  de
            ld   (de),a
            ld   hl,lmask_tab           ; маски знакоместа: ML = FF>>s, MR = ~ML
            ld   a,c
            call tab_a
            ld   (gc_ml),a
            cpl
            ld   (gc_mr),a
            ld   a,(gfx_x)              ; адрес: плоскость 0
            rrca
            rrca
            rrca
            and  1Fh
            ld   (gc_colx),a
            add  a,80h
            ld   h,a
            ld   a,(gfx_y)
            ld   b,a
            ld   a,MSX_TOP
            sub  b
            ld   l,a
            ld   (gc_y),a
            ld   a,(gfx_fg)             ; цвета: биты плоскостей в старшие биты
            call col2bits
            ld   (gc_f),a
            ld   a,(gfx_bg)
            call col2bits
            ld   (gc_b),a
            ld   a,NPL
            ld   (gc_cnt),a
pc_pl:      ld   a,(gc_f)               ; вид цикла по битам (знак, фон) плоскости
            rlca
            ld   (gc_f),a
            ld   a,(gc_b)
            jp   c,pc_f1
            rlca
            ld   (gc_b),a
            jp   c,pc_01
            ; (0,0): знакоместо цветом 0
            ld   a,(gc_ml)
            cpl
            ld   c,a
            call pc_clr
            ld   a,(gc_mr)
            cpl
            ld   c,a
            call pc_clr_r
            jp   pc_nx
pc_f1:      rlca
            ld   (gc_b),a
            jp   nc,pc_10
            ; (1,1): знакоместо цветом 1
            ld   a,(gc_ml)
            ld   c,a
            call pc_set
            ld   a,(gc_mr)
            ld   c,a
            call pc_set_r
            jp   pc_nx
pc_10:      ; (1,0): (old & ~M) | g
            ld   a,(gc_ml)
            cpl
            ld   c,a
            ld   de,gc_rows
            call pc_gly
            ld   a,(gc_mr)
            cpl
            ld   c,a
            ld   de,gc_rows+1
            call pc_gly_r
            jp   pc_nx
pc_01:      ; (0,1): (old & ~M) | (g ^ M)
            ld   a,(gc_ml)
            ld   b,a
            ld   de,gc_rows
            call pc_inv
            ld   a,(gc_mr)
            ld   b,a
            ld   de,gc_rows+1
            call pc_inv_r
pc_nx:      ld   a,h
            add  a,20h
            ld   h,a
            ld   a,(gc_cnt)
            dec  a
            ld   (gc_cnt),a
            jp   nz,pc_pl
            ld   a,(gfx_pitch)          ; шаг знака: 8 (PRINT#1) или 6 (подписи экранов итога)
            ld   b,a
            ld   a,(gfx_x)
            add  a,b
            ld   (gfx_x),a
            ret
; правый байт знакоместа — в следующем столбце (если он есть на экране)
pc_clr_r:   call pc_right
            ret  z
            call pc_clr
            dec  h
            ret
pc_set_r:   call pc_right
            ret  z
            call pc_set
            dec  h
            ret
pc_gly_r:   call pc_right
            ret  z
            call pc_gly
            dec  h
            ret
pc_inv_r:   call pc_right
            ret  z
            call pc_inv
            dec  h
            ret
; Z = правого байта нет (сдвиг 0 или столбец 31); иначе H+1
pc_right:   ld   a,(gfx_x)
            and  7
            ret  z
            ld   a,(gc_colx)
            cp   31
            jp   z,pr_z
            inc  h
            or   1                      ; NZ
            ret
pr_z:       xor  a
            ret
; 8 строк вниз от gc_y: AND C
pc_clr:     ld   a,(gc_y)
            ld   l,a
            ld   b,8
pcc_1:      ld   a,(hl)
            and  c
            ld   (hl),a
            dec  l
            dec  b
            jp   nz,pcc_1
            ret
; OR C
pc_set:     ld   a,(gc_y)
            ld   l,a
            ld   b,8
pcs_1:      ld   a,(hl)
            or   c
            ld   (hl),a
            dec  l
            dec  b
            jp   nz,pcs_1
            ret
; (old & C) | (DE), DE += 2
pc_gly:     ld   a,(gc_y)
            ld   l,a
            ld   b,8
pcg_1:      ld   a,(de)
            push de
            ld   e,a
            ld   a,(hl)
            and  c
            or   e
            ld   (hl),a
            pop  de
            inc  de
            inc  de
            dec  l
            dec  b
            jp   nz,pcg_1
            ret
; (old & ~B) | ((DE) ^ B), DE += 2
pc_inv:     ld   a,(gc_y)
            ld   l,a
            ld   c,8
pci_1:      ld   a,(de)
            xor  b
            push de
            ld   e,a
            ld   a,b
            cpl
            and  (hl)
            or   e
            ld   (hl),a
            pop  de
            inc  de
            inc  de
            dec  l
            dec  c
            jp   nz,pci_1
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
            add  hl,hl                  ; *32
            ld   d,h
            ld   e,l
            add  hl,hl                  ; *64
            add  hl,de                  ; *96
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
            ld   c,NPL                  ; плоскости
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
            ld   (de),a
            pop  hl
            inc  hl
            inc  e
            ld   a,e
            cp   low (tmask+32)
            jp   nz,tm_1
            ld   de,-32
            add  hl,de
            ex   de,hl                  ; DE = данные тайла
            pop  hl                     ; HL = видео
            ; проход 2: vram = (vram & ~m) | d
            ld   a,NPL
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
            cp   low (tmask+32)
            jp   nz,tp_col              ; второй столбец той же плоскости
            ld   a,h
            add  a,20h-2
            ld   h,a
            ld   a,(gt_pln)
            dec  a
            ld   (gt_pln),a
            jp   nz,tp_pl
            ret

; ---------------------------------------------------------------- тайлы и глифы -> tiles_data
tiles_load: ld   hl,tiles_zx0
            ld   de,tiles_data
            call dzx0
            ; fallthrough
; ---------------------------------------------------------------- поворот тайлов
; вертикальные тайлы кораблей = горизонтальные, повёрнутые на 90° по часовой:
; новая точка (строка r, столбец c) = старая (строка 15-c, столбец r); по плоскостям
rot_tiles:
            ld   hl,rot_pairs
rt_pair:    ld   a,(hl)
            cp   255
            ret  z
            inc  hl
            push hl
            call rt_addr
            ex   de,hl
            ld   (rt_src),hl
            pop  hl
            ld   a,(hl)
            inc  hl
            push hl
            call rt_addr
            ex   de,hl
            ld   (rt_dst),hl
            ld   a,NPL
            ld   (rt_pl),a
rt_plane:   xor  a
            ld   (rt_r),a
rt_row:     ld   a,(rt_r)               ; маска бита столбца r и столбец-байт (r>>3)*16
            and  7
            ld   b,a
            ld   a,80h
            inc  b
rt_m:       dec  b
            jp   z,rt_m2
            rrca
            jp   rt_m
rt_m2:      ld   c,a                    ; C = маска
            ld   a,(rt_r)
            and  8
            add  a,a                    ; 0 или 16
            ld   hl,(rt_src)
            rst  00h
            ld   de,15
            add  hl,de                  ; -> строка 15 (c = 0)
            ld   de,0                   ; D:E — новая строка (16 точек)
            ld   b,16
rt_c:       ld   a,(hl)
            and  c
            add  a,0FFh                 ; CY = точка
            ld   a,e
            rla
            ld   e,a
            ld   a,d
            rla
            ld   d,a
            dec  hl
            dec  b
            jp   nz,rt_c
            ld   hl,(rt_dst)            ; левый байт -> столбец 0, правый -> столбец 1
            ld   a,(rt_r)
            rst  00h
            ld   (hl),d
            ld   a,16
            rst  00h
            ld   (hl),e
            ld   hl,rt_r
            inc  (hl)
            ld   a,(hl)
            cp   16
            jp   c,rt_row
            ld   hl,(rt_src)            ; следующая плоскость: +32
            ld   de,32
            add  hl,de
            ld   (rt_src),hl
            ld   hl,(rt_dst)
            add  hl,de
            ld   (rt_dst),hl
            ld   hl,rt_pl
            dec  (hl)
            jp   nz,rt_plane
            pop  hl
            jp   rt_pair
; A = тайл -> DE = адрес его данных
rt_addr:    ld   b,0
            call tile_addr
            ret
