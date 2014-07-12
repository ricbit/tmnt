set throttle off
set running 0
set current_frame 0

debug set_bp 0x9f {} {type "tmnt"}

proc readmemw {addr} {
  expr {
    [debug read "memory" $addr] + 
    256 * [debug read "memory" [expr {$addr + 1}]]
  }
}

debug probe set_bp VDP.IRQvertical {
  $running == 1 && $current_frame != [readmemw 0x103]
} {
  set current_frame [readmemw 0x103]
  puts stderr "Frame $current_frame"
}

debug set_bp 0xC000 {$current_frame >= 750} {
  puts stderr "smart_zblit starting at line [machine_info VDP_msx_y_pos]"
}

debug set_bp 0xC003 {} {
  puts stderr "smart_zblit ending at line [machine_info VDP_msx_y_pos]"
}

debug set_watchpoint write_mem 0x104 {[readmemw 0x103] == 521} {
  record start "/home/ricbit/work/tmnt/tmntmsx.avi"
  set running 1
}

debug set_watchpoint write_mem 0x104 {[readmemw 0x103] == 900} {
  record stop
  quit
}
