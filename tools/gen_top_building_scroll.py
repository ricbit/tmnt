baseaddr = 0x13600
def pos(addr):
  return (addr / 128, addr % 128 * 2)
for i in xrange(4):
  dy, dx = pos(baseaddr)
  sy, sx = pos(baseaddr + i * 64 + 64)
  print "\tVDP_HMMM %d, %d, %d, %d, 128, 1" % (sx, sy, dx, dy)
