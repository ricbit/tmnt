; TMNT attract mode
; by Ricardo Bittencourt 2014
; Last modification: 2014-06-09

; Sequence of animation frames
;  575 -  710 : cloud_fade
;  711 -  791 : cloud_slide
; 1290 - 1300 : disable_screen_title
; 1301 - 1373 : title_bounce
; 1374 - 1401 : title_slide
; 1402 ->     : title_stand

        output  attract.com
            
        org     0100h

; Required memory, in mapper 16kb selectors
selectors       equ     9

; MSX bios
restart         equ     00000h  ; Return to DOS
bdos            equ     00005h  ; BDOS entry point
dosver          equ     0006Fh  ; Get MSX-DOS version number
strout          equ     00009h  ; Print string terminated in $
open            equ     00043h  ; Open a file
read            equ     00048h  ; Read from a file
close           equ     00045h  ; Close a file
romslt          equ     0FFF7h  ; Slot of main rom (byte)
mainrom         equ     0FFF6h  ; Slot of main rom (word)
subrom          equ     0FAF7h  ; Slot of sub rom (word)
msxversion      equ     0002Dh  ; MSX version
rdslt           equ     0000Ch  ; Read a byte from a given slot
callf           equ     0001Ch  ; Call far
chgmod          equ     000D1h  ; Change SCREEN mode
chget           equ     0009Fh  ; Read keyboard
ldirvm          equ     0005Ch  ; Copy RAM to VRAM
setplt          equ     0014Dh  ; Set palette color
wrtvdp          equ     0012Dh  ; Write a VDP register
iniplt          equ     00141h  ; Reset the palette
irq             equ     00038h  ; irq vector
pcm             equ     000A4h  ; turboR PCM port
pmcntl          equ     000A5h  ; turboR PCM config
systml          equ     000E6h  ; turboR system timer
beep            equ     000C0h  ; Play a beep
disscr          equ     00041h  ; Disable screen
enascr          equ     00044h  ; Enable screen
vdpr0           equ     0F3DFh  ; Copy of VDP register 0
vdpr1           equ     0F3E0h  ; Copy of VDP register 1
vdpr9           equ     0FFE8h  ; Copy of VDP register 9
vdpr8           equ     0FFE7h  ; Copy of VDP register 8
vdpr25          equ     0FFFAh  ; Copy of VDP register 25
bigfil          equ     0016Bh  ; Fill vram with a value
chgcpu          equ     00180h  ; Change CPU
hokvld          equ     0FB20h  ; Extended BIOS support
extbio          equ     0FFCAh  ; Extended BIOS entry point
get_p1          equ     00021h  ; Entry point for mapper get_p1
get_p2          equ     00027h  ; Entry point for mapper get_p2
put_p1          equ     0001eh  ; Entry point for mapper put_p1
put_p2          equ     00024h  ; Entry point for mapper put_p2
all_seg         equ     00000h  ; Allocate a mapper segment
temp            equ     04000h  ; Temp buffer for disk loading

; ----------------------------------------------------------------
; Animation constants

theme_start_frame       equ     750
pcm_timer_period        equ     23

; ----------------------------------------------------------------
; Set a VDP register
; Input: A = value
; Destroys: A

        macro   VDPREG reg
        out     (099h), a
        ld      a, 128 + reg
        out     (099h), a
        endm

; ----------------------------------------------------------------
; Set entire palette
; Input: HL = palette
; Destroys: A

        macro   SET_PALETTE
        xor     a
        VDPREG  16
        ld      bc, (16 * 2) * 256 + 09Ah
        otir
        endm

; ----------------------------------------------------------------
; Set VRAM address to write
; Destroys: A

        macro   SET_VRAM_WRITE addr
        ld      a, addr >> 14
        VDPREG  14
        ld      a, addr and 255
        out     (099h), a
        ld      a, ((addr >> 8) and 03Fh) or 64
        out     (099h), a
        endm

; ----------------------------------------------------------------
; Helpers for the states.

; Set display page.

        macro   SET_PAGE page
        ld      a, (page << 5) or 011111b
        VDPREG  2
        endm

; Check if a virq has happened.
        macro   PREAMBLE_VERTICAL
        ex      af, af'
        in      a, (099h)
        and     a
        jp      p, return_irq
        endm

; Check if a hirq has happened.
        macro   PREAMBLE_HORIZONTAL
        ex      af, af'
        in      a, (099h)
        rrca
        jp      nc, return_irq
        endm

; Enable screen
        macro   ENABLE_SCREEN
        ld      a, (vdpr1)
        or      64
        VDPREG  1
        endm

; Disable screen
        macro   DISABLE_SCREEN
        ld      a, (vdpr1)
        and     255 - 64
        VDPREG  1
        endm

; Set the line where the hsplit will happen
        macro   HSPLIT_LINE line
        ld      a, line
        VDPREG  19
        endm

; Select which VDP status will be the default
        macro   VDP_STATUS reg
        ld      a, reg
        VDPREG  15
        endm

; Load the next handle in the irq pointer.
        macro   NEXT_HANDLE handle
        ld      hl, handle
        ld      (irq + 1), hl
        endm
       
; Disable h interrupt.
        macro   DISABLE_HIRQ
        ld      a, (vdpr0)
        and     255 - 16      
        VDPREG  0
        endm

; Enable h interrupt.
        macro   ENABLE_HIRQ
        ld      a, (vdpr0)
        or      16
        VDPREG  0
        endm

; ----------------------------------------------------------------
; Start of main program.

start:
        call    init
start_attract:
        ; Reset the animation.
        ld      de, state_start
        ld      hl, state_backup
        ld      bc, state_end - state_start
        ldir

        ; Install new interrupt handler.
        di
        ld      a, (irq)
        ld      (save_irq), a
        ld      hl, (irq + 1)
        ld      (save_irq + 1), hl

        ld      a, 0C3h
        ld      (irq), a
        ld      de, (current_frame)
        ld      hl, handles
        add     hl, de
        add     hl, de
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        ld      (irq + 1), de
        ei

        ; Init turboR PCM.
        ld      a, 3
        out     (pmcntl), a
        in      a, (systml)

        ; Delay theme music until frame 750.
delay_theme_music:
        ld      hl, theme_start_frame
        ld      de, (current_frame)
        or      a
        sbc     hl, de
        jr      nz, delay_theme_music

        ; Main theme music loop.
        ld      b, 9
        ld      hl, mapper_selectors
        xor     a
        out     (systml), a
change_sample_mapper:
        ; Set mapper page.
        ld      a, (hl)
        call    fast_put_p1
        ld      de, temp

        in      a, (systml)
sample_loop:
        ; Play a sample.
        ld      a, (de)
        out     (pcm), a

        ; Up to 10 outs here
        ;rept 10
        ;out (98h) ,a
        ;endm

sample_wait:
        ; Wait enough to hit 11025Hz.
        in      a, (systml)
        cp      pcm_timer_period
        jr      c, sample_wait
        xor     a
        out     (systml), a

        inc     de
        bit     7, d
        jr      z, sample_loop

        inc     hl
        djnz    change_sample_mapper

        ; Restore system irq.
        call    restore_irq

        ; Enable screen.
        di
        ENABLE_SCREEN
        ei

        ; Wait for a key and exit if not ESC.
        ld      iy, (mainrom)
        ld      ix, chget
        call    callf
        cp      27
        jp      nz, start_attract

        ; Restore palette.
        ld      iy, (subrom)
        ld      ix, iniplt
        call    callf

        ; Restore text mode.
        ld      iy, (subrom)
        ld      ix, chgmod
        xor     a
        call    callf

        ; Restore mapper.
        ld      a, (mapper_selectors)
        call    fast_put_p1
                
        ; Exit to DOS.
        ld      de, str_credits
        jp      abort

; ----------------------------------------------------------------
; Initialization.

init:
        ; Check if DOS2 is present.
        call    check_dos2
        ld      de, str_dos2_not_found
        jp      c, abort

        ; Check if MSX is a turboR.
        call    check_turbor
        ld      de, str_not_turbor
        jp      c, abort

        ; Enable R800 ROM.
        ld      a, 128 + 1
        ld      iy, (mainrom)
        ld      ix, chgcpu
        call    callf

        ; Get mapper support address.
        xor     a
        ld      de, 0402h
        call    extbio
        ; At this point C = number of free mapper pages.
        ld      a, 2
        add     a, c
        cp      selectors
        ld      de, str_not_enough_memory
        jp      c, abort
        ld      (mapper), hl

        ; Put the two default pages into the mapper pool.
        ld      de, get_p1
        add     hl, de
        call    call_hl
        ld      (mapper_selectors), a
        ld      hl, (mapper)
        ld      de, get_p2
        add     hl, de
        call    call_hl
        ld      (mapper_selectors + 1), a

        ; Allocate the remaining mapper selectors.
        ld      de, mapper_selectors + 2
        ld      b, selectors - 2
allocate_memory:
        push    bc
        ld      hl, (mapper)
        ld      bc, all_seg
        add     hl, bc
        xor     a
        ld      b, a
        call    call_hl
        ld      (de), a
        inc     de
        pop     bc
        djnz    allocate_memory

        ; Change to SCREEN 5.
        ld      iy, (subrom)
        ld      ix, chgmod
        ld      a, 5
        call    callf
        ld      a, 1
        ld      (graphics_on), a

        ; Disable screen.
        ld      iy, (mainrom)
        ld      ix, disscr
        call    callf

        ; Clear the vram.
        ld      iy, (mainrom)
        ld      ix, bigfil
        ld      hl, 0
        ld      bc, 0ffffh
        xor     a
        call    callf

        ; Set border to color 0.
        di
        xor     a
        VDPREG  7

        ; Enable 192 lines.
        ld      a, (vdpr9)
        and     127
        VDPREG  9

        ; Enable 16 colors and turn off sprites.
        ld      a, (vdpr8)
        or      32 + 2
        VDPREG  8
        ei

        ; Read opening screen.
        ld      de, opening_filename
        ld      hl, 256 * 192 / 2
        call    load_file

        ; Copy data to vram.
        di
        SET_VRAM_WRITE 08000h
        ei
        ld      hl, temp
        ld      bc, 256 * 192 / 2
        call    blit

        ; Read cloud 2 screen.
        ld      de, cloud_page2_filename
        ld      hl, 256 * 192 / 2
        call    load_file

        ; Copy data to vram.
        di
        SET_VRAM_WRITE 010000h
        ei
        ld      hl, temp
        ld      bc, 256 * 192 / 2
        call    blit

        ; Read cloud 3 screen.
        ld      de, cloud_page3_filename
        ld      hl, 256 * 192 / 2
        call    load_file

        ; Copy data to vram.
        di
        SET_VRAM_WRITE 018000h
        ei
        ld      hl, temp
        ld      bc, 256 * 192 / 2
        call    blit

        ; Copy palette.
        ld      hl, palette
        di
        SET_PALETTE
        ei

        ; Load PCM data.
        call    load_pcm_data

        ; Backup animation state on startup.
        ld      hl, state_start
        ld      de, state_backup
        ld      bc, state_end - state_start
        ldir

        ; Beep.
        ld      iy, (mainrom)
        ld      ix, beep
        call    callf

        ; Wait for a key.
        ld      iy, (mainrom)
        ld      ix, chget
        call    callf

        ret

; ----------------------------------------------------------------
; Load PCM data into mapper.

load_pcm_data:
        ; Open file handle.
        ld      de, title_music_filename
        ld      c, open
        xor     a
        ld      b, a
        call    bdos
        call    check_bdos_error
        ld      a, b
        ld      (file_handle), a

        ld      b, 9
        ld      hl, mapper_selectors
1:
        ; Set mapper page.
        push    bc
        push    hl
        ld      a, (hl)
        ld      hl, (mapper)
        ld      de, put_p1
        add     hl, de
        ld      (fast_put_p1 + 1), hl
        call    call_hl

        ; Read 16kb from disk.
        ld      de, temp
        ld      hl, 04000h
        ld      a, (file_handle)
        ld      b, a
        ld      c, read
        call    bdos
        call    check_bdos_error
        pop     hl
        inc     hl
        pop     bc
        djnz    1b

        ; Close file.
        ld      a, (file_handle)
        ld      b, a
        ld      c, close
        call    bdos
        call    check_bdos_error
        ret

; ----------------------------------------------------------------
; State: title_bounce
; Top of TMNT logo bounces in the screen.
title_bounce:
        PREAMBLE_VERTICAL

        exx
        ; Adjust vertical scroll.
        ld      a, (vertical_scroll)
        ld      hl, title_bounce_data
        ld      e, a
        ld      d, 0
        add     hl, de
        ld      a, (hl)
        VDPREG  23
        ld      a, (vertical_scroll)
        inc     a
        ld      (vertical_scroll), a

        ; Enable two-pages h scroll with no masking.
        ld      a, (vdpr25)
        or      1
        and     255-2
        VDPREG  25

        ; Set h scroll to page 1
        ld      a, 32
        VDPREG  26
        ld      a, 0
        VDPREG  27

        ; If the logo is too low, disable screen
        ld      a, (hl)
        cp      80h
        jr      nc, title_bounce_v_disable

        ; Program hsplit.
        HSPLIT_LINE 46

        ; Enable screen.
        ENABLE_SCREEN

        ; install horizontal split
        VDP_STATUS 1
        NEXT_HANDLE title_bounce_h_disable

        ; enable h interrupt.
        ENABLE_HIRQ

        jp      return_irq_exx

title_bounce_v_disable:
        ; Program hsplit.
        HSPLIT_LINE 10

        ; Disable screen.
        DISABLE_SCREEN

        ; install horizontal split
        VDP_STATUS 1
        NEXT_HANDLE title_bounce_h_enable

        ; enable h interrupt.
        ENABLE_HIRQ

        jp      return_irq_exx

; H handler to disable screen
title_bounce_h_disable:
        PREAMBLE_HORIZONTAL
       
        ; Disable screen
        DISABLE_SCREEN

        ; Install vertical split
        VDP_STATUS 0

        ; Disable h interrupt.
        DISABLE_HIRQ

        jp      frame_end_exx

; H handler to enable screen
title_bounce_h_enable:
        PREAMBLE_HORIZONTAL
        
        ; Enable screen
        ENABLE_SCREEN

        ; Program hsplit.
        HSPLIT_LINE 46

        ; install horizontal split
        exx
        NEXT_HANDLE title_bounce_h_disable
        jp      return_irq_exx

; ----------------------------------------------------------------
; State: title_slide
; Bottom of TMNT logo slides from the right.

title_slide:
        PREAMBLE_VERTICAL
        ENABLE_SCREEN
        HSPLIT_LINE 47
        VDP_STATUS 1
        ENABLE_HIRQ
        ld      a, 32
        VDPREG  26
        xor     a
        VDPREG  27
        exx
        NEXT_HANDLE title_slide_scroll
        jp      return_irq_exx

title_slide_scroll:
        PREAMBLE_HORIZONTAL
        ; Adjust horizontal scroll
        exx
        ld      a, (horizontal_scroll)
        ld      e, a
        ld      d, 0
        ld      hl, title_slide_data
        add     hl, de
        add     hl, de
        ld      a, (hl)
        VDPREG  26
        inc     hl
        ld      a, (hl)
        VDPREG  27
        inc     e
        ld      a, e
        ld      (horizontal_scroll), a
        HSPLIT_LINE 118
        NEXT_HANDLE title_slide_disable
        jp      return_irq_exx

title_slide_disable:
        PREAMBLE_HORIZONTAL
        DISABLE_SCREEN
        ; Reset h scroll
        xor     a
        VDPREG  26
        VDPREG  27
        VDP_STATUS 0
        DISABLE_HIRQ
        jp      frame_end_exx

; ----------------------------------------------------------------
; State: title_stand
; Show the entire logo.

title_stand:
        PREAMBLE_VERTICAL
        ENABLE_SCREEN
        ld      a, 32
        VDPREG  26
        xor     a
        VDPREG  27
        jp      frame_end_exx

; ----------------------------------------------------------------
; State: disable_screen
; Turn off the screen.

disable_screen:
        PREAMBLE_VERTICAL
        DISABLE_SCREEN
        exx
        ld      hl, black_palette
        call    smart_palette
        jp      frame_end

; ----------------------------------------------------------------
; State: cloud_fade
; Fade in the clouds.

cloud_fade:
        PREAMBLE_VERTICAL
        ENABLE_SCREEN
        SET_PAGE 3
        exx
        ld      hl, (palette_fade)
        call    smart_palette
        ld      a, (palette_fade_counter)
        dec     a
        jr      nz, 1f
        ld      hl, (palette_fade)
        ld      de, 16 * 2
        add     hl, de
        ld      (palette_fade), hl
        ld      a, 7
1:
        ld      (palette_fade_counter), a

        ; Enable two-pages h scroll with no masking.
        ld      a, (vdpr25)
        or      1
        and     255-2
        VDPREG  25

        HSPLIT_LINE 27
        VDP_STATUS 1
        ENABLE_HIRQ
        NEXT_HANDLE cloud_fade_first
        jp      return_irq

cloud_fade_first:  
        PREAMBLE_HORIZONTAL
        ld      a, 16
        VDPREG  26
        xor     a
        VDPREG  27
        HSPLIT_LINE 52
        exx
        NEXT_HANDLE cloud_fade_second
        jp      return_irq_exx

cloud_fade_second:  
        PREAMBLE_HORIZONTAL
        ld      a, 32
        VDPREG  26
        xor     a
        VDPREG  27
        VDP_STATUS 0
        DISABLE_HIRQ
        jp      frame_end_exx

; ----------------------------------------------------------------
; State: cloud_slide
; Slide the clouds before v scroll.

cloud_slide:
        PREAMBLE_VERTICAL
        ENABLE_SCREEN
        SET_PAGE 3
        exx
        ld      hl, cloud_palette_final
        call    smart_palette
        jp      frame_end

; ----------------------------------------------------------------
; State: disable_screen_title
; Disable the screen just before the title

disable_screen_title:
        PREAMBLE_VERTICAL
        DISABLE_SCREEN
        SET_PAGE 1
        exx
        ld      hl, palette
        SET_PALETTE
        jp      frame_end

; ----------------------------------------------------------------

; Exit common to all frames
frame_end_exx:
        exx
frame_end:
        ld      de, (current_frame)
        inc     de
        ld      (current_frame), de
        ld      hl, handles
        add     hl, de
        add     hl, de
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        ld      (irq + 1), de
return_irq_exx:
        exx
return_irq:
        ex      af, af'
        ei
        ret

; ----------------------------------------------------------------
; Utils

; Set the palette without stopping the pcm sample.
smart_palette:
        push    hl
        ld      hl, (current_frame)
        ld      de, theme_start_frame
        or      a
        sbc     hl, de
        pop     hl
        jr      nc, 1f
        SET_PALETTE
        ret
1:
        xor     a
        VDPREG  16
        ld      b, 32
smart_palette_next_color:
        ld      a, (hl)
        inc     hl
        out     (09Ah), a
        dec     b
        ret     z
        in      a, (systml)
        cp      pcm_timer_period
        jr      c, smart_palette_next_color

        xor     a
        out     (systml), a

        exx
        inc     de
        bit     7, d
        jr      z, smart_palette_next_sample

        inc     hl
        ld      a, (hl)
        call    fast_put_p1
        ld      de, temp

smart_palette_next_sample:
        ld      a, (de)
        out     (pcm), a
        exx     
        jr      smart_palette_next_color

; Restore the VDP interrupt settings.
restore_irq:
        di

        ; Disable h interrupt.
        DISABLE_HIRQ

        ; Clear H-irq flag
        VDP_STATUS 1
        in      a, (099h)

        ; Clear V-irq flag
        VDP_STATUS 0
        in      a, (099h)

        ; Reload old interrupt handler
        ld      a, (save_irq)
        ld      (irq), a
        ld      hl, (save_irq + 1)
        ld      (irq + 1), hl
        ei
        ret

; Check if DOS2 is present.
; Output: SCF if DOS2 not found.
; Based on http://map.grauw.nl/resources/dos2_functioncalls.php#_dosver
check_dos2:
        ; Check for DOS2
        ld      c, dosver
        call    bdos
        add     a, 255
        ret     c
        ld      a, b
        cp      2
        ret     c
        ; Check for EXTBIO
        ld      a, (hokvld)
        rrca
        ccf
        ret

; Check if turboR is present.
; Output: SCF if turboR not found.
check_turbor:
        ld      a, (romslt)
        ld      hl, msxversion
        call    rdslt
        cp      3
        ret

; Check bdos error and abort if necessary.
; Input: a = error if nz
; Destroy: de
check_bdos_error:
        ld      de, str_read_error
        or      a
        ret     z
        ; fall through

; Print error message, abort and return to dos.
; Input: de = error message terminated in $
abort:
        ; Restore text mode.
        ld      a, (graphics_on)
        or      a
        jr      z, 1f
        push    de
        ld      iy, (subrom)
        ld      ix, chgmod
        xor     a
        call    callf
        pop     de
1:
        ; Print the message.
        ld      c, strout
        call    bdos
        jp      restart

; Copy RAM to VRAM, assumes VRAM address is already set.
; Input: HL = RAM source, BC = size
blit:
        ld      a, (hl)
        out     (098h), a
        inc     hl
        dec     bc
        ld      a, b
        or      c
        jr      nz, blit
        ret

; Load a file.
; Input: DE = filename in asciiz, HL = size
load_file:
        push    hl
        ld      c, open
        xor     a
        ld      b, a
        call    bdos
        call    check_bdos_error

        ld      de, temp        
        pop     hl
        push    bc
        ld      c, read
        call    bdos
        call    check_bdos_error
        pop     bc

        ld      c, close
        call    bdos
        call    check_bdos_error
        ret

; Call HL.
call_hl:
        jp      (hl)

; Fast put page 1.
fast_put_p1:
        jp      0

; ----------------------------------------------------------------
; Variables.

save_irq:               db      0,0,0
file_handle:            db      0
mapper:                 dw      0
graphics_on:            db      0
mapper_selectors:       ds      selectors, 0

; Animation states.
state_start:
vertical_scroll:        db      0
horizontal_scroll:      db      0
palette_fade:           dw      cloud_fade_palette
palette_fade_counter:   db      16
current_frame:          dw      550
state_end:

state_backup:           ds      state_end - state_start, 0

; ----------------------------------------------------------------
; Misc strings.

str_dos2_not_found:     db      "MSX-DOS 2 not found, sorry.$"
str_not_turbor:         db      "This MSX is not a turboR, sorry.$"
str_read_error:         db      "Error reading from disk, sorry.$"
str_not_enough_memory:  db      "Not enough memory, sorry.$"
str_credits:            db      "TMNT Attract Mode 1.0", 13, 10
                        db      "by Ricardo Bittencourt 2014.$"
opening_filename:       dz      "attract.001"
title_music_filename:   dz      "attract.002"
cloud_page2_filename:   dz      "attract.003"
cloud_page3_filename:   dz      "attract.004"

; ----------------------------------------------------------------
; Data

palette:                incbin  "title_bounce_palette.bin"
title_bounce_data:      incbin  "title_bounce_scroll.bin"
title_slide_data:       incbin  "title_slide_scroll.bin"
cloud_fade_palette:     incbin  "cloud_fade_palette.bin"
handles:                include "handles.inc"
black_palette:          ds      16 * 2, 0
cloud_palette_final     equ     cloud_fade_palette + 512

end_of_code:
        assert  end_of_code < 04000h

        end

