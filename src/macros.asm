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
