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

; ---------------------------------------------------------------- тексты
; Язык выбирается при сборке: без флага — русский, -DLANG_EN — английский (tools/build_all.sh).
; Каждая переводимая строка стоит в исходнике парой: TXT "РУССКАЯ","English" — в образ идёт
; строка языка сборки. TXN "..." — строка без букв (цифры, знаки), одна на оба языка.
; Числа и клавиши, зависящие от языка, — в src/lang.asm (LNG), шрифт и словарь — по языку сборки
; (tools/mkdata.py: build/data/ — русские, build/data/en/ — английские).
; Кодировка U(): русская сборка — внутренняя кодировка шрифта (таблица ENC из dict.lua): 20h..40h
; как ASCII, А = 41h ... Я = 5Eh, Й = 5Fh (Ё = Е), латиница — ошибка сборки; английская — ASCII
; 20h..7Fh (строчные — через lc_map шрифта), кириллица — ошибка сборки.
; TXT — строка, сжатая словарём (build/data[/en]/dict.lua, строит tools/mkdata.py): байт >= 80h —
; слово словаря (dict в dict.inc), 0 — конец. Разбор — оптимальный (ДП).
; ABR "РУС","ENG" — сокращение имени корабля для cat3: 3 байта без словаря (короче — добито нулями).
            LUA PASS1
            LANG_EN = sj.get_define("LANG_EN") ~= nil
            if LANG_EN then dofile("build/data/en/dict.lua") else dofile("build/data/dict.lua") end
            function U(s)
              s = s:match('^"(.*)"$') or s
              local o = {}
              for _, c in utf8.codes(s) do
                local b
                if LANG_EN then
                  if c >= 32 and c < 128 then b = c end
                else
                  b = ENC[c]
                  if not b and c >= 32 and c <= 64 then b = c end
                end
                if not b then error("знак вне шрифта: " .. utf8.char(c) .. " в строке " .. s) end
                o[#o + 1] = string.char(b)
              end
              return table.concat(o)
            end
            function A(s)
              s = U(s)
              assert(#s <= 3, "ABR длиннее 3 знаков: " .. s)
              for i = 1, 3 do _pc("db " .. (s:byte(i) or 0)) end
            end
            function T(s)
              s = U(s)
              local n = #s
              local bc, bw, ch = {}, {}, {}
              bc[n + 1], bw[n + 1] = 0, 0
              for i = n, 1, -1 do
                local c, w, k0 = bc[i + 1] + 1, bw[i + 1], nil
                for k, wd in ipairs(DICT) do
                  local l = #wd
                  if s:sub(i, i + l - 1) == wd then
                    local c2, w2 = bc[i + l] + 1, bw[i + l] + 1
                    if c2 < c or (c2 == c and w2 < w) then c, w, k0 = c2, w2, k end
                  end
                end
                bc[i], bw[i], ch[i] = c, w, k0
              end
              local i = 1
              while i <= n do
                if ch[i] then _pc("db " .. (127 + ch[i])); i = i + #DICT[ch[i]]
                else _pc("db " .. s:byte(i)); i = i + 1 end
              end
              _pc("db 0")
            end
            -- строка языка сборки из пары
            function P(ru, en) if LANG_EN then return en else return ru end end
            ENDLUA
            MACRO TXT ru, en
            DEFINE+ _TXTA ru
            DEFINE+ _TXTB en
            LUA ALLPASS
            T(P(sj.get_define("_TXTA"), sj.get_define("_TXTB")))
            ENDLUA
            ENDM
            MACRO TXN str
            DEFINE+ _TXTA str
            LUA ALLPASS
            T(sj.get_define("_TXTA"))
            ENDLUA
            ENDM
            MACRO ABR ru, en
            DEFINE+ _TXTA ru
            DEFINE+ _TXTB en
            LUA ALLPASS
            A(P(sj.get_define("_TXTA"), sj.get_define("_TXTB")))
            ENDLUA
            ENDM
; LNG имя, русское, английское — константа языка сборки (для src/lang.asm)
            MACRO LNG name, ru, en
            IFDEF LANG_EN
name        equ en
            ELSE
name        equ ru
            ENDIF
            ENDM
