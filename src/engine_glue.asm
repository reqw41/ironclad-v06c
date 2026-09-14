; ============================================================================
; engine_glue.asm — имена, под которыми игра зовёт движок (бывшие POKE/PEEK MSX)
; ============================================================================
ENG_KL      equ vKL         ; &HCFAB: добивание
ENG_RK      equ vRK         ; &HCFFA: «флот у края»
ENG_RD      equ vRD         ; &HCF98
ENG_NF      equ vNF         ; &HCF99
ENG_RIM     equ vRIM        ; &HCF9A
ENG_JIFFY   equ frame_cnt   ; JIFFY &HFC9E: семя rnd16 движка
