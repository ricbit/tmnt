# Convert raw rgb to screen 5.

import sys

def save_sc5(raw, filename, start, size):
  f = open(filename, "wb")
  start *= 256
  for i in xrange(128 * size):
    a = (ord(raw[start + i*2 + 0]) << 4) + ord(raw[start + i*2 + 1])
    f.write(chr(a))
  f.close()

if __name__ == '__main__':
  raw = open(sys.argv[1], "rb").read()
  if len(raw) % 256 != 0:
    print "Warning: %s is not a multiple of 256" % sys.argv[1]
  save_sc5(raw, sys.argv[2], 0, len(raw) / 256)

