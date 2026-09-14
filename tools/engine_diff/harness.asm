; Стенд сверки: образ движка для 8080-эмулятора.  Массивы — по адресам ниже
; (с зазорами-«канарейками» между ними), код с 0100h, данные с 4000h.
ARR_MG          equ     8000h           ; int16[144]
ARR_PH          equ     8200h           ; int16[12]
ARR_CC          equ     8240h           ; int16[8]
ARR_OS          equ     8260h           ; int16[8]
ARR_SZ          equ     8280h           ; int16[12]
ARR_HK          equ     82C0h           ; int16[8]
ARR_TX          equ     82E0h           ; int16[11]
ARR_TY          equ     8300h           ; int16[11]
ARR_BZ          equ     8400h           ; int16[100]
ARR_PM          equ     8500h           ; int16[100]
ENG_JIFFY       equ     0FC9Eh

                OUTPUT  "engine_test.bin"
                org     0100h
                include "engine.asm"
                OUTEND
                org     4000h
bss_start:
                include "engine_bss.inc"
bss_end:
