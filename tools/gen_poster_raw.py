# Convert poster rgb to screen 5.

from convert_raw import convert_sc5, save_sc5
from compress_graphics import compress_diff, save_diff

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

def getlr(large):
  left = [0] * (256 * 212)
  right = [0] * (256 * 212)
  for i in xrange(212):
    left[i * 256 : i * 256 + 256] = large[i * 512 : i * 512 + 256]
    right[i * 256 : i * 256 + 256] = large[i * 512 + 256: i * 512 + 512]
  return left, right

left, right = getlr(large)
left_sc5 = convert_sc5(left, 0, 212)
right_sc5 = convert_sc5(right, 0, 212)
zero_sc5 = [0] * (128 * 212)
save_sc5("".join(chr(i) for i in left), "poster_left.sc5", 0, 212)
save_diff(right_sc5, zero_sc5, 0x18000, "poster_right.d5")

last_left, last_right = left_sc5, right_sc5
start = 256 - 20
size = 20
hscroll = 100
start -= 4
size += 4
hscroll -= 4
stream = []
stream_size = []
for i in xrange(1, 15):  
  for j in xrange(i * 4 + 4):
    top = 103 - j
    bottom = 108 + j
    offset = hscroll + 256 - size
    large[top * 512 + offset: top * 512 + size + offset] = raw[
        top * 256 + 130 : top * 256 + 130 + size]
    large[bottom * 512 + offset: bottom * 512 + size + offset] = raw[
        bottom * 256 + 130 : bottom * 256 + 130 + size]
  start -= 4
  size += 4
  hscroll -= 4
  left, right = map(lambda x: convert_sc5(x, 0, 212), getlr(large))
  before = len(stream)
  stream.extend(compress_diff(left, last_left, 0x10000, close_stream=False))
  stream.extend(compress_diff(right, last_right, 0x18000))
  diff_size = len(stream) - before
  stream_size.append(diff_size % 256)
  stream_size.append(diff_size >> 8)
  last_left, last_right = left, right
f = open("poster_slide_diff.d5", "wb")
f.write("".join(chr(i) for i in stream))
f.close()
f = open("poster_slide_size.bin", "wb")
f.write("".join(chr(i) for i in stream_size))
f.close()

