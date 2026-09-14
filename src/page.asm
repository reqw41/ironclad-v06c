; ============================================================================
; page.asm — видеостраницы MSX 0 («ENEMY WATERS») и 1 («YOUR FLEET») на одном экране.
; Своё у страниц: клетки сетки (слои тайлов/цифр), призрак корабля (стр. 1),
; курсор-спрайт (стр. 0), поле AT:, заголовок. Остальное BASIC рисует на обе
; страницы одинаково — это рисуется прямо в экран.
; Клетка (C,R): x = 24+16C, y = 30+16R; запись = 4 байта слоёв.
; ============================================================================

GX          equ 24
GY          equ 30

; HL = &cellrec[A][C + 10R]: A = страница, B = C, C = R
cell_rec:
            push de
            ld   de,0                   ; page*400
            or   a
            jp   z,cr_p0
            ld   de,400
cr_p0:      ld   a,c                    ; R*10 + C
            add  a,a
            ld   l,a
            add  a,a
            add  a,a
            add  a,l
            add  a,b
            ld   l,a
            ld   h,0
            add  hl,hl
            add  hl,hl                  ; *4
            add  hl,de
            ld   de,cellrec
            add  hl,de
            pop  de
            ret

; B, C = клетка под курсором (cur_x, cur_y)
cur_cell:   LDV  cur_x
            call px2c
            ld   b,a
            LDV  cur_y
            call py2c
            ld   c,a
            ret
; A = клетка по координате y (py2c) / x (px2c); sh4a: A = A>>4
py2c:       sub  GY-GX
px2c:       sub  GX
sh4a:       rrca
            rrca
            rrca
            rrca
            and  0Fh
            ret

; B = C, C = R -> B = x, C = y клетки
cell_xy:
            ld   a,b
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            add  a,GX
            ld   b,a
            ld   a,c
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            add  a,GY
            ld   c,a
            ret

; COPY тайла непрозрачно в клетку: A = страница, B = C, C = R, D = тайл
cell_op:
            STV  co_pg
            push bc
            call cell_rec
            ld   (hl),d
            inc  hl
            ld   (hl),0FFh
            inc  hl
            ld   (hl),0FFh
            inc  hl
            ld   (hl),0FFh
            ld   hl,gfx_tile
            jp   co_tail

; COPY ...,TPSET в клетку: A = страница, B = C, C = R, D = код слоя (тайл или 32+цифра)
cell_tp:
            STV  co_pg
            push bc
            call cell_rec
            ld   e,4
ct_1:       ld   a,(hl)
            cp   0FFh
            jp   z,ct_2
            inc  hl
            dec  e
            jp   nz,ct_1
            dec  hl                     ; слоёв больше 4 не бывает; на всякий случай — последний
ct_2:       ld   (hl),d
            ld   hl,draw_layer_tp
; если страница на экране — нарисовать слой D процедурой HL в клетке B,C, курсор поверх
co_tail:    pop  bc
            LDV  pg_vis
            ld   e,a
            LDV  co_pg
            cp   e
            ret  nz
            push bc
            call cell_xy
            ld   a,d
            call scn_c
            pop  bc
            jp   cell_cursor

; слой D поверх клетки в (B,C) пикселях
draw_layer_tp:
            cp   32
            jp   c,gfx_tile_tp
            sub  32                     ; цифра: набор = (код-32)>>5, номер = код&31
            ld   e,a
            and  31
            ld   d,a
            ld   a,e
            rlca
            rlca
            rlca
            and  3
            ld   hl,glyph_fill
            rst  00h
            ld   e,(hl)
            ld   a,b
            add  a,5
            ld   b,a
            ld   a,c
            add  a,4
            ld   c,a
            ld   a,d
            jp   gfx_glyph
glyph_fill: db 15,7,8

; перерисовать клетку B=C, C=R страницы pg_vis из записи
cell_redraw:
            CPV  pg_vis,2
            ret  nc
            push bc
            call cell_rec
            ld   (cd_p),hl
            pop  bc
            push bc
            call cell_xy
            ld   hl,(cd_p)
            ld   a,(hl)
            cp   0FFh
            jp   nz,cd_t
            ld   a,b                    ; пусто: цвет фона страницы
            add  a,15
            ld   d,a
            ld   a,c
            add  a,15
            ld   e,a
            ld   a,1
            call gfx_fill
            jp   cd_done
cd_t:       push bc
            call gfx_tile
            pop  bc
            SETV cd_n,3
cd_l:       ld   hl,(cd_p)
            inc  hl
            ld   (cd_p),hl
            ld   a,(hl)
            cp   0FFh
            jp   z,cd_done
            push bc
            call draw_layer_tp
            pop  bc
            ld   hl,cd_n
            dec  (hl)
            jp   nz,cd_l
cd_done:    pop  bc
            ; fallthrough — курсор поверх
; если на странице 0 курсор стоит на клетке B=C, C=R — нарисовать его поверх
cell_cursor:
            LDV  pg_vis
            or   a
            ret  nz
            LDV  cur_on
            or   a
            ret  z
            push bc
            call cell_xy
            LDV  cur_x
            cp   b
            jp   nz,cc_no
            LDV  cur_y
            cp   c
            jp   nz,cc_no
            pop  bc
            jp   cur_draw
cc_no:      pop  bc
            ret

; рамка 16x16 спрайта-курсора цветом 11 в (cur_x, cur_y)
cur_draw:
            LDV  cur_x
            ld   b,a
            add  a,15
            ld   d,a
            LDV  cur_y
            ld   c,a
            add  a,15
            ld   e,a
            ld   a,11
            jp   gfx_box

; PUT SPRITE 0,(B,C-1),11 на странице 0
cur_show:
            LDV  cur_on
            or   a
            jp   z,cs_new
            LDV  cur_x
            cp   b
            jp   nz,cs_mv
            LDV  cur_y
            cp   c
            ret  z                      ; уже там
cs_mv:      push bc                     ; стереть на старом месте
            call cur_hide
            pop  bc
cs_new:     ld   a,b
            STV  cur_x
            ld   a,c
            STV  cur_y
            SETV cur_on,1
            LDV  pg_vis
            or   a
            ret  nz
            jp   cur_draw

; PUT SPRITE 0,(0,200),0 — спрятать
cur_hide:
            LDV  cur_on
            or   a
            ret  z
            ZEROV cur_on
            LDV  pg_vis
            or   a
            ret  nz
            call cur_cell               ; клетка под курсором
            jp   cell_redraw

; ---------------------------------------------------------------- призрак 1664-1668
; нарисовать по gh_* (страница 1)
gh_draw:
            CPV  pg_vis,1
            ret  nz
            LDV  gh_on
            or   a
            ret  z
            ZEROV gh_i
            LDV  gh_rx
            ld   b,a
            LDV  gh_ry
            ld   c,a
gd_1:       push bc
            xor  a
            call gfx_tile
            pop  bc
            push bc
            LDV  gh_i
            ld   hl,gh_gt
            rst  00h
            ld   a,(hl)
            call gfx_tile_tp
            pop  bc
            LDV  gh_od
            or   a
            jp   nz,gd_v
            ld   a,b
            add  a,16
            ld   b,a
            jp   gd_2
gd_v:       ld   a,c
            add  a,16
            ld   c,a
gd_2:       INCV gh_i
            LDV  gh_s
            cp   (hl)
            jp   nz,gd_1
            ; рамка композита: зелёная (9) у копии (0,32)/(0,48), красная (8) у (0,128)/(16,48)
            LDV  gh_rx
            ld   b,a
            LDV  gh_rw
            add  a,b
            dec  a
            ld   d,a
            LDV  gh_ry
            ld   c,a
            LDV  gh_rh
            add  a,c
            dec  a
            ld   e,a
            CPV  gh_sy,128
            jp   z,gd_red
            CPV  gh_sx,16
            jp   z,gd_red
            ld   a,9
            jp   gfx_box
gd_red:     ld   a,8
            jp   gfx_box

; убрать призрак: клетки под ним — из записей страницы 1 (1662: COPY со страницы 2)
gh_erase:
            LDV  gh_on
            or   a
            ret  z
            ZEROV gh_on
            CPV  pg_vis,1
            ret  nz
            jp   gh_cells

; ---------------------------------------------------------------- поле AT: (1473)
; нарисовать at_rec[bDP] (если эта страница на экране)
at_draw:
            LDV  bDP
            ld   e,a
            LDV  pg_vis
            cp   e
            ret  nz
at_draw_vis:
            ld   bc,190*256+172
            ld   de,255*256+188
            ld   a,1
            call gfx_fill
            call at_ptr
            ld   a,(hl)
            or   a
            ret  z
            push hl
            ld   bc,192*256+174
            ld   a,9
            call gfx_pset
            ld   a,15
            ld   (gfx_fg),a
            pop  hl
            jp   gfx_puts
; HL = &at_rec[pg_vis]
at_ptr:
            LDV  pg_vis
; HL = &at_rec[A]
at_ptr_a:   add  a,a
            add  a,a
            add  a,a
            ld   hl,at_rec
            jp   add_a_hl

; ---------------------------------------------------------------- заголовок страницы (1370)
hdr_draw:
            ld   bc,24*256+4
            ld   de,119*256+11
            ld   a,1
            call gfx_fill
            ld   bc,24*256+4
            ld   a,11
            call gfx_pset
            ld   a,15
            ld   (gfx_fg),a
            ld   hl,s_enemy_waters
            LDV  pg_vis
            or   a
            jp   z,gfx_puts
            ld   hl,s_your_fleet
            jp   gfx_puts
s_enemy_waters: TXT  "ENEMY WATERS"
s_your_fleet:   TXT  "YOUR FLEET"

; ---------------------------------------------------------------- SET PAGE DP,DP
; A = страница 0/1. Если на экране другая страница игры — перерисовать своё;
; если на экране иной экран (помощь, победа) — полная перерисовка (render_full в игре).
page_show:
            ld   e,a
            LDV  pg_vis
            cp   e
            ret  z
            cp   2
            ld   a,e
            STV  pg_vis
            jp   nc,render_full
            call hdr_draw
            ; клетки: только те, чьи слои на двух страницах различаются
            ld   hl,cellrec
            ld   de,cellrec+400
            ld   bc,0
ps_c:       push hl
            push de
            ld   b,4
ps_cmp:     ld   a,(de)
            cp   (hl)
            jp   nz,ps_diff
            inc  hl
            inc  de
            dec  b
            jp   nz,ps_cmp
            jp   ps_same
ps_diff:    push bc
            ld   a,c                    ; индекс = C + 10R -> B = C, C = R
            call div10
            ld   c,a
            call cell_redraw
            pop  bc
ps_same:    pop  de
            pop  hl
ps_next:    ld   a,4
            rst  00h
            ex   de,hl
            ld   a,4
            rst  00h
            ex   de,hl
            inc  c
            ld   a,c
            cp   100
            jp   c,ps_c
            ; оверлеи прежней страницы: клетки под ними перерисовать новой страницей
            LDV  pg_vis
            or   a
            jp   z,ps_0
            LDV  cur_on             ; ушли со страницы 0: клетка под курсором
            or   a
            jp   z,ps_n
            call cur_cell
            call cell_redraw
            call gh_draw
            jp   ps_n
ps_0:       LDV  gh_on              ; ушли со страницы 1: клетки под призраком
            or   a
            jp   z,ps_0c
            call gh_cells
ps_0c:      LDV  cur_on
            or   a
            call nz,cur_draw
ps_n:       jp   at_draw_vis

; перерисовать клетки под призраком из записей страницы pg_vis — по прямоугольнику
; RX,RY,RW,RH (как COPY со страницы 2 в 1662), а не по композиту: при повороте композит
; уже пересобран под новую ориентацию, а стирать надо старый прямоугольник
gh_cells:   LDV  gh_rx
            call px2c
            STV  gh_c0
            ld   b,a
            LDV  gh_ry
            call py2c
            ld   c,a
            LDV  gh_rh
            call sh4a
            STV  gh_i               ; строк
ghc_r:      LDV  gh_rw
            call sh4a
            STV  gh_n               ; столбцов
ghc_c:      push bc
            call cell_redraw
            pop  bc
            inc  b
            ld   hl,gh_n
            dec  (hl)
            jp   nz,ghc_c
            LDV  gh_c0
            ld   b,a
            inc  c
            ld   hl,gh_i
            dec  (hl)
            jp   nz,ghc_r
            ret

; все 100 клеток страницы A = тайл воды (1154: COPY(96,32)-(255,191) — фон сетки = 100 тайлов 0)
cells_water:
            STV  cw_pg
            ld   hl,cw_1
; процедура HL для всех клеток: B = 0..9 (внешний), C = 0..9
for_cells:  ld   bc,0
fc_1:       push bc
            push hl
            call scn_c
            pop  hl
            pop  bc
            inc  c
            ld   a,c
            cp   10
            jp   nz,fc_1
            ld   c,0
            inc  b
            ld   a,b
            cp   10
            jp   nz,fc_1
            ret
cw_1:       LDV  cw_pg
            ld   d,0
            jp   cell_op
