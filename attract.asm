; TMNT attract mode
; by Ricardo Bittencourt 2014

; Keep in mind: 18 frames to copy 192 lines to vram.

        output  attract.com
            
        org     0100h
        jp      start_main

; Required memory, in mapper 16kb selectors
selectors       equ     13

; ----------------------------------------------------------------
; Animation states.

state_start:
current_frame:          dw      520
vertical_scroll:        db      0
horizontal_scroll:      db      0
palette_fade:           dw      cloud_fade_palette
palette_fade_counter:   db      16
cloud1_scroll:          db      158
cloud2_scroll:          db      146
cloud_tick:             db      1
city_split_line:        db      189 + 10
city_scroll:            dw      city_scroll_down5
top_building_current:   dw      top_building_dyn_attr
is_playing:             db      0
pcm_mapper_page:        dw      mapper_selectors
state_end:
state_backup:           ds      state_end - state_start, 0

; ----------------------------------------------------------------
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
vdp_vscroll     equ     00017h  ; VDP register for vertical scroll
vdp_hscroll_h   equ     0001Ah  ; VDP register for horizontal scroll, high
vdp_hscroll_l   equ     0001Bh  ; VDP register for horizontal scroll, low
vdp_sprite_patt equ     00006h  ; VDP register for sprite pattern base addr
vdp_hsplit_line equ     00013h  ; VDP register for horizontal split line
vdp_timp        equ     00008h  ; VDP logic operator TIMP
vdp_set_page    equ     00002h  ; VDP register for set page
vdp_hmmm_size   equ     00010h  ; Number of bytes required to perform a HMMM

; ----------------------------------------------------------------
; VRAM layout

; VRAM Layout during cloud states:
; 00000-07FFF city2 pixels
; 08000-0D9FF city1 pixels
; 0DA00-0FBFF city1 parallax scroll, frames 1-4
; 10000-1017F top building patterns
; 10700-114FF cloud2 pixels
; 11900-1287F must be all zeros, don't use
; 12880-128FF city line mask
; 13000-1321F moon attributes
; 13800-16AFF moon patterns
; 17000-1727F top building attributes
; 18000-1A87F cloud3 pixels
; 1CA00-1DEFF city1 parallax scroll, frame 5

cloud2_addr             equ     10000h
cloud3_addr             equ     18000h
city1_addr              equ     08000h
city2_addr              equ     00000h
moon_pattern_addr       equ     13800h
moon_attr_addr          equ     13200h
top_building_attr_addr  equ     17200h
top_building_patt_addr  equ     10000h
city_line_mask_addr     equ     12880h
title_addr              equ     08000h

; ----------------------------------------------------------------
; Animation constants

theme_start_frame               equ     750
pcm_timer_period                equ     23
moon_pattern_base_hscroll       equ     108
down4_sprite_start_frame        equ     822
cloud_scroll_start_frame        equ     794
expand_city_line_frame          equ     814
copy_city_line_frame            equ     819

; ----------------------------------------------------------------
; Helpers for the states.

; Set a VDP register
        macro   VDPREG reg
        out     (099h), a
        ld      a, 128 + reg
        out     (099h), a
        endm

; Set entire palette
        macro   SET_PALETTE
        xor     a
        VDPREG  16
        ld      bc, (16 * 2) * 256 + 09Ah
        otir
        endm

; Set VRAM address to write
        macro   SET_VRAM_WRITE addr
        ld      a, addr >> 14
        VDPREG  14
        ld      a, addr and 255
        out     (099h), a
        ld      a, ((addr >> 8) and 03Fh) or 64
        out     (099h), a
        endm

; Set display page.
        macro   SET_PAGE page
        ld      a, (page << 5) or 011111b
        VDPREG  vdp_set_page
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
        ld      (vdpr1), a
        VDPREG  1
        endm

; Disable screen
        macro   DISABLE_SCREEN
        ld      a, (vdpr1)
        and     255 - 64
        ld      (vdpr1), a
        VDPREG  1
        endm

; Set the line where the hsplit will happen
        macro   HSPLIT_LINE line
        ld      a, line
        VDPREG  vdp_hsplit_line
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
        ld      (vdpr0), a
        VDPREG  0
        endm

; Enable h interrupt.
        macro   ENABLE_HIRQ
        ld      a, (vdpr0)
        or      16
        ld      (vdpr0), a
        VDPREG  0
        endm

; Turn on sprites.
        macro   SPRITES_ON
        ld      a, (vdpr8)
        and     255 - 2
        ld      (vdpr8), a
        VDPREG  8
        endm

; Turn off sprites.
        macro   SPRITES_OFF
        ld      a, (vdpr8)
        or      2
        ld      (vdpr8), a
        VDPREG  8
        endm

; Set sprite size to 16x16.
        macro   SPRITES_16x16
        ld      a, (vdpr1)
        or      2
        ld      (vdpr1), a
        VDPREG  1
        endm

; Enable two-pages h scroll with no masking.
        macro   WIDE_SCROLL
        ld      a, (vdpr25)
        or      1
        and     255 - 2
        ld      (vdpr25), a
        VDPREG  25
        endm

; Set sprite attribute table.
        macro   SPRITE_ATTR addr
        assert  (addr and ((1 << 10) - 1)) == (1 << 9)
        ld      a, (((addr >> 10) and 1Fh) << 3) or 7
        VDPREG  5
        ld      a, addr >> 15
        VDPREG  11
        endm

; Set sprite pattern table.
        macro   SPRITE_PATTERN addr
        assert  (addr and ((1 << 11) - 1)) == 0
        ld      a, addr >> 11
        VDPREG vdp_sprite_patt
        endm
        
; Set a VDP register to auto-increment.
        macro   VDP_AUTOINC reg
        ld      a, reg
        VDPREG 17
        endm

; Set the value of the h scroll.
        macro   SET_HSCROLL value
        ld      a, (value + 7) / 8
        VDPREG vdp_hscroll_h
        ld      a, ((value + 7) and 01F8h) - value
        VDPREG vdp_hscroll_l
        endm

; Set the value of the h scroll using indirect register access.
        macro   FAST_SET_HSCROLL value
        ld      a, (value + 7) / 8
        out     (09Bh), a
        ld      a, ((value + 7) and 01F8h) - value
        out     (09Bh), a
        endm

; VDP Command HMMV: fill rectangle with a color.
        macro   VDP_HMMV dx, dy, nx, ny, color
        db      36
        db      dx and 255
        db      dx >> 8
        db      dy and 255
        db      dy >> 8
        db      nx and 255
        db      nx >> 8
        db      ny and 255
        db      ny >> 8
        db      color
        db      0
        db      0C0h
        endm

; VDP Command YMMM: copy rectangle VRAM->VRAM on the Y direction.
        macro   VDP_YMMM sy, dx, dy, ny
        db      34
        db      sy and 255
        db      sy >> 8
        db      dx and 255
        db      dx >> 8
        db      dy and 255
        db      dy >> 8
        db      0
        db      0
        db      ny and 255
        db      ny >> 8
        db      0
        db      0
        db      0E0h
        endm

; VDP Command LMMM: copy rectangle VRAM->VRAM using logic operators.
        macro   VDP_LMMM sx, sy, dx, dy, nx, ny, op
        db      32
        db      sx and 255
        db      sx >> 8
        db      sy and 255
        db      sy >> 8
        db      dx and 255
        db      dx >> 8
        db      dy and 255
        db      dy >> 8
        db      nx and 255
        db      nx >> 8
        db      ny and 255
        db      ny >> 8
        db      0
        db      0
        db      090h + op
        endm

; VDP Command HMMM: copy rectangle VRAM->VRAM using bytes.
        macro   VDP_HMMM sx, sy, dx, dy, nx, ny
        db      32
        db      sx and 255
        db      sx >> 8
        db      sy and 255
        db      sy >> 8
        db      dx and 255
        db      dx >> 8
        db      dy and 255
        db      dy >> 8
        db      nx and 255
        db      nx >> 8
        db      ny and 255
        db      ny >> 8
        db      0
        db      0
        db      0D0h
        endm

; ----------------------------------------------------------------
; Start of main program.

start_main:
        call    global_init
start_attract:
        call    local_init

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

        ; Install foreground thread.
        ld      hl, foreground_next
        ld      (foreground + 1), hl

        ; Init turboR PCM.
        ld      a, 3
        out     (pmcntl), a
        in      a, (systml)

        ; Delay theme music until the correct frame.
delay_theme_music:
        ld      hl, theme_start_frame
        ld      de, (current_frame)
        or      a
        sbc     hl, de
        jr      nz, delay_theme_music

        ; Main theme music loop.
        xor     a
        out     (systml), a
        ld      a, 1
        ld      (is_playing), a
        ld      de, 04000h
change_sample_mapper:
        ; Set mapper page.
        push    hl
        ld      hl, (pcm_mapper_page)
        ld      a, (hl)
        inc     hl
        ld      (pcm_mapper_page), hl
        call    fast_put_p1
        pop     hl

        in      a, (systml)
sample_loop:
        ; Play a sample.
        ld      a, (de)
        out     (pcm), a

foreground:
        jp      foreground_next
foreground_next:
        ; Avoid jitter by stopping foreground thread 
        ; a few ticks before the limit.
        in      a, (systml)
        cp      pcm_timer_period - 4
        jr      c, foreground
        ; Wait enough to hit 11025Hz.
1:
        in      a, (systml)
        cp      pcm_timer_period
        jr      c, 1b
        ld      iyl, a
        xor     a
        out     (systml), a
        ; Increment the pcm counter.
        ld      iyh, high advance_pcm
        ld      a, (iy)
        add     a, e
        ld      e, a
        ld      a, 0
        adc     a, d
        ld      d, a

        ; Check the pcm for mapper page change.
        bit     7, d
        jr      z, sample_loop
        set     6, d
        res     7, d
        jr      change_sample_mapper

finish_animation:
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

        ; Restore environment.
        call    restore_environment
                
        ; Exit to DOS.
        ld      de, str_credits
        jp      abort

; ----------------------------------------------------------------
; Initialization.

global_init:
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
        ld      de, put_p1
        add     hl, de
        ld      (fast_put_p1 + 1), hl
        ld      hl, (mapper)
        ld      de, put_p2
        add     hl, de
        ld      (fast_put_p2 + 1), hl

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

        ; Load mapper data.
        call    load_mapper_data

        ; Beep.
        ld      iy, (mainrom)
        ld      ix, beep
        call    callf

        ; Wait for a key.
        ld      iy, (mainrom)
        ld      ix, chget
        call    callf

        ; Change to SCREEN 5.
        ld      iy, (subrom)
        ld      ix, chgmod
        ld      a, 5
        call    callf

        ; Backup animation state on startup.
        ld      hl, state_start
        ld      de, state_backup
        ld      bc, state_end - state_start
        ldir

        ret

; ----------------------------------------------------------------
; Initialization to be performed every time.

local_init:
        ; Disable screen.
        ld      iy, (mainrom)
        ld      ix, disscr
        call    callf

        ; Clear the vram.
        di
        ld      hl, cmd_erase_all_vram
        call    vdp_command
        ei

        ; Set border to color 0.
        di
        xor     a
        VDPREG  7

        ; Enable 192 lines.
        ld      a, (vdpr9)
        and     127
        ld      (vdpr9), a
        VDPREG  9

        ; Enable 16 colors and turn off sprites.
        ld      a, (vdpr8)
        or      32 + 2
        ld      (vdpr8), a
        VDPREG  8
        ei

        ; Copy cloud2 to vram.
        ld      a, (mapper_selectors + 9)
        call    fast_put_p2
        di
        SET_VRAM_WRITE cloud2_addr
        ei
        ld      hl, cloud_page2
        call    zblit

        ; Copy cloud3 to vram.
        di
        SET_VRAM_WRITE cloud3_addr
        ei
        ld      hl, cloud_page3
        call    zblit

        ; Copy moon sprite patterns to vram.
        ld      a, (mapper_selectors + 10)
        call    fast_put_p2
        di
        SET_VRAM_WRITE moon_pattern_addr
        ei
        ld      hl, moon_pattern
        call    zblit

        ; Copy moon sprite attributes to vram.
        di
        SET_VRAM_WRITE (moon_attr_addr - 512)
        ei
        ld      hl, moon_attr
        call    zblit

        ; Copy city1 to vram.
        di
        SET_VRAM_WRITE city1_addr
        ei
        ld      hl, city_page1
        call    zblit

        ; Copy city2 to vram.
        di
        SET_VRAM_WRITE city2_addr
        ei
        ld      a, (mapper_selectors + 11)
        call    fast_put_p2
        ld      hl, city2a
        call    zblit
        ld      a, (mapper_selectors + 12)
        call    fast_put_p2
        ld      hl, city2b
        call    zblit

        ; Copy initial frames of city scrolling.
        di
        ld      b, 12
        ld      hl, cmd_copy_city_back
1:
        push    bc
        call    vdp_command
        pop     bc
        djnz    1b
        ei

        ; Copy top building sprite patterns to vram.
        di
        ld      a, (mapper_selectors + 11)
        call    fast_put_p2
        SET_VRAM_WRITE top_building_patt_addr
        ei
        ld      hl, top_building_pattern
        call    zblit

        ; Copy top building sprite attributes to vram.
        di
        SET_VRAM_WRITE (top_building_attr_addr - 512)
        ei
        ld      hl, top_building_attr
        call    zblit

        ; Copy city line mask to vram.
        di
        SET_VRAM_WRITE city_line_mask_addr
        ei
        ld      hl, city_line_mask
        call    zblit

        ; Reset the animation.
        ld      de, state_start
        ld      hl, state_backup
        ld      bc, state_end - state_start
        ldir

        ret

; ----------------------------------------------------------------
; Load mapper data.

load_mapper_data:
        ; Print "loading" message.
        ld      de, str_loading
        ld      c, strout
        call    bdos

        ; Open file handle.
        ld      de, mapper_data_filename
        ld      c, open
        xor     a
        ld      b, a
        call    bdos
        call    check_bdos_error
        ld      a, b
        ld      (file_handle), a

        ld      b, selectors
        ld      hl, mapper_selectors
load_mapper_data_block:
        ; Set mapper page.
        push    bc
        push    hl
        ld      a, (hl)
        call    fast_put_p1

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

        ; Print a dot and loop
        push    bc
        push    hl
        ld      de, str_dot
        ld      c, strout
        call    bdos
        pop     hl
        pop     bc
        djnz    load_mapper_data_block        

        ; Close file.
        ld      a, (file_handle)
        ld      b, a
        ld      c, close
        call    bdos
        call    check_bdos_error

        ld      de, str_press_any_key
        ld      c, strout
        call    bdos
        ret

; ----------------------------------------------------------------
; State: end_animation
; Finish the animation.

end_animation:
        PREAMBLE_VERTICAL
        exx
        ld      hl, finish_animation
        ld      (foreground + 1), hl
        jp      frame_end

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
        VDPREG vdp_vscroll
        ld      a, (vertical_scroll)
        inc     a
        ld      (vertical_scroll), a

        WIDE_SCROLL
        SET_HSCROLL 256

        ; If the logo is too low, disable screen
        ld      a, (hl)
        cp      80h
        jr      nc, title_bounce_v_disable

        HSPLIT_LINE 46
        ENABLE_SCREEN
        VDP_STATUS 1
        NEXT_HANDLE title_bounce_h_disable
        ENABLE_HIRQ
        jp      return_irq_exx

title_bounce_v_disable:
        HSPLIT_LINE 10
        DISABLE_SCREEN
        VDP_STATUS 1
        NEXT_HANDLE title_bounce_h_enable
        ENABLE_HIRQ
        jp      return_irq_exx

; H handler to disable screen
title_bounce_h_disable:
        PREAMBLE_HORIZONTAL
        DISABLE_SCREEN
        VDP_STATUS 0
        DISABLE_HIRQ
        jp      frame_end_exx

; H handler to enable screen
title_bounce_h_enable:
        PREAMBLE_HORIZONTAL
        ENABLE_SCREEN
        HSPLIT_LINE 46
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
        SET_HSCROLL 256
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
        VDPREG vdp_hscroll_h
        inc     hl
        ld      a, (hl)
        VDPREG vdp_hscroll_l
        inc     e
        ld      a, e
        ld      (horizontal_scroll), a
        HSPLIT_LINE 118
        NEXT_HANDLE title_slide_disable
        jp      return_irq_exx

title_slide_disable:
        PREAMBLE_HORIZONTAL
        DISABLE_SCREEN
        VDP_STATUS 0
        DISABLE_HIRQ
        jp      frame_end_exx

; ----------------------------------------------------------------
; State: title_stand
; Show the entire logo.

title_stand:
        PREAMBLE_VERTICAL
        ENABLE_SCREEN
        SET_HSCROLL 256
        jp      frame_end_exx

; ----------------------------------------------------------------
; State: erase_title_vram
; Erase vram page 0 in order to prepare to draw the title.

erase_title_vram:
        PREAMBLE_VERTICAL
        exx
        ld      hl, cmd_erase_vram_page0
        call    smart_vdp_command
        VDP_STATUS 0
        jp      frame_end

; ----------------------------------------------------------------
; State: copy_title_vram
; Copy title data to vram.

copy_title_vram:
        PREAMBLE_VERTICAL
        SET_VRAM_WRITE title_addr
        ld      a, (mapper_selectors + 9)
        call    fast_put_p2
        xor     a
        ld      (vertical_scroll), a
        exx
        ld      hl, opening_title
        call    smart_zblit
        jp      frame_end

; ----------------------------------------------------------------
; State: disable_screen
; Turn off the screen.

disable_screen:
        PREAMBLE_VERTICAL
        DISABLE_SCREEN
        jp      frame_end_exx

; ----------------------------------------------------------------
; State: disable_screen
; Turn off the screen and set the palette to all blacks.

disable_screen_black:
        PREAMBLE_VERTICAL
        DISABLE_SCREEN
        exx
        ld      hl, black_palette
        call    smart_palette
        jp      frame_end

; ----------------------------------------------------------------
; State: cloud_setup
; Setup cloud animation.

cloud_setup:
        PREAMBLE_VERTICAL
        WIDE_SCROLL
        SPRITES_16x16
        SPRITE_ATTR moon_attr_addr
        jp      cloud_fade_moon_set_sprite

; ----------------------------------------------------------------
; State: cloud_fade_first
; First frame of fade in the clouds.

cloud_fade_first:
        PREAMBLE_VERTICAL
        ENABLE_SCREEN
        jr      cloud_fade_common

; ----------------------------------------------------------------
; State: cloud_fade
; Fade in the clouds.

cloud_fade:
        PREAMBLE_VERTICAL
cloud_fade_common:
        SET_PAGE 3
        SPRITES_ON
        ; Set v scroll.
        exx
        ld      hl, (current_frame)
        xor     a
        ld      de, cloud_scroll_start_frame
        sbc     hl, de
        jr      c, 1f
        ld      a, (vertical_scroll)
        add     a, 2
        ld      (vertical_scroll), a
1:
        VDPREG vdp_vscroll
        ; Change palette every 6 frames.
        ld      hl, (palette_fade)
        ld      a, (palette_fade_counter)
        dec     a
        jr      nz, 2f
        ld      hl, (palette_fade)
        ld      de, 16 * 2
        add     hl, de
        ld      (palette_fade), hl
        ld      a, 6 + 1
2:
        ld      (palette_fade_counter), a
        call    smart_palette

        HSPLIT_LINE 14
        VDP_STATUS 1
        ENABLE_HIRQ
        ; Patch the scroll values for cloud 1.
        ld      a, (cloud1_scroll)
        ld      ix, cloud_fade_patch
        call    patch_scroll_values
        VDP_AUTOINC vdp_hscroll_h
        NEXT_HANDLE cloud_fade_first_top
        jp      return_irq_exx

cloud_fade_first_top:  
        PREAMBLE_HORIZONTAL
cloud_fade_patch:
        FAST_SET_HSCROLL 0
        HSPLIT_LINE 40
        exx
        ; Patch the scroll values for cloud 2.
        ld      a, (cloud2_scroll)
        ld      ix, cloud_fade_patch2
        call    patch_scroll_values
        VDP_AUTOINC vdp_hscroll_h
        NEXT_HANDLE cloud_fade_first_bottom
        jp      return_irq_exx

cloud_fade_first_bottom:  
        PREAMBLE_HORIZONTAL
        FAST_SET_HSCROLL 256
        HSPLIT_LINE 49
        exx
        NEXT_HANDLE cloud_fade_second_top
        VDP_AUTOINC vdp_hscroll_h
        jp      return_irq_exx

cloud_fade_second_top:
        PREAMBLE_HORIZONTAL
cloud_fade_patch2:
        FAST_SET_HSCROLL 0
        exx
        HSPLIT_LINE 79
        VDP_AUTOINC vdp_hscroll_h
        NEXT_HANDLE cloud_fade_second_bottom
        jp      return_irq_exx

cloud_fade_second_bottom:
        PREAMBLE_HORIZONTAL
        FAST_SET_HSCROLL 256
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 256 - 80
        VDPREG vdp_vscroll
        SET_PAGE 1
        SPRITES_OFF
        exx
        ld      hl, (palette_fade)
        ld      de, city_fade_palette - cloud_fade_palette
        add     hl, de
        call    smart_palette
        HSPLIT_LINE 150 - 79
        NEXT_HANDLE cloud_fade_moon_sprites
        jp      return_irq_exx

cloud_fade_moon_sprites:
        PREAMBLE_HORIZONTAL
        VDP_STATUS 0
        DISABLE_HIRQ
cloud_fade_moon_set_sprite:
        exx
        call    update_cloud_scroll
        ; Set sprite pattern base.
        ld      a, (cloud1_scroll)
        sub     moon_pattern_base_hscroll
        ld      d, a
        srl     a
        srl     a
        srl     a
        add     a, moon_pattern_addr >> 11
        VDPREG vdp_sprite_patt
        ; Set sprite attributes.
        ld      b, 8
        ld      a, d
        and     7
        rrca
        rrca
        rrca
        ld      hl, dynamic_moon_attr + 3
        ld      de, 4
1:
        ld      (hl), a
        add     a, e
        add     hl, de
        djnz    1b
        ; Copy moon attributes to VRAM.
        SET_VRAM_WRITE moon_attr_addr
        ld      hl, dynamic_moon_attr
        call    smart_zblit
        jp      frame_end

; ----------------------------------------------------------------
; Helpers for the cloud states.

update_cloud_scroll:        
        ; Scroll clouds every 4 frames.
        ld      hl, cloud1_scroll
        ld      a, (cloud_tick)
        dec     a
        jr      nz, 1f
        dec     (hl)
        inc     hl
        inc     (hl)
        dec     hl
        ld      a, 4 + 1
1:
        ld      (cloud_tick), a
        ret

patch_scroll_values:
        ; Patch scroll values for very fast response to HIRQ.
        ld      e, a
        ld      d, 0
        ld      hl, absolute_scroll
        add     hl, de
        add     hl, de
        ld      a, (hl)
        ld      (ix + 1), a
        inc     hl
        ld      a, (hl)
        ld      (ix + 5), a
        ret

set_absolute_scroll:
        ; Set an absolute horizontal scroll.
        ld      e, a
        ld      d, 0
        ld      hl, absolute_scroll
        add     hl, de
        add     hl, de
        ld      a, (hl)
        VDPREG vdp_hscroll_h
        inc     hl
        ld      a, (hl)
        VDPREG vdp_hscroll_l
        ret

update_top_building_sprite:
        ; Update the top building sprite attributes.
        SET_VRAM_WRITE top_building_attr_addr
        ld      hl, (top_building_current)
        call    smart_zblit
        ld      hl, (top_building_current)
        ld      de, 2 + 64
        add     hl, de
        ld      (top_building_current), hl
        ret

; ----------------------------------------------------------------
; State: cloud_down2
; Start scrolling down the clouds, step 2.
; Cloud 1 still visible.

cloud_down2:
        PREAMBLE_VERTICAL
        SET_PAGE 3
        SPRITES_ON
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 2
        ld      (vertical_scroll), a
        VDPREG vdp_vscroll
        exx
        ld      hl, cloud_palette_final
        call    smart_palette

        VDP_STATUS 1
        ENABLE_HIRQ
        ; Set directly the scroll values for cloud 1.
        ld      a, (cloud1_scroll)
        call    set_absolute_scroll
        HSPLIT_LINE 40
        ; Patch the scroll values for cloud 2.
        ld      a, (cloud2_scroll)
        ld      ix, cloud_fade_patch2
        call    patch_scroll_values
        VDP_AUTOINC vdp_hscroll_h
        NEXT_HANDLE cloud_fade_first_bottom
        jp      return_irq_exx

; ----------------------------------------------------------------
; State: cloud_down3
; Start scrolling down the clouds, step 3.
; Middle cloud visible.

cloud_down3:
        PREAMBLE_VERTICAL
        SET_PAGE 3
        SPRITES_OFF
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 2
        ld      (vertical_scroll), a
        VDPREG vdp_vscroll
        exx
        ld      hl, cloud_palette_final
        call    smart_palette
        VDP_STATUS 1
        ENABLE_HIRQ
        ; Patch the scroll values for cloud 2.
        ld      a, (cloud2_scroll)
        ld      ix, cloud_down3_patch
        call    patch_scroll_values
        HSPLIT_LINE 49
        NEXT_HANDLE cloud_down3_second_top
        VDP_AUTOINC vdp_hscroll_h
        jp      return_irq_exx

cloud_down3_second_top:
        PREAMBLE_HORIZONTAL
cloud_down3_patch:
        FAST_SET_HSCROLL 0
        exx
        HSPLIT_LINE 70
        ld      hl, (current_frame)
        ld      de, expand_city_line_frame
        or      a
        sbc     hl, de
        jr      nz, 1f
        ld      hl, cmd_expand_city_line_mask
        call    smart_vdp_command
        VDP_STATUS 1
1:
        NEXT_HANDLE cloud_down3_set_vdp_hscroll
        jp      return_irq_exx

cloud_down3_set_vdp_hscroll:
        PREAMBLE_HORIZONTAL
        HSPLIT_LINE 79
        VDP_AUTOINC vdp_hscroll_h
        exx
        NEXT_HANDLE cloud_down3_second_bottom
        jp      return_irq_exx

cloud_down3_second_bottom:
        PREAMBLE_HORIZONTAL
        FAST_SET_HSCROLL 256
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 256 - 80
        VDPREG vdp_vscroll
        SET_PAGE 1
        exx
        ld      hl, city_palette_final
        call    smart_palette
        call    update_cloud_scroll
        VDP_STATUS 0
        DISABLE_HIRQ
        jp      frame_end

; ----------------------------------------------------------------
; State: cloud_down4_first
; Start scrolling down the clouds, step 4, first frame.
; Bottom cloud visible.

cloud_down4_first:
        PREAMBLE_VERTICAL
        SPRITE_ATTR top_building_attr_addr
        SPRITE_PATTERN top_building_patt_addr
        SPRITES_ON
        jr      cloud_down4_start

; ----------------------------------------------------------------
; State: cloud_down4
; Start scrolling down the clouds, step 4.
; Bottom cloud visible.

cloud_down4:
        PREAMBLE_VERTICAL
cloud_down4_start:
        SET_PAGE 3
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 2
        ld      (vertical_scroll), a
        VDPREG vdp_vscroll
        exx
        ld      hl, cloud_palette_final
        call    smart_palette
        VDP_STATUS 1
        ENABLE_HIRQ
        ; Set directly the scroll values for cloud 2.
        ld      a, (cloud2_scroll)
        call    set_absolute_scroll
        HSPLIT_LINE 70
        NEXT_HANDLE cloud_down4_copy_city_line
        jp      return_irq_exx

cloud_down4_copy_city_line:
        PREAMBLE_HORIZONTAL
        HSPLIT_LINE 77
        exx
        ld      hl, (current_frame)
        ld      de, copy_city_line_frame
        or      a
        sbc     hl, de
        jr      nz, 1f
        ld      hl, cmd_copy_city_line_mask
        call    smart_vdp_command
1:
        NEXT_HANDLE cloud_down4_set_vdp_autoinc
        jp      return_irq_exx

cloud_down4_set_vdp_autoinc:
        PREAMBLE_HORIZONTAL
        HSPLIT_LINE 79
        VDP_AUTOINC vdp_hscroll_h
        exx
        NEXT_HANDLE cloud_down4_second_bottom
        jp      return_irq_exx

cloud_down4_second_bottom:
        PREAMBLE_HORIZONTAL
        FAST_SET_HSCROLL 256
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 256 - 80
        VDPREG vdp_vscroll
        SET_PAGE 1
        exx
        ld      hl, city_palette_final
        call    smart_palette
        ; Update top building sprites only on the last frames.
        ld      hl, (current_frame)
        ld      de, down4_sprite_start_frame
        or      a
        sbc     hl, de
        jr      nc, 1f
        VDP_STATUS 0
        DISABLE_HIRQ
        call    update_cloud_scroll
        jp      frame_end
1:
        HSPLIT_LINE 100
        NEXT_HANDLE cloud_down4_sprites
        jp      return_irq_exx

cloud_down4_sprites:
        PREAMBLE_HORIZONTAL
        exx
        call    update_top_building_sprite
        VDP_STATUS 0
        DISABLE_HIRQ
        call    update_cloud_scroll
        jp      frame_end

; ----------------------------------------------------------------
; State: cloud_down5
; Start scrolling down the clouds, step 5.
; Bottom cloud visible and city starting to appear.

cloud_down5:
        PREAMBLE_VERTICAL
        SET_PAGE 3
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 2
        ld      (vertical_scroll), a
        VDPREG vdp_vscroll
        exx
        ld      hl, cloud_palette_final
        call    smart_palette
        VDP_STATUS 1
        ENABLE_HIRQ
        ; Set directly the scroll values for cloud 2.
        ld      a, (cloud2_scroll)
        call    set_absolute_scroll
        HSPLIT_LINE 79
        VDP_AUTOINC vdp_hscroll_h
        NEXT_HANDLE cloud_down5_second_bottom
        jp      return_irq_exx

cloud_down5_second_bottom:
        PREAMBLE_HORIZONTAL
        FAST_SET_HSCROLL 256
        ; Set v scroll.
        exx
        ld      a, (vertical_scroll)
        add     a, 256 - 80
        ld      (city_line), a
        VDPREG vdp_vscroll
        SET_PAGE 1
        ld      a, (city_line)
        ld      b, a
        ld      a, (city_split_line)
        sub     10
        add     a, b
        sub     90
        VDPREG vdp_hsplit_line
        ld      hl, city_palette_final
        call    smart_palette        
        NEXT_HANDLE cloud_down5_sprite_setup
        jp      return_irq_exx

cloud_down5_sprite_setup:
        PREAMBLE_HORIZONTAL
        SPRITES_ON
        exx
        ld      a, (city_line)
        ld      b, a
        ld      a, (city_split_line)
        sub     10
        ld      (city_split_line), a
        add     a, b
        sub     5
        VDPREG vdp_hsplit_line
        call    update_top_building_sprite
        NEXT_HANDLE cloud_down5_city_setup
        jp      return_irq_exx

cloud_down5_city_setup:
        ; In the first four frames: setup autoinc to change the scroll fast.
        ; In the last frame: setup autoinc to change page fast.
        PREAMBLE_HORIZONTAL
        exx
        ld      a, (city_line)
        ld      b, a
        ld      a, (city_split_line)
        add     a, b
        ld      b, a
        VDPREG vdp_hsplit_line
        ld      a, 093h
        cp      b
        jr      z, 1f
        VDP_AUTOINC vdp_vscroll
        NEXT_HANDLE cloud_down5_city
        jp      return_irq_exx
1:
        VDP_AUTOINC vdp_set_page
        NEXT_HANDLE cloud_down5_city_last
        jp      return_irq_exx
        
cloud_down5_city:
        PREAMBLE_HORIZONTAL
        exx
        ld      a, (city_split_line)
        ld      b, a
        ld      hl, (city_scroll)
        ld      a, (hl)
        inc     hl
        ld      (city_scroll), hl
        sub     b
        dec     a
2:
        out     (09Bh), a
        DISABLE_HIRQ
        VDP_STATUS 0
        SPRITES_OFF        
        call    update_cloud_scroll
        jp      frame_end

cloud_down5_city_last:
        PREAMBLE_HORIZONTAL
        ; Set page 3.
        ld      a, (3 << 5) or 011111b
        exx
        jr      2b

; ----------------------------------------------------------------
; State: city_scroll1
; Scroll down the city with parallax, part 1.

city_scroll1:
        PREAMBLE_VERTICAL
        SET_PAGE 1
        SPRITES_ON
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 2
        ld      (vertical_scroll), a
        add     a, 256 - 80
        ld      (city_line), a
        VDPREG vdp_vscroll
        exx
        ; Copy top building sprites.
        call    update_top_building_sprite
        ; H split to city2.
        ld      a, (city_line)
        ld      b, a
        ld      a, (city_split_line)
        sub     10
        ld      (city_split_line), a
        add     a, b
        ld      b, a
        VDPREG vdp_hsplit_line
        VDP_STATUS 1
        ENABLE_HIRQ
        NEXT_HANDLE city_scroll1_foreground
        jp      return_irq_exx

city_scroll1_foreground:
        PREAMBLE_HORIZONTAL
        SET_PAGE 0
        ld      a, (city_split_line)
        neg
        dec     a
        VDPREG  vdp_vscroll
        SPRITES_OFF
        VDP_STATUS 0
        DISABLE_HIRQ
        exx
        jp      frame_end

; ----------------------------------------------------------------
; State: disable_screen_title
; Disable the screen just before the title

disable_screen_title:
        PREAMBLE_VERTICAL
        DISABLE_SCREEN
        SPRITES_OFF
        SET_PAGE 1
        exx
        ld      hl, title_palette
        call    smart_palette
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
; Decompress graphics, assumes VRAM address is already set.
; Input: HL = address

zblit:
        ld      a, (hl)
        inc     hl
        or      a
        ret     z
        jp      m, zblit_rle
        ld      b, a
        ld      c, 098h
        otir
        jr      zblit
zblit_rle:
        sub     080h
        ld      b, a
        ld      a, (hl)
        inc     hl
1:
        out     (098h), a
        djnz    1b
        jr      zblit

; ----------------------------------------------------------------
; Start a VDP command.
; Input: HL=table with vdp commands

vdp_command:
        VDP_STATUS 2
1:
        in      a, (099h)
        rrca
        jr      c, 1b
        ; Set VDP to autoinc.
        ld      a, (hl)
        VDPREG  17
        ld      a, 47
        sub     (hl)
        ld      b, a
        ld      c, 09Bh
        inc     hl
        otir
2:
        in      a, (099h)
        rrca
        jr      c, 2b
        VDP_STATUS 0
        ret

; ----------------------------------------------------------------
; Start a VDP command without stopping the pcm sample.
; Input: HL=table with vdp commands
; Destroy: VDP Status

smart_vdp_command:
        ; Check for foreground overrun.
        push    hl
        call    check_foreground
        pop     hl
        ; Check for VDP overrun.
        VDP_STATUS 2
        in      a, (099h)
        rrca
        ld      de, str_vdp_error
        jp      c, graphic_abort
        ; Set VDP to autoincrement. 
        ld      a, (hl)
        VDPREG 17
        ; Setup foreground thread.
        ld      a, 47
        sub     (hl)
        inc     hl
        push    hl
        exx
        pop     hl
        ld      b, a
        exx
        ld      hl, foreground_vdp_command
        ld      (foreground + 1), hl
        ret

foreground_vdp_command:
        ld      a, (hl)
        out     (09Bh), a
        inc     hl
        dec     b
        jp      nz, foreground_next
        jp      foreground_ret

; ----------------------------------------------------------------
; Decompress graphics without stopping the pcm sample.
; Input: HL=graphics

smart_zblit:
        ld      a, (is_playing)
        or      a
        jp      z, zblit

        push    hl
        exx
        pop     hl
        exx
        call    check_foreground
        ld      hl, foreground_zblit
        ld      (foreground + 1), hl
        ret

foreground_zblit:
        ld      a, (hl)
        inc     hl
        or      a
        jp      z, foreground_ret
        jp      m, foreground_rle_setup

        ; Setup zblit copy.
        ld      bc, foreground_copy_step
        ld      (foreground + 1), bc
        ld      b, a
        jp      foreground_next

        ; Setup zblit rle.
foreground_rle_setup:
        ld      bc, foreground_rle_step
        ld      (foreground + 1), bc
        sub     080h
        ld      b, a
        jp      foreground_next

foreground_copy_step:
        ld      a, (hl)
        inc     hl
        out     (098h), a
        dec     b
        jp      nz, foreground_next
        ld      bc, foreground_zblit
        ld      (foreground + 1), bc
        jp      foreground_next

foreground_rle_step:
        ld      a, (hl)
        out     (098h), a
        dec     b
        jp      nz, foreground_next
        inc     hl
        ld      bc, foreground_zblit
        ld      (foreground + 1), bc
        jp      foreground_next

; ----------------------------------------------------------------
; Set the palette without stopping the pcm sample.

smart_palette:
        ld      a, (is_playing)
        or      a
        jr      nz, 1f
        SET_PALETTE
        ret
1:
        xor     a
        VDPREG  16
        push    hl
        exx
        pop     hl
        ld      b, 32
        exx
        call    check_foreground
        ld      hl, foreground_palette
        ld      (foreground + 1), hl
        ret

foreground_palette:
        ld      a, (hl)
        out     (09Ah), a
        inc     hl
        dec     b
        jp      nz, foreground_next
        ; fall through

foreground_ret:
        ld      hl, foreground_next
        ld      (foreground + 1), hl
        jp      (hl)

check_foreground:
        ld      hl, (foreground + 1)
        ld      de, foreground_next
        or      a
        sbc     hl, de
        ld      de, str_foreground_error
        jp      nz, graphic_abort
        ret

; ----------------------------------------------------------------
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
        ; Print the message.
        ld      c, strout
        call    bdos
        jp      restart

; Restore DOS2 environment, print error message, abort and return to dos.
; Input: de = error message terminated in $
graphic_abort:
        push    de
        call    restore_irq
        call    restore_environment
        pop     de
        jr      abort

restore_environment:
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
        ld      a, (mapper_selectors + 1)
        jp      fast_put_p2

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

; Call HL.
call_hl:
        jp      (hl)

; Fast put page 1.
fast_put_p1:
        jp      0

; Fast put page 2.
fast_put_p2:
        jp      0

; ----------------------------------------------------------------
; Variables.

save_irq:               db      0,0,0
file_handle:            db      0
mapper:                 dw      0
save_palette:           dw      0
city_line:              db      0
mapper_selectors:       ds      selectors, 0

; ----------------------------------------------------------------
; Misc strings.

str_dos2_not_found:     db      "MSX-DOS 2 not found, sorry.$"
str_not_turbor:         db      "This MSX is not a turboR, sorry.$"
str_read_error:         db      "Error reading from disk, sorry.$"
str_not_enough_memory:  db      "Not enough memory, sorry.$"
str_foreground_error:   db      "Foreground thread overrun.$"
str_vdp_error:          db      "VDP command overrun.$"
str_loading:            db      "Loading$"
str_dot:                db      ".$"
str_press_any_key:      db      13, 10, "Press any key to start.$"
str_credits:            db      "TMNT Attract Mode 1.0", 13, 10
                        db      "by Ricardo Bittencourt 2014.", 13, 10, "$"
mapper_data_filename:   dz      "attract.dat"

; ----------------------------------------------------------------
; Data

title_palette:          incbin  "title_bounce_palette.bin"
title_bounce_data:      incbin  "title_bounce_scroll.bin"
title_slide_data:       incbin  "title_slide_scroll.bin"
cloud_fade_palette:     incbin  "cloud_fade_palette.bin"
city_fade_palette:      incbin  "city_fade_palette.bin"
absolute_scroll:        incbin  "absolute_scroll.bin"
city_line_mask:         incbin  "cityline.z5"
handles:                include "handles.inc"
black_palette:          ds      16 * 2, 0
cloud_palette_final     equ     cloud_fade_palette + 512
city_palette_final      equ     city_fade_palette + 512

                        align   256
advance_pcm:            incbin  "advance_pcm.bin"

; Dynamic sprite attr data for the moon.
dynamic_moon_attr:
        db      8 * 4 + 1
        rept    4
        db      14, 72, 0, 0
        db      14, 72 + 16, 0, 0
        endr
        db      0xD8, 0

; City scroll positions for state cloud_down5.
city_scroll_down5:        
        db      188, 188 + 2, 188 + 14, 188 + 36

; ----------------------------------------------------------------
; VDP commands

; Erase page 0 of vram.
cmd_erase_vram_page0:           
        VDP_HMMV 0, 0, 256, 192, 0

; Erase all vram.        
cmd_erase_all_vram:             
        VDP_HMMV 0, 0, 256, 1023, 0

; Copy the parallax scroll of cloud_down5 to the right place.
cmd_copy_city_back:             
        VDP_YMMM 256 + 180,          0, 768 + 128,       2 
        VDP_YMMM 256 + 180 - 10 + 2, 0, 768 + 128 + 2,  12
        VDP_YMMM 256 + 180 - 20 + 4, 0, 768 + 128 + 14, 22
        VDP_YMMM 256 + 180 - 30 + 6, 0, 768 + 128 + 36, 32
        VDP_YMMM 256 + 180 - 40 + 8, 0, 768 + 128 + 68, 42
        VDP_LMMM 0, 0, 0, 768 + 128,      256,  2, vdp_timp
        VDP_LMMM 0, 0, 0, 768 + 128 + 2,  256, 12, vdp_timp
        VDP_LMMM 0, 0, 0, 768 + 128 + 14, 256, 22, vdp_timp
        VDP_LMMM 0, 0, 0, 768 + 128 + 36, 256, 32, vdp_timp
        VDP_LMMM 0, 0, 0, 768 + 128 + 68, 256, 42, vdp_timp
        VDP_YMMM 768 + 128,          0, 256 + 188,      68
        VDP_YMMM 768 + 128 + 68,     0, 768 + 148,      42

; Expand the city line mask to cover 140 lines.
cmd_expand_city_line_mask:
        VDP_YMMM 593, 0, 594, 140

; Copy city2 over the city line mask.
cmd_copy_city_line_mask:
        VDP_LMMM 0, 0, 0, 593, 256, 140, vdp_timp

end_of_code:
        assert  end_of_code <= 04000h

; ----------------------------------------------------------------
; Mapper Data

        output  attract.dat

        macro   PAGE_LIMIT
        assert  $ <= 0C000h
        endm

; Mapper pages 0-8
theme_music:            incbin "theme.pcm"

; Mapper page 9
                        .phase  08000h
opening_title:          incbin "tmnt.z5"
cloud_page2:            incbin "cloud2.z5"
cloud_page3:            incbin "cloud3.z5"
                        PAGE_LIMIT                
                        align 16384

; Mapper page 10
                        .phase  08000h
city_page1:             incbin "city1.z5"
moon_pattern:           incbin "moon_pattern.z5"
moon_attr:              incbin "moon_attr.z5"
                        PAGE_LIMIT
                        align 16384

; Mapper page 11
                        .phase  08000h
city2a:                 incbin "city2a.z5"
top_building_pattern:   incbin "top_building_patt.z5"
top_building_attr:      incbin "top_building_attr.z5"
top_building_dyn_attr:  incbin "top_building_dyn_attr.bin"
                        PAGE_LIMIT
                        align 16384

; Mapper page 12
                        .phase  08000h
city2b:                 incbin "city2b.z5"
                        PAGE_LIMIT
                        align 16384

        end

