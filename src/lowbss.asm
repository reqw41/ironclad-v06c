; ============================================================================
; lowbss.asm — переменные библиотеки в свободной памяти под $0100 ($0060..$00FF).
; Образ .rom грузится с $0100, ниже — только вектор RST7 ($0038) и маска тайла ($0040).
; ============================================================================
            org  LOWBSS
; vec
frame_cnt:  ds 2
vec_pal:    ds 16               ; текущая палитра (индекс 0 = фон/бордюр)
vec_pal_live: ds 16             ; то, что ISR льёт в цветогенератор
disp_off:   ds 1
vec_border: ds 1
cur_cmap:   ds 2
rt_src:     ds 2
rt_dst:     ds 2
rt_pl:      ds 1
rt_r:       ds 1
kbd_rows:   ds 8        ; ряды клавиатуры 0..7, прочитанные в ISR (0 = нажата)
kbd_last:   ds 1
kbd_rep:    ds 1
kq_head:    ds 1
kq_tail:    ds 1
kq_buf:     ds KQ_SIZE
; gfx
gf_col:     ds 1
gf_h:       ds 1
gf_row:     ds 1
gf_lm:      ds 1
gf_rm:      ds 1
gf_c1:      ds 1
fc_pl:      ds 1
gb_col:     ds 1
gp_col:     ds 1
gp_row:     ds 1
gp_cx:      ds 1
gfx_x:      ds 1
gfx_y:      ds 1
gfx_fg:     ds 1
gfx_bg:     ds 1
gfx_pitch:  ds 1
gfx_bold:   ds 1
gs_n:       ds 1
gc_src:     ds 2
gc_colx:    ds 1
gc_y:       ds 1
gc_cnt:     ds 1
gc_rows:    ds 16
gc_ml:      ds 1
gc_mr:      ds 1
gc_f:       ds 1
gc_b:       ds 1
gl_fill:    ds 1
gt_row:     ds 1
gt_pln:     ds 1
; snd
sfx_t:      ds 1
sfx_n:      ds 1
sfx_div:    ds 2
sfx_rs:     ds 2
sn_s1:      ds 1
sx_ch:      ds 1
mus_on:     ds 1
mus_live:   ds 1
mus_p:      ds 4
mus_cnt:    ds 2
mv_v:       ds 1
; zx0
zx_off:     ds 2
; util
rnd_seed:   ds 2
rn_n:       ds 1
rn_t:       ds 1
sd_buf:     ds 6
lowbss_end:
            ASSERT lowbss_end <= 100h
