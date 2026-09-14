; ============================================================================
; vec.asm — железо Вектора-06Ц: порты, ISR, палитра, клавиатура (как INKEY$ MSX),
; счётчик кадров, ожидания. i8080 (собирается sjasmplus --i8080).
; ============================================================================

PPI_CW      equ 00h
PPI_C       equ 01h         ; in: б5 СС (0 = нажата)
PPI_B       equ 02h         ; out: индекс палитры/бордюра (мл. ниббл), б4 = режим 512; in: столбцы клавиатуры
PPI_A       equ 03h         ; out: вертикальный скролл И выбор ряда клавиатуры (активный 0)
PAL_PORT    equ 0Ch
VI_CTL      equ 08h         ; ВИ53: управляющее слово
VI_CH0      equ 0Bh         ; счётчики 0/1/2 (адреса на Векторе переставлены)
VI_CH1      equ 0Ah
VI_CH2      equ 09h

KEY_REP1    equ 20          ; кадров до первого автоповтора
KEY_REP2    equ 3           ; кадров между повторами
KQ_SIZE     equ 16          ; буфер клавиш (степень двойки)

; ---------------------------------------------------------------- старт железа
; Вызывать под DI. Портит всё.
vec_init:
            ld   a,8Ah                  ; ВВ55: A — выход, B — вход, C старшие — вход, C младшие — выход
            out  (PPI_CW),a
            ld   a,0FFh
            out  (PPI_A),a              ; скролл в норму
            xor  a
            out  (PPI_C),a
            ld   a,0C3h                 ; RST7 ($38) -> isr
            ld   (38h),a
            ld   hl,isr
            ld   (39h),hl
            call snd_init
            jp   scr_clear_all

; ---------------------------------------------------------------- прерывание 50 Гц
isr:
            push af
            push bc
            push de
            push hl
            ; палитра -> цветогенератор (защёлкивается по кадру, льём каждый кадр)
            ld   hl,vec_pal_live+15
            ld   c,15
isr_pal:
            ld   a,c
            out  (PPI_B),a
            ld   a,(hl)
            dec  hl
            out  (PAL_PORT),a
            out  (PAL_PORT),a
            out  (PAL_PORT),a
            out  (PAL_PORT),a
            dec  c
            jp   p,isr_pal
            ld   a,(vec_border)
            out  (PPI_B),a              ; бордюр: индекс 0 (слот фона) или 8 (слот 4 экранов итога)
            ld   hl,(frame_cnt)
            inc  hl
            ld   (frame_cnt),hl
            call kbd_isr
            ld   a,0FFh
            out  (PPI_A),a              ; после опроса клавиатуры — скролл на место
            call snd_isr
            pop  hl
            pop  de
            pop  bc
            pop  af
            ei
            ret

; ---------------------------------------------------------------- палитра
; HL = 8 байт палитры 8-цветного режима (цвет слота k -> индексы 2k и 2k+1; слот 0 = бордюр/фон).
; Копирует в vec_pal (текущая) и, если экран не погашен, в vec_pal_live (то, что льёт ISR).
pal_set:
            ld   de,vec_pal
            ld   b,8
ps_1:       ld   a,(hl)
            ld   (de),a
            inc  de
            ld   (de),a
            inc  de
            inc  hl
            dec  b
            jp   nz,ps_1
            ld   a,(disp_off)
            or   a
            ret  nz
            jp   pal_live

; VDP(1)=VDP(1) AND 191 — погасить экран: весь экран цветом фона (индекс 0).
disp_blank:
            ld   a,1
            ld   (disp_off),a
            ld   a,(vec_pal)
            ld   hl,vec_pal_live
            ld   b,16
db_1:       ld   (hl),a
            inc  hl
            dec  b
            jp   nz,db_1
            ret

; VDP(1)=VDP(1) OR 64 — включить экран.
disp_on:
            xor  a
            ld   (disp_off),a
pal_live:
            ld   hl,vec_pal
            ld   de,vec_pal_live
            ld   bc,16
            jp   memcpy

; ---------------------------------------------------------------- ожидание
; wait_frames: A = число кадров (1..255).
wait_frames:
            ld   b,a
wf_1:       ei
            halt
            dec  b
            jp   nz,wf_1
            ret

; ---------------------------------------------------------------- клавиатура
; Опрос в ISR: первая нажатая клавиша с кодом -> буфер; удержание -> автоповтор
; (как буфер клавиатуры MSX, из которого читает INKEY$).
kbd_isr:
            ld   l,0                    ; номер клавиши = ряд*8 + бит
            ld   b,0FEh                 ; маска ряда 0
            ld   c,0                    ; найденный код
ki_row:
            ld   a,b
            out  (PPI_A),a
            in   a,(PPI_B)
            cpl                         ; 1 = нажата
            ld   e,8
ki_bit:
            rra
            jp   nc,ki_nb
            ld   d,a
            ld   a,c
            or   a
            jp   nz,ki_nb0              ; уже нашли более раннюю
            ld   a,l
            call kbd_code
            ld   c,a
ki_nb0:     ld   a,d
ki_nb:      inc  l
            dec  e
            jp   nz,ki_bit
            ld   a,b
            rlca
            ld   b,a
            jp   c,ki_row               ; пока ноль не прошёл все 8 рядов
            ; C = код (0 — ничего). СС + '/' = '?', без СС тоже '?' (клавиша «/ ?»)
            ld   a,c
            or   a
            jp   nz,ki_key
            ld   (kbd_last),a
            ret
ki_key:
            ld   a,(kbd_last)
            cp   c
            jp   z,ki_hold
            ld   a,c
            ld   (kbd_last),a
            ld   a,KEY_REP1
            ld   (kbd_rep),a
            jp   kq_put
ki_hold:
            ld   hl,kbd_rep
            dec  (hl)
            ret  nz
            ld   (hl),KEY_REP2
            ; fallthrough: C = код
; положить C в буфер (если есть место)
kq_put:
            ld   a,(kq_tail)
            ld   e,a
            inc  a
            and  KQ_SIZE-1
            ld   hl,kq_head
            cp   (hl)
            ret  z                      ; полон
            ld   (kq_tail),a
            ld   d,0
            ld   hl,kq_buf
            add  hl,de
            ld   (hl),c
            ret

; INKEY$: A = код клавиши или 0. Портит HL, DE.
inkey:
            di
            ld   a,(kq_head)
            ld   hl,kq_tail
            cp   (hl)
            jp   z,ik_none
            ld   e,a
            inc  a
            and  KQ_SIZE-1
            ld   (kq_head),a
            ld   d,0
            ld   hl,kq_buf
            add  hl,de
            ld   a,(hl)
            ei
            or   a
            ret
ik_none:    xor  a
            ei
            ret

; ждать клавишу: A = код
getkey:
            call inkey
            ret  nz
            ei
            halt
            jp   getkey

; A = номер клавиши (ряд 0..7 * 8 + бит 0..7) -> A = код (MSX: 28 ->, 29 <-, 30 вверх, 31 вниз).
; Ряд 0: ТАБ ПС ВК ЗБ <- ^ -> v (таблица); ряд 1 (F-клавиши, АР2) — нет кода; ряды 2..7 —
; 20h + номер ('0'..'7', '8','9',':',';',',','=','.','?', '@','A'..'Z','[','\',']','^',' '),
; кроме «,» (было бы '<'), «.» ('>') и пробела ('_'). Портит H.
kbd_code:   cp   8
            jp   c,kc_r0
            cp   16
            jp   c,kc_z
            add  a,20h
            cp   5Fh
            jp   z,kc_sp
            cp   3Ch
            jp   z,kc_x
            cp   3Eh
            ret  nz
kc_x:       sub  10h
            ret
kc_sp:      ld   a,' '
            ret
kc_z:       xor  a
            ret
kc_r0:      push hl
            ld   hl,kbd_row0
            rst  00h
            ld   a,(hl)
            pop  hl
            ret
kbd_row0:   db 9,0,13,0,29,30,28,31

; ---------------------------------------------------------------- экран
; очистить экран ($8000..$DFFF, 3 плоскости) нулями (слот 0 = цвет фона); $E000.. — память программы
scr_clear_all:                          ; (только на старте — скорость не важна)
            ld   hl,8000h
            ld   de,6000h
            jp   memzero
