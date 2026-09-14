; ============================================================================
; IRONCLAD — порт с MSX2 на Вектор-06Ц. Точка сборки.
;   tools/sjasmplus --i8080 --sld=build/ironclad.sld --lst=build/ironclad.lst src/main.asm
; Образ .rom грузится с $0100 и стартует с $0100.
; ============================================================================
            DEVICE NOSLOT64K
            include "macros.asm"
            IFDEF NOIMG
            DEFINE NOTITLE
            ENDIF

; Память (8-цветный режим): $0000..$00FF — вектор RST7, маска тайла, переменные библиотеки;
; $0100..$7FFF — код и данные (образ .rom); $8000..$DFFF — экран (3 плоскости);
; $E000..$FFFF — плоскость, которой нет на экране: переменные, массивы, стек.
            IFDEF DISK
; Дисковая версия (-DDISK, tools/build_disk.sh): экран — все 4 плоскости $8000..$FFFF, 16 цветов;
; картинки — с дискеты (disk.asm); BSS и стек — в нижней памяти за образом.
STACK_TOP   equ 8000h
DISK_BSS    equ 5000h               ; BSS с постоянного адреса: там же исполняются оверлеи, их адрес
                                    ; не должен зависеть от длины образа (проходы 1 и 2 build_disk.sh)
            ELSE
STACK_TOP   equ 0                   ; стек растёт вниз от $FFFF
HIBSS       equ 0E000h
            ENDIF
LOWBSS      equ 0060h
            include "lowbss.asm"

            org  100h
start:
            di
            IFNDEF NOSPLASH
            ld   sp,0060h               ; временный стек под $0100: $E000.. — заставка
            call splash_show
            ENDIF
            ld   sp,STACK_TOP
            ; обнулить BSS
            ld   hl,bss_start
            ld   de,bss_end-bss_start
bz_1:       xor  a
            ld   (hl),a
            inc  hl
            dec  de
            ld   a,d
            or   e
            jp   nz,bz_1
            ld   hl,LOWBSS              ; и переменные под $0100
            ld   b,100h-LOWBSS
lz_1:       ld   (hl),0
            inc  hl
            dec  b
            jp   nz,lz_1
            ld   hl,rst0_code           ; RST 0 = add_a_hl прямо в векторе (с nop,nop: слово по $0000 = 0)
            ld   de,0
            ld   bc,rst0_end-rst0_code
            call memcpy
            ld   hl,rst_tab             ; векторы RST 1..6 -> частые подпрограммы
            ld   de,8
rvs_1:       ld   a,(hl)
            or   a
            jp   z,rvs_2
            ld   a,0C3h
            ld   (de),a
            inc  de
            ld   a,(hl)
            ld   (de),a
            inc  hl
            inc  de
            ld   a,(hl)
            ld   (de),a
            inc  hl
            ld   a,e
            add  a,6
            ld   e,a
            jp   rvs_1
rvs_2:       ld   hl,font_zx0            ; шрифт -> BSS
            ld   de,font_data
            call dzx0
            IFDEF LIBTEST
            call tiles_load
            ENDIF
            call vec_init
            ld   a,8
            ld   (gfx_pitch),a
            ld   hl,1
            ld   (rnd_seed),hl
            IFDEF LIBTEST
            jp   libtest
            ELSE
            jp   setup_main
            ENDIF

rst_tab:    dw rst_ldv, rst_cpv, rst_incv, rst_setv, rst_zerov, rst_stv
            db 0
; RST 0: HL += A. Два nop в начале: байты $0000/$0001 = 0 (нулевой указатель на строку = "")
rst0_code:  nop
            nop
            add  a,l
            ld   l,a
            ret  nc
            inc  h
            ret
rst0_end:
add_a_hl    equ 2
            IFNDEF NOSPLASH
            include "splash.asm"
            include "../build/data/splash_pal.inc"
            ENDIF
            include "vec.asm"
            include "gfx.asm"
            include "snd.asm"
            include "zx0.asm"
            include "util.asm"
            IFDEF DISK
            include "disk.asm"
            ENDIF

            IFDEF LIBTEST
            include "libtest.asm"
            ELSE
            include "page.asm"
            include "game.asm"
            include "gdraw.asm"
            include "gai.asm"
            include "gmisc.asm"
            include "gsalvo.asm"
            IFDEF ENGINE_STUB
            include "engine_stub.asm"
            ELSE
            include "engine/engine.asm"
            include "engine_glue.asm"
            ENDIF
            ENDIF

; ---------------------------------------------------------------- данные
            IFDEF DISK
            include "../build/disk/pal16.inc"
            ELSE
            include "../build/data/palettes.inc"
            ENDIF
            include "../build/data/font.inc"
            include "../build/data/dict.inc"
            include "../build/data/tiles.inc"
            IFDEF DISK
tiles_zx0:  incbin "../build/disk/tiles16.zx0"
            ELSE
tiles_zx0:  incbin "../build/data/tiles.zx0"
            ENDIF
font_zx0:   incbin "../build/data/font.zx0"
            IFNDEF NOIMG
            IFNDEF DISK
            IFNDEF NOTITLE
img_title:  incbin "../build/data/title.zx0"
            ENDIF
img_defeat: incbin "../build/data/defeat.zx0"
img_victory: incbin "../build/data/victory.zx0"
            ENDIF
            ENDIF
            IFNDEF LIBTEST
            IFNDEF OVL_PASS1
            IFDEF DISK
ovl_menu_zx0: incbin "../build/disk/ovl_menu.zx0"
ovl_end_zx0: incbin "../build/disk/ovl_end.zx0"
            ELSE
ovl_menu_zx0: incbin "../build/ovl_menu.zx0"   ; оверлеи (последними: адреса выше не зависят от их размеров)
ovl_end_zx0: incbin "../build/ovl_end.zx0"
            ENDIF
            ENDIF
            ENDIF

image_end:
            ASSERT image_end <= 8000h
            ; ---------------------------------------------------------------- BSS (в плоскости $E000)
            IFDEF DISK
            ASSERT image_end <= DISK_BSS
            org  DISK_BSS                       ; с границы страницы — как $E000 у картриджа
            ELSE
            org  HIBSS
            ENDIF
bss_start:
            include "bss.asm"
bss_end:
            IFDEF DISK
            ASSERT bss_end <= STACK_TOP-256     ; 256 Б на стек
            ELSE
            ASSERT bss_end <= 0FF00h            ; 256 Б на стек
            ENDIF
            ASSERT bMI-bKA <= 288               ; render_full сохраняет скаляры в ARR_MG

            IFNDEF LIBTEST
            ; ---------------------------------------------------------------- оверлей меню
            ; SETUP.BAS исполняется из области тайлов (в меню тайлы не рисуются; game_run
            ; распаковывает их заново). build.sh: проход 1 (-DOVL_PASS1) пишет build/ovl_menu.bin,
            ; salvador сжимает его в build/ovl_menu.zx0, проход 2 кладёт сжатое в образ.
            org  OVL_BASE
ovl_menu:
            include "setup.asm"
ovl_menu_end:
            ASSERT ovl_menu_end <= OVL_END
            IFDEF DISK
            SAVEBIN "build/disk/ovl_menu.bin", ovl_menu, ovl_menu_end-ovl_menu
            ELSE
            SAVEBIN "build/ovl_menu.bin", ovl_menu, ovl_menu_end-ovl_menu
            ENDIF
            ; оверлей 2: помощь и конец партии — за оверлеем меню в том же буфере
            org  ovl_menu_end
ovl_end:
            include "ovl_end.asm"
ovl_end_end:
            ASSERT ovl_end_end <= OVL_END
            IFDEF DISK
            SAVEBIN "build/disk/ovl_end.bin", ovl_end, ovl_end_end-ovl_end
            ELSE
            SAVEBIN "build/ovl_end.bin", ovl_end, ovl_end_end-ovl_end
            ENDIF
            ENDIF

            IFDEF DISK
            ; дисковая версия: только образ $0100..image_end (заставку кладёт на экран загрузчик)
            SAVEBIN "build/disk/game.rom", 100h, image_end-100h
            DISPLAY "образ: ", /D, image_end-100h, " Б; BSS: ", /D, bss_end-bss_start, " Б (", /H, bss_start, "..", /H, bss_end, "); стек 256 Б; свободно: ", /D, DISK_BSS-image_end, " + ", /D, STACK_TOP-256-bss_end
            ELSE
            IFNDEF NOSPLASH
            ; образ 64 КБ: код с $0100, нули до $8000, экран заставки $8000..$FFFF
            ; (записывается поверх нулей BSS в памяти ассемблера — в образ BSS не попадает)
            org  8000h
            incbin "../build/data/splash.bin"
            SAVEBIN "build/ironclad.rom", 100h, 0FF00h
            ELSE
            SAVEBIN "build/ironclad.rom", 100h, image_end-100h
            ENDIF
            DISPLAY "образ: ", /D, image_end-100h, " Б (свободно до $8000: ", /D, 8000h-image_end, "); BSS: ", /D, bss_end-bss_start, " Б (свободно в $E000: ", /D, 10000h-bss_end, ")"
            ENDIF
