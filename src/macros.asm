; ============================================================================
; macros.asm — компактный доступ к байтам страницы переменных (varpage, см. game_bss.asm):
; 2 байта вместо 3. Регистры, кроме A (у LDV), и флаги не меняются.
; ============================================================================
            MACRO LDV adr
            rst  08h
            db   low (adr)
            ASSERT high (adr) == high varpage
            ENDM
            MACRO STV adr
            rst  30h
            db   low (adr)
            ASSERT high (adr) == high varpage
            ENDM
; CPV v,K: A = (v), флаги — от cp K (= LDV v / cp K)
            MACRO CPV adr,k
            rst  10h
            db   low (adr), k
            ASSERT high (adr) == high varpage
            ENDM
; INCV v: HL = v, inc (hl) (= ld hl,v / inc (hl)); A не меняется
            MACRO INCV adr
            rst  18h
            db   low (adr)
            ASSERT high (adr) == high varpage
            ENDM
; SETV v,K: (v) = A = K, флаги не меняются (= ld a,K / STV v)
            MACRO SETV adr,k
            rst  20h
            db   low (adr), k
            ASSERT high (adr) == high varpage
            ENDM
; ZEROV v: (v) = A = 0, флаги как у xor a (= xor a / STV v)
            MACRO ZEROV adr
            rst  28h
            db   low (adr)
            ASSERT high (adr) == high varpage
            ENDM
