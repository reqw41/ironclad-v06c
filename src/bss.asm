; ============================================================================
; bss.asm — переменные библиотеки (обнуляются при старте). Не попадает в образ.
; ============================================================================
            ALIGN 256
tmask:      ds 32               ; маска прозрачности тайла (выровнена на 256)
; vec
frame_cnt:  ds 2
vec_pal:    ds 16               ; текущая палитра (индекс 0 = фон/бордюр)
vec_pal_live: ds 16             ; то, что ISR льёт в цветогенератор
disp_off:   ds 1
kbd_last:   ds 1
kbd_rep:    ds 1
kq_head:    ds 1
kq_tail:    ds 1
kq_buf:     ds KQ_SIZE
sca_sp:     ds 2
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
gs_n:       ds 1
gc_src:     ds 2
gc_colx:    ds 1
gc_y:       ds 1
gc_cnt:     ds 1
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
zx_bits:    ds 1
zx_bt:      ds 1
zx_off:     ds 2
zx_lsb:     ds 1
; util
rnd_seed:   ds 2
rn_n:       ds 1
rn_t:       ds 1
sd_buf:     ds 6
            IFNDEF LIBTEST
            include "game_bss.asm"
            ENDIF
