; ============================================================================
; fdd.asm — чтение дискеты Вектора-06Ц (контроллер КР1818ВГ93 = WD1793). i8080.
;
; Геометрия: 80 дорожек x 2 стороны x 5 секторов по 1024 Б = 800 КБ. Позиция задаётся парой
; D = дорожка (0..79), E = номер сектора В ДОРОЖКЕ 0..9: 0..4 — сторона 0, секторы 1..5;
; 5..9 — сторона 1, секторы 1..5. В образе .fdd это смещение (D*10 + E)*1024: номера идут
; подряд, следующий за 9 — сектор 0 следующей дорожки. Файловой системы нет: позиции файлов
; прошивает в код tools/build_fdd.py (build/disk/layout.inc).
;
; Порты ВГ93 у Вектора инвертированы: $1B команда/статус, $1A дорожка, $19 сектор, $18 данные,
; $1C управление (бит 0 — дисковод, 0 = A; бит 2: 1 = сторона 0, 0 = сторона 1).
;
; Ловушки (из порта Ianna, tools/build_fdd.py и src/vec/vec_fdd.asm там):
;  * сектор читается по ЯВНОМУ счётчику 1024 байт: цикл «по флагам DRQ» при неснятом DRQ
;    крутится, пока адрес не переполнится, и затирает всю память;
;  * наличие дисковода — только бит 7 статуса (NOT READY): эхо регистра сектора отвечает и
;    без дискеты;
;  * прерывание Вектора не защёлкивается: под DI (весь сектор, ~33 мс на железе) кадр теряется.
;    Поэтому при fdd_yld <> 0 между секторами отдаём кадр прерыванию (ei / halt) — иначе
;    музыка ISR зависает на ноте. На время приёма байтов прерывания запрещены обязательно:
;    байт стоит в регистре данных 32 мкс (~96 тактов), ISR его потеряет (LOST DATA).
;
; Внешнее: fdd_read, fdd_yld (байт: 0 — читать подряд, иначе отдавать кадр между секторами),
; fdd_cur (дорожка под головкой, 0FFh — неизвестна: первый поиск начнётся с RESTORE).
; ============================================================================

FDC_CMD     equ 1Bh
FDC_TRK     equ 1Ah
FDC_SEC     equ 19h
FDC_DAT     equ 18h
FDC_CTL     equ 1Ch
FDC_S0      equ 34h                     ; дисковод A, сторона 0 (как у ПЗУ и в Ianna); сторона 1 = 30h
FDD_TRIES   equ 4                       ; попыток на сектор

; ---------------------------------------------------------------- чтение
; D = дорожка, E = сектор в дорожке (0..9), B = число секторов (1..255), HL = приёмник.
; Выход: NC — всё прочитано, HL за последним байтом, D/E — позиция следующего сектора;
;        CY — ошибка (нет дискеты или сектор не читается FDD_TRIES раз), A = статус ВГ93.
; Прерывания на выходе ЗАПРЕЩЕНЫ (вызывающий сам решает, когда EI). Портит всё.
fdd_read:
            di
fr_sec:     push bc
            ld   c,FDD_TRIES
fr_try:     push hl
            call fdd_sector
            jp   nc,fr_ok
            pop  hl                     ; повтор в тот же приёмник
            dec  c
            jp   nz,fr_try
            pop  bc
            scf
            ret
fr_ok:      pop  bc                     ; (сохранённый HL больше не нужен)
            pop  bc
            inc  e                      ; следующий сектор: 9 -> сектор 0 следующей дорожки
            ld   a,e
            cp   10
            jp   c,fr_nx
            ld   e,0
            inc  d
fr_nx:      dec  b
            jp   nz,fr_more
            or   a                      ; NC: всё прочитано (CY мог остаться от cp 10)
            ret
fr_more:    ld   a,(fdd_yld)
            or   a
            jp   z,fr_sec
            ei                          ; кадр — прерыванию (музыка, клавиатура, палитра)
            halt
            di
            jp   fr_sec

; один сектор: D, E, HL. NC — принят, HL += 1024; CY — ошибка, A = статус. BC, DE сохраняет.
fdd_sector:
            push bc
            ld   a,FDC_S0               ; выбрать дисковод; бит 7 статуса — NOT READY
            out  (FDC_CTL),a
            in   a,(FDC_CMD)
            rlca
            jp   c,fs_fail
            ld   a,(fdd_cur)
            cp   d
            call nz,fdd_seek
            jp   c,fs_fail
            ld   a,e                    ; сторона и номер сектора
            ld   b,FDC_S0
            cp   5
            jp   c,fs_s0
            sub  5
            ld   b,FDC_S0 xor 4
fs_s0:      inc  a
            out  (FDC_SEC),a
            ld   a,b
            out  (FDC_CTL),a
            ld   a,80h                  ; READ SECTOR (одиночный, без проверки стороны)
            out  (FDC_CMD),a
            ld   b,0                    ; дождаться BUSY (не больше 256 опросов ~ 4 мс)
fs_bw:      in   a,(FDC_CMD)
            rrca
            jp   c,fs_go
            dec  b
            jp   nz,fs_bw
            jp   fs_fail
fs_go:      ld   bc,4                   ; B = 0 (256 байт), C = 4: ровно 1024 байта
fs_rd:      in   a,(FDC_CMD)            ; 80 тактов на байт, пока DRQ есть сразу
            rrca                        ; бит 0 BUSY
            rrca                        ; бит 1 DRQ -> CY
            jp   nc,fs_nd
            in   a,(FDC_DAT)
            ld   (hl),a
            inc  hl
            dec  b
            jp   nz,fs_rd
            dec  c
            jp   nz,fs_rd
fs_end:     in   a,(FDC_CMD)            ; 1024 байта приняты — дождаться конца команды
            rrca
            jp   c,fs_end
            in   a,(FDC_CMD)
            and  9Ch                    ; NOT READY, сектор не найден, CRC, потеря данных
            pop  bc
            ret  z                      ; NC
            scf
            ret
fs_nd:      and  40h                    ; DRQ нет: BUSY (бит 0 — теперь бит 6) ещё стоит?
            jp   nz,fs_rd
fs_fail:    in   a,(FDC_CMD)            ; команда кончилась раньше 1024 байт / не пошла
            pop  bc
            scf
            ret

; головку на дорожку D. CY — тайм-аут. A портит.
fdd_seek:
            ld   a,(fdd_cur)
            inc  a
            jp   nz,fk_1
            out  (FDC_CMD),a            ; A = 0: RESTORE — позиция неизвестна
            call fdd_wait
            ret  c
fk_1:       ld   a,d
            out  (FDC_DAT),a
            ld   a,18h                  ; SEEK: головку прижать, без проверки, шаг 6 мс
            out  (FDC_CMD),a
            call fdd_wait
            ret  c
            ld   a,d
            ld   (fdd_cur),a
            ret

; ждать конца команды ВГ93 (тип I): CY — тайм-аут ~1.3 с. A портит.
fdd_wait:
            push bc
            ld   bc,0
            ex   (sp),hl                ; ~16 мкс: статус ВГ93 верен не сразу после команды
            ex   (sp),hl
fw_1:       in   a,(FDC_CMD)
            rrca
            jp   nc,fw_2
            dec  bc
            ld   a,b
            or   c
            jp   nz,fw_1
            scf
fw_2:       pop  bc
            ret

fdd_cur:    db 0FFh
fdd_yld:    db 0
