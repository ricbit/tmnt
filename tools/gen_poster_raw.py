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
c.save_sc5("".join(chr(i) for i in right), "poster_right.sc5", 0, 212)

def save_diff(newsc5, oldsc5, start, filename):
  page = -1
  pos = 0
  out = []
  while pos < len(newsc5):
    if newsc5[pos] == oldsc5[pos]:
      pos += 1
    else:
      stripe = []
      addr = start + pos
      page = addr >> 14
      vrampos = addr and 0x3FFF
      while pos < len(newsc5) and newsc5[pos] != oldsc5[pos]:
        stripe.append(newsc5[pos])
        pos += 1
      out.append(128 + page)
      out.append(128 + 64 + (vrampos >> 8))
      out.append(vrampos and 255)
      size = len(stripe)
      while size > 0:
        if (size > 63):
          out.append(63)
          out.extend(stripe[:63])
          stripe = stripe[63:]
          size -= 63
        else:
          out.append(len(stripe))
          out.extend(stripe)
          size = 0
  f = open(filename, "wb")
  f.write("".join(chr(i) for i in out))
  f.close()

save_diff(right_sc5, zero_sc5, 0x18000, "poster_right.d5")

