set throttle off

debug set_bp 0x9f {} {type "tmnt"}

proc readmemw {addr} {
  expr {
    [debug read "memory" $addr] + 
    256 * [debug read "memory" [expr {$addr + 1}]]
  }
}

debug set_watchpoint write_mem 0x104 {[readmemw 0x103] == 521} {
  record start "/home/ricbit/work/tmnt/tmntmsx.avi"
}

debug set_watchpoint write_mem 0x104 {[readmemw 0x103] == 1000} {
  record stop
  quit
}
