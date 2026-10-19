; ============================================================================
; vec.asm — железо Вектора-06Ц: порты, ISR, палитра, клавиатура (как INKEY$ MSX),
; счётчик кадров, ожидания. i8080 (собирается sjasmplus --i8080).
; ============================================================================

PPI_CW      equ 00h
PPI_C       equ 01h         ; in: б5 СС (0 = нажата)
PPI_B       equ 02h         ; out: индекс палитры/бордюра (мл. ниббл), б4 = режим 512; in: столбцы клавиатуры
PPI_A       equ 03h         ; out: вертикальный скролл И выбор ряда клавиатуры (активный 0)
PAL_PORT    equ 0Ch
PPI2_CW     equ 04h         ; ВВ55 №2: джойстик «П» (как в ядре MiSTer, Vector-06C.sv joyP)
PPI2_C      equ 05h
PPI2_A      equ 06h         ; in: б0 вправо, б1 влево, б2 вверх, б3 вниз, б6 огонь 1, б7 огонь 2
VI_CTL      equ 08h         ; ВИ53: управляющее слово
VI_CH0      equ 0Bh         ; счётчики 0/1/2 (адреса на Векторе переставлены)
VI_CH1      equ 0Ah
VI_CH2      equ 09h

KEY_REP1    equ 20          ; кадров до первого автоповтора
KEY_REP2    equ 3           ; кадров между повторами
KQ_SIZE     equ 16          ; буфер клавиш (степень двойки)

; ВВ55 (порт 0): обычный режим PPI_OUT — A, B и C младшие выходы: порт B выдаёт индекс
; палитры/бордюра и бит 4 (режим 512 = 0). На входе (PPI_KBD) порт B не выдаёт ничего — на
; железе, MiSTer и в Emu80 индекс читается как FFh (палитра уходит в индекс 15, режим 512,
; бордюр 15); vector06js направление порта не смотрит. Поэтому PPI_KBD — только на опрос
; клавиатуры в начале ISR (кадровый бланк); запись режима обнуляет выходы, после неё порт A
; (скролл) и B (бордюр) ставятся заново.
PPI_OUT     equ 88h         ; A — выход, B — выход, C старшие — вход, C младшие — выход
PPI_KBD     equ 8Ah         ; то же, но B — вход (столбцы клавиатуры)

; ---------------------------------------------------------------- старт железа
; Вызывать под DI. Портит всё.
vec_init:
            ld   a,PPI_OUT
            out  (PPI_CW),a
            ld   a,0FFh
            out  (PPI_A),a              ; скролл в норму
            xor  a
            out  (PPI_C),a
            ld   a,83h                  ; джойстик «П»: оба устройства
            out  (PPI2_CW),a
            ld   a,9Fh
            out  (PPI2_C),a
            in   a,(PPI2_A)             ; покой: всё чтение дальше — относительно него (без
            ld   (joy_idle),a           ; джойстика порт читается FFh, на Турбо+ — тоже константа)
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
            ld   a,PPI_KBD              ; ряды клавиатуры — сразу за палитрой, пока бланк (~450 тактов
            out  (PPI_CW),a             ; порт B на входе; разбор — kbd_isr, уже в режиме PPI_OUT)
            ld   hl,kbd_rows
            ld   a,0FEh                 ; маска ряда 0
isr_kr:     out  (PPI_A),a
            ld   b,a
            in   a,(PPI_B)
            ld   (hl),a
            inc  hl
            ld   a,b
            rlca
            jp   c,isr_kr               ; пока ноль не прошёл все 8 рядов
            call joy_rows               ; джойстик «П» -> те же ряды, как нажатые клавиши
            ld   a,PPI_OUT              ; порт B снова выход (запись режима обнулила выходы)
            out  (PPI_CW),a
            ld   a,0FFh
            out  (PPI_A),a              ; скролл на место (после записи режима, иначе затрётся)
            ld   a,(vec_border)
            out  (PPI_B),a              ; бордюр: индекс 0 (слот фона) или 2*слот белого (экраны итога)
            ld   hl,(frame_cnt)
            inc  hl
            ld   (frame_cnt),hl
            ld   hl,ai_left             ; счёт показа сообщения ИИ: до 0
            dec  (hl)
            jp   p,isr_ai
            inc  (hl)
isr_ai:
            call kbd_isr
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
            IFDEF DISK                  ; 16 цветов: 16 байт как есть
            ld   b,16
ps_1:       ld   a,(hl)
            ld   (de),a
            inc  de
            inc  hl
            dec  b
            jp   nz,ps_1
            ELSE
            ld   b,8
ps_1:       ld   a,(hl)
            ld   (de),a
            inc  de
            ld   (de),a
            inc  de
            inc  hl
            dec  b
            jp   nz,ps_1
            ENDIF
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

; ---------------------------------------------------------------- джойстик «П»
; Джойстик «П» (порт 6) накладывается на прочитанные ряды клавиатуры: стрелки — клавиши
; стрелок (ряд 0), огонь 1 — пробел, огонь 2 — ТАБ (страница). Дальше всё идёт как от
; клавиатуры: автоповтор, буфер, INKEY$. Порт 0Eh (джойстик «С») не читается: на Турбо+
; там мусор. Портит AF, BC, HL.
joy_rows:
            in   a,(PPI2_A)
            ld   hl,joy_idle
            xor  (hl)                   ; 1 = отклонён от покоя
            ld   b,a
            ld   hl,kbd_rows
            ld   a,(hl)
            ld   c,a                    ; ряд 0 (0 = нажата)
            ld   a,b
            and  01h                    ; вправо -> б6 «->»
            jp   z,jr_1
            ld   a,c
            and  0BFh
            ld   c,a
jr_1:       ld   a,b
            and  02h                    ; влево -> б4 «<-»
            jp   z,jr_2
            ld   a,c
            and  0EFh
            ld   c,a
jr_2:       ld   a,b
            and  04h                    ; вверх -> б5
            jp   z,jr_3
            ld   a,c
            and  0DFh
            ld   c,a
jr_3:       ld   a,b
            and  08h                    ; вниз -> б7
            jp   z,jr_4
            ld   a,c
            and  07Fh
            ld   c,a
jr_4:       ld   a,b
            and  80h                    ; огонь 2 -> б0 ТАБ
            jp   z,jr_5
            ld   a,c
            and  0FEh
            ld   c,a
jr_5:       ld   (hl),c
            ld   a,b
            and  40h                    ; огонь 1 -> пробел (ряд 7, б7)
            ret  z
            ld   hl,kbd_rows+7
            ld   a,(hl)
            and  7Fh
            ld   (hl),a
            ret

; ---------------------------------------------------------------- клавиатура
; Опрос в ISR: первая нажатая клавиша с кодом -> буфер; удержание -> автоповтор
; (как буфер клавиатуры MSX, из которого читает INKEY$).
; Ряды прочитаны в ISR в kbd_rows (порт B — вход только на это время).
kbd_isr:
            ld   hl,0                   ; H = найденный код, L = номер клавиши = ряд*8 + бит
            ld   bc,kbd_rows
ki_row:
            ld   a,(bc)
            cpl                         ; 1 = нажата
            ld   e,8
ki_bit:
            rra
            jp   nc,ki_nb
            ld   d,a
            ld   a,h
            or   a
            jp   nz,ki_nb0              ; уже нашли более раннюю
            ld   a,l
            call kbd_code               ; (HL, BC, DE не трогает)
            ld   h,a
ki_nb0:     ld   a,d
ki_nb:      inc  l
            dec  e
            jp   nz,ki_bit
            inc  bc
            ld   a,l
            cp   64
            jp   c,ki_row               ; все 8 рядов
            ; H = код (0 — ничего). СС + '/' = '?', без СС тоже '?' (клавиша «/ ?»)
            ld   c,h
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
            call ai_wait                ; сообщение ИИ провисело свои 60 кадров
gk_1:       call inkey
            ret  nz
            ei
            halt
            jp   gk_1

; A = номер клавиши (ряд 0..7 * 8 + бит 0..7) -> A = код (MSX: 28 ->, 29 <-, 30 вверх, 31 вниз).
; Прочие регистры сохраняет.
; Ряд 0: ТАБ ПС ВК ЗБ <- ^ -> v (таблица); ряд 1 (F-клавиши, АР2) — нет кода; ряды 2..7 —
; 20h + номер ('0'..'7', '8','9',':',';',',','=','.','?', '@','A'..'Z','[','\',']','^',' '),
; кроме «,» (было бы '<'), «.» ('>') и пробела ('_').
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
            ld   de,NPL*2000h           ; (дисковая версия: все 4 плоскости)
            jp   memzero
