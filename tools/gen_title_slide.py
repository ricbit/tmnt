# Generate h scroll values for title slide.

import sys

f = open("title_slide_scroll.bin", "wb")
for line in sys.stdin:
  n = 256 + 40 - int(line)
  if n < 0:
    n = 0
  x = (n+7)/8*8
  y = x - n
  print n, x, y
  f.write(chr(x >> 3))
  f.write(chr(y))
f.close()

