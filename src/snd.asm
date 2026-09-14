; ============================================================================
; snd.asm — звук на ВИ53 (три прямоугольных канала, без громкости и без шума).
;
; SOUND MSX (строка 2600): шум канала A с огибающей-спадом (R6 = S1, R12 = S2).
; У ВИ53 шума нет — даём его каналами со случайными делителями, которые меняются
; каждый кадр в полосе частоты шума; спад огибающей передаём числом звучащих
; каналов (3 -> 2 -> 1 -> тишина). Длина спада огибающей AY = S2*65536/1789772 с
; = S2*36.6 мс = S2*1.83 кадра.
; PLAY MSX (2627, 2635): две короткие мелодии, ноты = делители ВИ53 (1.5 МГц / f).
; Всё звучание ведёт ISR; основной код только заводит эффект — как фоновый PSG MSX.
; ============================================================================

snd_init:                               ; (sfx_t, mus_on — нули: lowbss обнулена на старте)
            ld   hl,0ACE1h
            ld   (sfx_rs),hl
snd_mute:
            ld   a,36h
            out  (VI_CTL),a
            ld   a,76h
            out  (VI_CTL),a
            ld   a,0B6h
            out  (VI_CTL),a
            ret

; SOUND 7,55:8,16:11,0:13,0:6,S1:12,S2 — A = S1 (период шума), C = S2 (огибающая)
snd_noise:
            ld   (sn_s1),a
            ld   a,c                    ; кадров = S2*2 - S2/8 (~S2*1.83)
            rrca
            rrca
            rrca
            and  1Fh
            ld   e,a
            ld   a,c
            add  a,a
            sub  e
            jp   nz,sn_1
            inc  a
sn_1:       ld   d,a
            ld   a,(sn_s1)              ; делитель ВИ53 для частоты шума: S1*13
            ld   l,a
            ld   h,0
            add  hl,hl
            add  hl,hl                  ; *4
            ld   b,h
            ld   c,l
            add  hl,hl                  ; *8
            add  hl,bc                  ; *12
            ld   c,a
            ld   b,0
            add  hl,bc                  ; *13
            di
            ld   (sfx_div),hl
            ld   a,d
            ld   (sfx_t),a
            ld   (sfx_n),a
            ei
            ret

; PLAY: HL = мелодия (dw голос0, dw голос1). Шумовой эффект гасится.
mus_start:
            di
            ld   de,mus_p
            ld   bc,4
            call memcpy
            xor  a
            ld   (mus_cnt),a
            ld   (mus_cnt+1),a
            ld   (sfx_t),a
            inc  a
            ld   (mus_on),a
            ei
            ret

; ---------------------------------------------------------------- ISR, раз в кадр
snd_isr:
            ld   a,(mus_on)
            or   a
            jp   nz,mus_frame
            ld   a,(sfx_t)
            or   a
            ret  z
            dec  a
            ld   (sfx_t),a
            jp   z,snd_mute
            ; звучащих каналов = ceil(3*t/n)
            ld   b,a
            add  a,a
            add  a,b                    ; 3t
            ld   b,a
            ld   a,(sfx_n)
            ld   c,a
            ld   a,b
            ld   d,0
sx_div:     sub  c
            jp   c,sx_d1
            inc  d
            jp   sx_div
sx_d1:      add  a,c
            jp   z,sx_d2
            inc  d
sx_d2:      xor  a
sx_lp:      ld   (sx_ch),a
            cp   d
            jp   nc,sx_off
            push de
            call sx_rnddiv
            ld   a,(sx_ch)
            call vi_set
            pop  de
            jp   sx_nx
sx_off:     push de
            call vi_off
            pop  de
sx_nx:      ld   a,(sx_ch)
            inc  a
            cp   3
            jp   nz,sx_lp
            ret

; HL = делитель шума: base*(1 + r&3) + (r>>8 & 63)
sx_rnddiv:
            ld   hl,(sfx_rs)
            call xs16                   ; xorshift16 (7,9,8)
            ld   (sfx_rs),hl
            ld   a,h
            and  63
            ld   c,a
            ld   a,l
            and  3
            ld   b,a
            ld   hl,(sfx_div)
            ex   de,hl
            ld   h,d
            ld   l,e
sr_1:       ld   a,b
            or   a
            jp   z,sr_2
            add  hl,de
            dec  b
            jp   sr_1
sr_2:       ld   b,0
            add  hl,bc
            ret

; A = канал, HL = делитель: режим 3 и пуск
vi_set:
            push hl
            call vi_cw
            out  (VI_CTL),a
            pop  hl
            ld   a,l
            call vd_op
            ld   a,h
            jp   vd_op
; A = канал: заглушить (управляющее слово без делителя — выход стоит в 1)
vi_off:
            call vi_cw
            out  (VI_CTL),a
            ret
; A = канал -> A = управляющее слово режима 3; порт данных канала вписан в vd_op
vi_cw:
            add  a,a
            ld   hl,vi_tab
            rst  00h
            inc  hl
            ld   a,(hl)
            ld   (vd_op+1),a
            dec  hl
            ld   a,(hl)
            ret
vd_op:      out  (VI_CH0),a             ; самомодифицируемый порт (трогает только ISR)
            ret
vi_tab:     db 36h,VI_CH0, 76h,VI_CH1, 0B6h,VI_CH2

; ---------------------------------------------------------------- мелодии
mus_frame:
            xor  a
            ld   (mus_live),a
            call mus_voice              ; голос 0
            ld   a,1
            call mus_voice
            ld   a,(mus_live)
            or   a
            ret  nz
            ld   (mus_on),a
            jp   snd_mute

; A = голос (0/1)
mus_voice:
            ld   (mv_v),a
            ld   hl,mus_cnt
            rst  00h
            ld   a,(hl)
            or   a
            jp   z,mv_fetch
            dec  (hl)
            jp   z,mv_fetch
            ld   a,1
            ld   (mus_live),a
            ret
mv_fetch:   push hl                     ; -> mus_cnt[v]
            ld   a,(mv_v)
            add  a,a
            ld   hl,mus_p
            rst  00h               ; HL -> mus_p[v]
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            dec  hl
            ld   a,d
            or   e
            jp   z,mv_idle
            ex   de,hl                  ; HL = нота, DE -> mus_p[v]
            ld   c,(hl)
            inc  hl
            ld   b,(hl)
            inc  hl
            ld   a,b
            or   c
            jp   z,mv_stop
            ld   a,(hl)
            inc  hl
            ex   de,hl                  ; HL -> mus_p[v], DE = следующая нота
            ld   (hl),e
            inc  hl
            ld   (hl),d
            pop  hl
            ld   (hl),a                 ; длительность ноты
            ld   h,b
            ld   l,c
            ld   a,(mv_v)
            call vi_set
            ld   a,1
            ld   (mus_live),a
            ret
mv_stop:    ex   de,hl
            xor  a
            ld   (hl),a
            inc  hl
            ld   (hl),a
            ld   a,(mv_v)
            call vi_off
mv_idle:    pop  hl
            ret

; 2627: PLAY "T140O4L8V12EDCO3AG","T140O3L8V9CO2B-AG" — восьмые при T140 = 10.7 кадра
mus_sunk:   dw ms_v0, ms_v1
ms_v0:      dw 4551
            db 11
            dw 5108
            db 11
            dw 5733
            db 10
            dw 6818
            db 11
            dw 7653
            db 11
            dw 0
ms_v1:      dw 11467
            db 11
            dw 12871
            db 11
            dw 13636
            db 10
            dw 15306
            db 11
            dw 0
; 2635: PLAY "T220O5L32V10CG" — тридцать вторые при T220 = 1.7 кадра
mus_blip:   dw mb_v0, mb_none
mb_v0:      dw 2867
            db 2
            dw 1913
            db 2
mb_none:    dw 0
