# Convert city2 rgb to screen 5.

import sys

raw = open(sys.argv[1], "rb").read()
f1 = open(sys.argv[2], 'wb')
f2 = open(sys.argv[3], 'wb')
start = 38 * 256
for i in xrange(128 * 256 / 2):
  a = (ord(raw[start + i*2 + 0]) << 4) + ord(raw[start + i*2 + 1])
  f1.write(chr(a))
start += 128 * 256
for i in xrange(128 * 256 / 2):
  a = (ord(raw[start + i*2 + 0]) << 4) + ord(raw[start + i*2 + 1])
  f2.write(chr(a))
f1.close()
f2.close()

