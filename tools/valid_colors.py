for i in xrange(8):
  c = (i<<5) + (i<<2) + (i>>1)
  print "%02X %d" % (c, c)
