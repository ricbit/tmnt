# Convert raw rgb to screen 5.

import sys

raw = open(sys.argv[1], "rb").read()
f = open(sys.argv[2], 'wb')
for i in xrange(256*192/2):
  a = (ord(raw[i*2 + 0]) << 4) + ord(raw[i*2 + 1])
  f.write(chr(a))
f.close()

