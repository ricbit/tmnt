f = open("absolute_scroll.bin", "wb")
for i in xrange(257):
  x = (i + 7) / 8
  y = x * 8 - i
  f.write(chr(x))
  f.write(chr(y))
f.close()
