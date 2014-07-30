# Generate h scroll values for title slide.

import sys

f = open("title_slide_scroll.bin", "wb")
for line in sys.stdin:
  if line.startswith("#"):
    continue
  n = 256 + 40 - int(line)
  if n < 0:
    n = 0
  x = (n+7)/8*8
  y = x - n
  f.write(chr(x >> 3))
  f.write(chr(y))
f.close()

