# Convert poster rgb to screen 5.

import convert_raw as c

raw = [ord(i) for i in open("raw/turtles.raw", "rb").read()]
large = [0] * (512 * 212)
for i in xrange(212):
  large[i * 512 : i * 512 + 128] = raw[i * 256 : i * 256 + 128]
  large[i * 512 + 256: i * 512 + 256 + 128] = raw[i * 256 + 128: i * 256 + 256]
left = [0] * (256 * 212)
right = [0] * (256 * 212)
for i in xrange(212):
  left[i * 256 : i * 256 + 256] = large[i * 512 : i * 512 + 256]
  right[i * 256 : i * 256 + 256] = large[i * 512 + 256: i * 512 + 512]
c.save_sc5("".join(chr(i) for i in left), "poster_left.sc5", 0, 212)
c.save_sc5("".join(chr(i) for i in right), "poster_right.sc5", 0, 212)

