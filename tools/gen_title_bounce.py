# Generate v scroll values for title bounce.

import sys

f = open("title_bounce_scroll.bin", "wb")
x = 0
s = 1301
for n in sys.stdin:
  if n.startswith("#"): 
    continue
  x = (47 - int(n) + 256 ) % 256
  f.write(chr(x))
  s += 1
for i in xrange(s, 1375):
  f.write(chr(0))
f.close()
