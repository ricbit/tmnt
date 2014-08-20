# Convert poster rgb to screen 5.

import convert_raw as c

raw = [ord(i) for i in open("raw/turtles.raw", "rb").read()]
large = [0] * (512 * 212)
for i in xrange(212):
  large[i * 512 : i * 512 + 128] = raw[i * 256 : i * 256 + 128]
start = 256 - 20
size = 20
hscroll = 100
for i in xrange(26):
  for j in xrange(4):
    top = 103 - i * 4 - j
    bottom = 108 + i * 4 + j
    offset = hscroll + 256 - size
    large[top * 512 + offset: top * 512 + size + offset] = raw[
        top * 256 + 130 : top * 256 + 130 + size]
    large[bottom * 512 + offset: bottom * 512 + size + offset] = raw[
        bottom * 256 + 130 : bottom * 256 + 130 + size]
  start -= 4
  size += 4
  hscroll -= 4
left = [0] * (256 * 212)
right = [0] * (256 * 212)
for i in xrange(212):
  left[i * 256 : i * 256 + 256] = large[i * 512 : i * 512 + 256]
  right[i * 256 : i * 256 + 256] = large[i * 512 + 256: i * 512 + 512]
right_sc5 = c.convert_sc5(right, 0, 212)
zero_sc5 = [0] * (128 * 212)
c.save_sc5("".join(chr(i) for i in left), "poster_left.sc5", 0, 212)

def save_diff(newsc5, oldsc5, start, name):
  page = start >> 14
  addr = start and 0x3FFF

save_diff(right_sc5, zero_sc5, 0x18000, "poster_right.d5")

