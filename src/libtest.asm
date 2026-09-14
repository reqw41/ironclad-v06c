; ============================================================================
; libtest.asm — проверка библиотеки на стенде (сборка с -DLIBTEST)
; ============================================================================
libtest:
            ld   hl,pal_game
            call pal_set
            ei
            ld   bc,0                   ; LINE(0,0)-(255,211),1,BF
            ld   de,255*256+211
            ld   a,1
            call gfx_fill
            ld   bc,23*256+29           ; рамка сетки
            ld   de,184*256+190
            ld   a,12
            call gfx_box
            ld   bc,24*256+4
            ld   a,11
            call gfx_pset
            ld   a,15
            ld   (gfx_fg),a
            ld   hl,lt_s1
            call gfx_puts
            ld   bc,4*256+192
            ld   a,11
            call gfx_pset
            ld   a,11
            ld   (gfx_fg),a
            ld   hl,lt_s2
            call gfx_puts
            ; тайлы 0..9 непрозрачно в ряд 0 сетки, 10..22 поверх воды в ряды 1..2
            ld   b,24
            ld   c,30
            xor  a
lt_t1:      push af
            push bc
            call gfx_tile
            pop  bc
            pop  af
            inc  a
            ld   d,a
            ld   a,b
            add  a,16
            ld   b,a
            ld   a,d
            cp   10
            jp   nz,lt_t1
            ld   a,10
            ld   (lt_n),a
            ld   b,24
            ld   c,46
lt_t2:      push bc
            xor  a
            call gfx_tile
            pop  bc
            push bc
            ld   a,(lt_n)
            call gfx_tile_tp
            pop  bc
            ld   a,b
            add  a,16
            ld   b,a
            cp   184
            jp   nz,lt_t3
            ld   b,24
            ld   a,c
            add  a,16
            ld   c,a
lt_t3:      ld   a,(lt_n)
            inc  a
            ld   (lt_n),a
            cp   23
            jp   nz,lt_t2
            ; глифы: 0..9 трёх цветов поверх воды, ряды 4..6
            xor  a
            ld   (lt_n),a
lt_g1:      ld   a,(lt_n)
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            add  a,24
            ld   b,a
            push bc
            ld   c,94
            xor  a
            call gfx_tile
            pop  bc
            push bc
            ld   c,110
            xor  a
            call gfx_tile
            pop  bc
            push bc
            ld   c,126
            xor  a
            call gfx_tile
            pop  bc
            ld   a,b
            add  a,5
            ld   b,a
            push bc
            ld   c,98
            ld   a,(lt_n)
            ld   e,15
            call gfx_glyph
            pop  bc
            push bc
            ld   c,114
            ld   a,(lt_n)
            ld   e,7
            call gfx_glyph
            pop  bc
            ld   c,130
            ld   a,(lt_n)
            ld   e,8
            call gfx_glyph
            ld   a,(lt_n)
            inc  a
            ld   (lt_n),a
            cp   10
            jp   nz,lt_g1
            ld   hl,mus_sunk
            call mus_start
lt_idle:    call getkey
            cp   ' '
            jp   nz,lt_n2
            ld   a,30
            ld   c,31
            call snd_noise
            jp   lt_idle
lt_n2:      cp   'V'
            jp   nz,lt_idle
            call disp_blank
            ld   hl,img_victory
            ld   de,8000h
            call dzx0
            ld   hl,pal_end
            call pal_set
            call disp_on
            jp   lt_idle

lt_s1:      db "ENEMY WATERS  Press SPACE ...?",0
lt_s2:      db "HITS: 1/3 [B] SANK: CAR",0
lt_n:       db 0
