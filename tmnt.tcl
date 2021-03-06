set throttle off
set mute on
set running 0
set current_frame 0
set vdp_command_running 0
set fast_emulation 0
set last_sample -1
set measure_sample -1
set measure_acc 0
set measure_total 0
set freq_hist [dict create]
set irqon 0

# Parse sym file.
set symfile [open "attract.sym" r]
set symlines [split [read $symfile] "\n"]
close $symfile
set symlabel [dict create]
foreach line $symlines {
  if {[regexp {([^:]+): equ (0x[0-9A-F]+)} $line _ name value]} {
    dict append symlabel $name [expr $value]
  }
}

proc getlabel {label_name} {
  global symlabel
  dict get $symlabel $label_name
}

proc vdplines {} {
  if {[expr [vdpreg 9] & 128] > 0} {
    return 212 
  } else {
    return 192
  }
}

debug set_bp [getlabel measure_sample_start] {$running} {
  set measure_sample [machine_info time]
}

debug set_bp [getlabel foreground_continue] {$measure_sample >= 0} {
  set measure_acc [expr $measure_acc + [machine_info time] - $measure_sample]
  set measure_total [expr $measure_total + 1]
  set measure_sample -1
}


debug set_bp [getlabel play_sample] {$running} {
  if {$last_sample > 0} {
    set freq [expr int(0.01 / ([machine_info time] - $last_sample))]
    dict incr freq_hist $freq
  }
  set last_sample [machine_info time]
}

debug probe set_bp VDP.IRQhorizontal {$running} {
  if {[debug read {VDP regs} 15] != 1} {
    puts stderr "HIRQ but VDP status is [debug read {VDP regs} 15]"
    puts stderr "on line [machine_info VDP_msx_y_pos]"
    record stop
    exit
  } else {
    if {$irqon == 0} {
      puts stderr "HIRQ at [machine_info VDP_msx_y_pos]"
      set irqon 1
    }
  }
}

debug probe set_bp VDP.IRQvertical {
  $running == 1 && $current_frame != [peek16 [getlabel current_frame]]
} {
  set current_frame [peek16 [getlabel current_frame]]
  puts stderr "\nFrame $current_frame, lines=[vdplines]"
  puts stderr "VIRQ at [machine_info VDP_msx_y_pos]"
  set irqon 1
  #if {$current_frame == 1155} {
  #  debug break
  #}
  if {[debug read {VDP regs} 15] != 0} {
    puts stderr "VIRQ but VDP status is [debug read {VDP regs} 15]"
    puts stderr "on line [machine_info VDP_msx_y_pos]"
    record stop
    exit
  }
}

debug set_bp [getlabel return_irq] {$running && $irqon} {
  puts stderr "IRQ return at [machine_info VDP_msx_y_pos]"
  set irqon 0
}

debug set_bp [getlabel smart_zblit] {$running} {
  puts stderr "smart_zblit starting at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel smart_zblit_end] {$running} {
  puts stderr "smart_zblit ending at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel zblit_end] {$running} {
  puts stderr "smart_zblit ending at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel foreground_diffblit_end] {$running} {
  puts stderr "diffblit ending at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel short_palette_queued] {$running} {
  puts stderr "smart_palette queued at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel short_palette] {$running} {
  puts stderr "smart_palette starting at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel smart_palette] {$running} {
  puts stderr "smart_palette starting at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel smart_palette_end] {$running} {
  puts stderr "smart_palette ending at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel palette_end] {$running} {
  puts stderr "smart_palette ending at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel smart_vdp_command] {$running} {
  puts stderr "smart_vdp_command starting at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel smart_vdp_command_queued] {$running} {
  puts stderr "smart_vdp_command queued at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel smart_zblit_queued] {$running} {
  puts stderr "smart_zblit queued at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel process_diffblit] {$running} {
  puts stderr "diffblit queued at [machine_info VDP_msx_y_pos]"
}

debug set_bp [getlabel smart_vdp_command_end] {$running} {
  puts stderr "smart_vdp_command ending at [machine_info VDP_msx_y_pos]"
  if {$fast_emulation == 0} {
    set vdp_command_running [
      debug set_condition {
        $vdp_command_running != 0 && 
        [expr {[debug read {VDP status regs} 2] & 1}] == 0
      } {
        debug remove_condition $vdp_command_running
        set vdp_command_running 0
        puts stderr "smart_vdp_command stopping at [machine_info VDP_msx_y_pos]"
      }
    ]
  }
}

debug set_watchpoint write_mem [expr 1 + [getlabel current_frame]] {
  [peek16 [getlabel current_frame]] == 521
} {
  record start "/home/ricbit/work/tmnt/tmntmsx.avi"
  set running 1
}

debug set_watchpoint write_mem [expr 1 + [getlabel current_frame]] {
  [peek16 [getlabel current_frame]] == 1500
} {
  record stop
  puts stderr "Histogram of frequencies:"
  foreach freq [lsort -integer [dict keys $freq_hist]] {
    puts stderr "freq [expr 100 * $freq] -> [dict get $freq_hist $freq]"
  }
  puts stderr "Mean measure = [expr $measure_acc / $measure_total]"
  quit
}

proc vc {offset} {
  peek16 [expr [reg hl] - $offset]
}

debug set_bp [getlabel foreground_vdp_command] {[reg b] == 1} {
  if {[peek [reg hl]] == 0xC0} {
    puts stderr [format "%s%02X" \
                 "HMMV cmd dx=[vc 10] dy=[vc 8] nx=[vc 6] ny=[vc 4] color=0x" \
                 [vc 2]]
  }
  if {[peek [reg hl]] == 0xD0} {
    puts stderr [format "%s%s" \
                 "HMMM cmd sx=[vc 14] sy=[vc 12] dx=[vc 10] dy=[vc 8] " \
                 "nx=[vc 6] ny=[vc 4]"]
  }
  if {[peek [reg hl]] == 0xE0} {
    puts stderr [format "%s%s" \
                 "YMMM cmd sy=[vc 12] dx=[vc 10] dy=[vc 8] " \
                 "ny=[vc 4]"]
  }
  if {[expr [peek [reg hl]] & 0xF0] == 0x90} {
    puts stderr [format "%s%s" \
                 "LMMM cmd sx=[vc 14] sy=[vc 12] dx=[vc 10] dy=[vc 8] " \
                 "nx=[vc 6] ny=[vc 4]"]
  }
}
