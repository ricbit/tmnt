# Convert poster rgb to screen 5.

import convert_raw

raw = [ord(i) for i in open("raw/turtles.raw", "rb").read()]
large = [0] * (512 * 212)
for i in xrange(212):
  large[i * 512 : i * 512 + 128] = raw[i * 256 : i * 256 + 128]
left = [0] * (256 * 212)
for i in xrange(212):
  left[i * 256 : i * 256 + 256] = large[i * 512 : i * 512 + 256]
convert_raw.save_sc5("".join(chr(i) for i in left), "poster_left.sc5", 0, 212)

