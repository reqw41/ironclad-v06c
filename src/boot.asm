; ============================================================================
; boot.asm — загрузчик дисковой версии IRONCLAD (build/ironclad.fdd). i8080.
;   сборка: tools/build_fdd.py (sjasmplus --i8080 src/boot.asm -> build/disk/boot.bin)
;
; Как стартует дискета. Штатное ПЗУ Вектора читает с дорожки 0 дескриптор (32 Б: байт 4 = сколько
; КБ грузить, байт 31 = сумма байтов 0..30 с затравкой $66) и кладёт первые КБ дискеты с адреса
; $0080: байт дискеты $80 попадает в $0100. БЛК+СБР — вход в $0100. Мы грузимся одним сектором
; (1 КБ: код $0100..$047F), остальное читаем сами драйвером src/fdd.asm:
;   1. заставка 32 КБ — с дискеты прямо в видеопамять $8000..$FFFF (палитра чёрная, пока идёт
;      чтение), затем её палитра — заставка видна, пока грузится игра;
;   2. игра — образ $0100.. дисковой версии (build/disk/game.rom, сборка -DDISK) — с дискеты в $0100
;      и вход в неё. Игра сама держит заставку ещё SPLASH_FRAMES кадров (src/splash.asm) и стартует.
; Код, который читает игру поверх $0100.., должен жить ниже: вторая копия драйвера (MODULE res,
; собрана под адрес 0) копируется в $0000..$00EF перед чтением игры, стек — $00F0..$00FF.
; Прерывания с этого момента запрещены, поэтому вектор $0038 копии не мешает. Заставку читает
; первая копия драйвера — в теле загрузчика, пока вектор $0038 ведёт в ISR палитры.
;
; С -DPICTEST (build/disk/pictest.fdd — стенд): вместо игры по очереди грузит с дискеты титул,
; победу и поражение в 16 цветах (на время чтения — чёрная палитра, между секторами кадр отдаётся
; прерыванию, как будет в игре) и держит каждую PIC_HOLD кадров.
; ============================================================================
            DEVICE NOSLOT64K
            IFDEF LANG_EN                       ; позиции файлов на дискете (пишет build_fdd.py):
            include "../build/disk_en/layout.inc" ; у английской дискеты игра своей длины
            ELSE
            include "../build/disk/layout.inc"
            ENDIF

RES_TOP     equ 0F0h                    ; резидент $0000..$00EF, под ним стек до $0100
PIC_HOLD    equ 100                     ; PICTEST: кадров на картинку
SPL_HOLD    equ 50                      ; PICTEST: кадров на заставку

            org  100h
boot:       di
            ld   sp,100h
            ld   a,0C3h                 ; RST 7 -> ISR палитры
            ld   (38h),a
            ld   hl,isr
            ld   (39h),hl
            ld   a,88h                  ; ВВ55: A, B, C мл. — выход. Порт B держим выходом: его биты —
            out  (00h),a                ; бордюр и режим 256/512 (на входе они на железе «плавают»)
            ld   a,0FFh
            out  (03h),a                ; скролл на место
            xor  a
            out  (02h),a                ; бордюр — индекс 0, режим 256
            ld   a,36h                  ; ВИ53: три канала — тишина
            out  (08h),a
            ld   a,76h
            out  (08h),a
            ld   a,0B6h
            out  (08h),a
            ei                          ; ISR льёт палитру (пока чёрную) в обратный ход
            halt
            ld   de,FD_SPLASH           ; заставка -> экран
            ld   b,FD_SPLASH_N
            ld   hl,8000h
bt_sld:     call fdd_read               ; стенд засекает кадры от bt_sld до bt_splash
bt_splash:  jp   c,bt_err
            ld   hl,splash_pal
            call set_pal
            ei
            halt                        ; заставка видна
            IFNDEF PICTEST
bt_game:    di                          ; игра читается поверх этого кода — дальше только резидент
            ld   hl,res_img
            ld   de,0
            ld   c,res.res_end-res.res_beg
bt_cp:      ld   a,(hl)
            ld   (de),a
            inc  hl
            inc  de
            dec  c
            jp   nz,bt_cp
            ld   a,(fdd_cur)            ; головка уже стоит — копии не нужен RESTORE
            ld   (res.fdd_cur),a
            jp   res.res_game
            ELSE
            ld   a,SPL_HOLD
            call bt_wait
            ld   a,3
            ld   (pt_cnt),a
            ld   hl,pt_list
pt_next:    ld   e,(hl)                 ; позиция на дискете
            inc  hl
            ld   d,(hl)
            inc  hl
            push hl
            push de
            ld   hl,pal_black           ; на время чтения экран чёрный (как VDP(1) AND 191 у MSX)
            call set_pal
            ei
            halt
            pop  de
            ld   a,1                    ; между секторами — кадр прерыванию, как будет в игре
            ld   (fdd_yld),a
            ld   b,FD_PIC_N
            ld   hl,8000h
pt_load:    call fdd_read               ; стенд засекает кадры от pt_load до pt_loaded
pt_loaded:  jp   c,bt_err
            pop  hl
            ld   e,(hl)                 ; палитра картинки
            inc  hl
            ld   d,(hl)
            inc  hl
            push hl
            ex   de,hl
            call set_pal
            ei
            halt
pt_shown:   ld   a,PIC_HOLD
            call bt_wait
            pop  hl
            ld   a,(pt_cnt)
            dec  a
            ld   (pt_cnt),a
            jp   nz,pt_next
pt_end:     ei
            halt
            jp   pt_end
pt_list:    dw FD_TITLE, pal16_title
            dw FD_VICTORY, pal16_victory
            dw FD_DEFEAT, pal16_defeat
pt_cnt:     db 0
pal_black:  ds 16
bt_wait:    ei
            halt
            dec  a
            jp   nz,bt_wait
            ret
            ENDIF

; ошибка чтения до копирования резидента: весь экран красный (запись палитры без остановки
; попадает во все индексы)
bt_err:     di
            ld   a,07h
be_1:       out  (0Ch),a
            jp   be_1

; палитра 16 байт (HL) -> cur_pal (её льёт ISR в обратный ход кадра)
set_pal:    ld   de,cur_pal
            ld   c,16
sp_1:       ld   a,(hl)
            ld   (de),a
            inc  hl
            inc  de
            dec  c
            jp   nz,sp_1
            ret

; кадровое прерывание: палитра — в начале, пока идёт обратный ход (запись в $0C защёлкивается
; в индекс выводимой точки; в обратный ход это бордюр = индекс из порта $02)
isr:        push af
            push bc
            push hl
            ld   hl,cur_pal+15
            ld   c,15
is_1:       ld   a,c
            out  (02h),a
            ld   a,(hl)
            out  (0Ch),a
            out  (0Ch),a
            out  (0Ch),a
            out  (0Ch),a
            dec  hl
            dec  c
            jp   p,is_1
            xor  a
            out  (02h),a
            pop  hl
            pop  bc
            pop  af
            ei
            ret
cur_pal:    ds 16

            include "../build/data/splash_pal.inc"
            IFDEF PICTEST
            include "../build/disk/pics.inc"
            ENDIF

            include "fdd.asm"           ; драйвер для заставки (и картинок в PICTEST)

; ---------------------------------------------------------------- резидент $0000..$00EF
res_img:
            DISP 0
            MODULE res
res_beg:
; хвост загрузки: игра -> $0100.., вход в неё (прерывания запрещены до самой игры: она ставит
; свой вектор $0038)
res_game:   ld   de,FD_GAME
            ld   b,FD_GAME_N
            ld   hl,100h
            call fdd_read
            jp   nc,100h
; ошибка чтения: весь экран красный (запись палитры без остановки попадает во все индексы)
res_err:    di
            ld   a,07h
re_1:       out  (0Ch),a
            jp   re_1
            include "fdd.asm"
res_end:
            ENDMODULE
            ENT
            ASSERT res.res_end-res.res_beg <= RES_TOP
boot_end:
            ASSERT boot_end <= 480h     ; один сектор: $0100..$047F
            IFDEF PICTEST
            SAVEBIN "build/disk/boot_pictest.bin", 100h, boot_end-100h
            ELSE
            IFDEF LANG_EN
            SAVEBIN "build/disk_en/boot.bin", 100h, boot_end-100h
            ELSE
            SAVEBIN "build/disk/boot.bin", 100h, boot_end-100h
            ENDIF
            ENDIF
            DISPLAY "загрузчик: ", /D, boot_end-100h, " Б (из 896), резидент: ", /D, res.res_end-res.res_beg, " Б (из ", /D, RES_TOP, ")"
