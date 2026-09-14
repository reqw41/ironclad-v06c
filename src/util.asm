; ============================================================================
; util.asm — ГСЧ (RND), умножение/деление, числа -> строки (STR$), строки.
; Строки — байты с нулём в конце.
; ============================================================================

; HL += A — add_a_hl, RST 0 (код в векторе $0000, ставит старт)

; HL, DE = длина: обнулить
memzero:    ld   (hl),0
            inc  hl
            dec  de
            ld   a,d
            or   e
            jp   nz,memzero
            ret

; копировать BC байт HL -> DE
memcpy:     ld   a,b
            or   c
            ret  z
            ld   a,(hl)
            ld   (de),a
            inc  hl
            inc  de
            dec  bc
            jp   memcpy

; ---------------------------------------------------------------- страница переменных
; LDV v (rst 08h / db low v): A = (v). STV v (rst 30h / db low v): (v) = A.
; Ещё CPV, INCV, SETV, ZEROV — см. macros.asm.
; v — в странице varpage. Прочие регистры и флаги сохраняются (как у ld a,(v) / ld (v),a).
rst_ldv:    ex   (sp),hl
            ld   a,(hl)
            inc  hl
            ex   (sp),hl
            push hl
            ld   l,a
            ld   h,high varpage
            ld   a,(hl)
            pop  hl
            ret
; CPV v,K (rst 10h / db low v, K)
rst_cpv:    ex   (sp),hl
            ld   a,(hl)
            inc  hl
            push hl
            ld   l,a
            ld   h,high varpage
            ld   a,(hl)
            pop  hl
            cp   (hl)
            inc  hl
            ex   (sp),hl
            ret
; INCV v (rst 18h / db low v): HL = v, inc (hl)
rst_incv:   pop  hl
            push hl
            ld   l,(hl)
            ld   h,high varpage
            inc  (hl)
            ex   (sp),hl
            inc  hl
            ex   (sp),hl
            ret
; SETV v,K (rst 20h / db low v, K)
rst_setv:   ex   (sp),hl
            push de
            ld   e,(hl)
            inc  hl
            ld   a,(hl)
            inc  hl
            ld   d,high varpage
            ld   (de),a
            pop  de
            ex   (sp),hl
            ret
; ZEROV v (rst 28h / db low v) -> STV с A = 0
rst_zerov:  xor  a
rst_stv:    ex   (sp),hl
            push de
            ld   e,(hl)
            inc  hl
            ld   d,high varpage
            ld   (de),a
            pop  de
            ex   (sp),hl
            ret

; ---------------------------------------------------------------- RND
; HL = следующее 16-битное xorshift (7,9,8); rnd_seed не должен быть 0
rnd16:
            ld   hl,(rnd_seed)
            call xs16
            ld   (rnd_seed),hl
            ret
; HL = xorshift16(HL) (7,9,8); портит A, E
xs16:       ld   a,l
            rrca
            and  80h
            ld   e,a                    ; (lo&1)<<7
            ld   a,h
            rra
            ld   a,l
            rra                         ; (hi&1)<<7 | lo>>1
            xor  h
            ld   h,a
            ld   a,e
            xor  l
            ld   l,a                    ; x ^= x<<7
            ld   a,h
            or   a
            rra
            xor  l
            ld   l,a                    ; x ^= x>>9
            xor  h
            ld   h,a                    ; x ^= x<<8
            ret

; INT(RND(1)*N): A = N (1..255) -> A = 0..N-1
rnd_n:
            ld   (rn_n),a
            call rnd16
            push hl
            ld   h,l
            ld   a,(rn_n)
            ld   e,a
            call mul8                   ; L*N
            ld   a,h
            ld   (rn_t),a
            pop  hl
            ld   a,(rn_n)
            ld   e,a
            call mul8                   ; H*N
            ld   a,(rn_t)
            add  a,l
            ld   a,h
            adc  a,0                    ; (HL*N)>>16
            ret

; HL = H * E (без знака)
mul8:
            ld   l,0
            ld   d,0
            ld   b,8
m8_1:       add  hl,hl
            jp   nc,m8_2
            add  hl,de
m8_2:       dec  b
            jp   nz,m8_1
            ret

; HL = HL * DE (16 бит, знак не важен для младших 16)
mul16:
            ld   b,h
            ld   c,l
            ld   hl,0
            ld   a,16
m16_1:      add  hl,hl
            ex   de,hl
            add  hl,hl
            ex   de,hl
            jp   nc,m16_2
            add  hl,bc
m16_2:      dec  a
            jp   nz,m16_1
            ret

; HL = HL / DE, DE = остаток (без знака, DE > 0)
div16:
            ld   b,h
            ld   c,l
            ld   hl,0
            ld   a,16
d16_1:      push af
            ld   a,c                    ; BC <<= 1, бит -> HL
            rla
            ld   c,a
            ld   a,b
            rla
            ld   b,a
            ld   a,l
            rla
            ld   l,a
            ld   a,h
            rla
            ld   h,a
            ld   a,l                    ; HL - DE
            sub  e
            ld   l,a
            ld   a,h
            sbc  a,d
            ld   h,a
            jp   nc,d16_2
            add  hl,de                  ; не влезло — вернуть
            pop  af
            jp   d16_3
d16_2:      inc  c                      ; бит частного
            pop  af
d16_3:      dec  a
            jp   nz,d16_1
            ex   de,hl                  ; DE = остаток
            ld   h,b
            ld   l,c
            ret

; HL = -HL
neg_hl:
            ld   a,l
            cpl
            ld   l,a
            ld   a,h
            cpl
            ld   h,a
            inc  hl
            ret

; сравнение со знаком: HL - DE -> CY = 1, если HL < DE; Z, если равны
cmp_hl_de:
            ld   a,h
            xor  d
            jp   m,chd_s                ; разные знаки
            ld   a,h
            cp   d
            ret  nz
            ld   a,l
            cp   e
            ret
chd_s:      ld   a,h                    ; знаки разные: меньше тот, что отрицателен
            rla                         ; CY = знак HL; HL<0 -> меньше
            ret                         ; Z не бывает (раз знаки разные — не равны), A=?

; ---------------------------------------------------------------- STR$
; HL = число со знаком -> в буфер DE: ' ' или '-', цифры, 0. DE на выходе -> завершающий 0.
str_num:
            ld   a,h
            or   a
            jp   p,sn_pos
            ld   a,'-'
            ld   (de),a
            inc  de
            call neg_hl
            jp   str_digits
sn_pos:     ld   a,' '
            ld   (de),a
            inc  de
; HL >= 0 -> цифры в DE (без знака), 0 в конце
str_digits:
            push de
            ld   de,sd_buf+5
            xor  a
            ld   (de),a
sd_1:       push de
            ld   de,10
            call div16                  ; HL = HL/10, DE = остаток
            ld   a,e
            pop  de
            add  a,'0'
            dec  de
            ld   (de),a
            ld   a,h
            or   l
            jp   nz,sd_1
            ex   de,hl                  ; HL -> цифры
            pop  de
            jp   str_copy

; копировать строку HL -> DE (с нулём); слова словаря (байт >= 80h, TXT) раскрываются.
; HL на выходе -> нуль источника, DE -> нуль приёмника
str_copy:
            ld   a,(hl)
            or   a
            jp   m,sc_w
            ld   (de),a
            ret  z
            inc  hl
            inc  de
            jp   str_copy
sc_w:       push hl
            call dict_word
sc_w1:      ld   a,(hl)
            and  7Fh
            ld   (de),a
            inc  de
            ld   a,(hl)
            inc  hl
            or   a
            jp   p,sc_w1
            pop  hl
            inc  hl
            jp   str_copy

; A = байт-слово (>= 80h) -> HL = первый знак слова в dict (у последнего знака слова бит 7)
dict_word:  ld   hl,dict
            and  7Fh
            ret  z
            push bc
            ld   b,a
dw_1:       ld   a,(hl)
            inc  hl
            or   a
            jp   p,dw_1
            dec  b
            jp   nz,dw_1
            pop  bc
            ret

; DE -> конец строки (на нуль)
str_end:
            ld   a,(de)
            or   a
            ret  z
            inc  de
            jp   str_end

; A = длина строки HL (слова словаря раскрываются); HL на выходе -> нуль
str_len:
            ld   b,0
sl_1:       ld   a,(hl)
            or   a
            jp   m,sl_w
            ld   a,b
            ret  z
            inc  hl
            inc  b
            jp   sl_1
sl_w:       push hl
            call dict_word
sl_w1:      inc  b
            ld   a,(hl)
            inc  hl
            or   a
            jp   p,sl_w1
            pop  hl
            inc  hl
            jp   sl_1

; сравнение строк HL и DE: Z = равны
str_eq:
            ld   a,(de)
            cp   (hl)
            ret  nz
            or   a
            ret  z
            inc  hl
            inc  de
            jp   str_eq
