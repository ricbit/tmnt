# Convert raw rgb to screen 5.

import sys

def convert_sc5(raw, start, size):
  out = []
  start *= 256
  for i in xrange(128 * size):
    out.append(((raw[start + i*2 + 0]) << 4) + (raw[start + i*2 + 1]))
  return out

def save_sc5(raw, filename, start, size):
  out = convert_sc5([ord(i) for i in raw], start, size)
  f = open(filename, "wb")
  f.write("".join(chr(i) for i in out))
  f.close()

if __name__ == '__main__':
  raw = open(sys.argv[1], "rb").read()
  if len(raw) % 256 != 0:
    print "Warning: %s is not a multiple of 256" % sys.argv[1]
  save_sc5(raw, sys.argv[2], 0, len(raw) / 256)

