set throttle off
debug set_bp 0x9f {} {type "tmnt"}
debug set_watchpoint write_mem 0x104 {[debug read "memory" 0x103] == 0x9 && [debug read "memory" 0x104] == 0x2} {record start "/home/ricbit/work/tmnt/tmntmsx.avi"}
debug set_watchpoint write_mem 0x104 {[debug read "memory" 0x103] == 0xe8 && [debug read "memory" 0x104] == 0x3} {record stop}
debug set_watchpoint write_mem 0x104 {[debug read "memory" 0x103] == 0xe9 && [debug read "memory" 0x104] == 0x3} {quit}
