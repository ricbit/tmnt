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

def map_sc5(left_right_tuple):
  return map(lambda x: convert_sc5(x, 0, 212), left_right_tuple)

def extend_half_screen(line_start, size, lr, last_lr, stream, stream_size):
  before = len(stream)
  stream.extend(compress_diff(
    lr[0], last_lr[0], 0x10000, line_start, size, close_stream=False))
  stream.extend(compress_diff(
    lr[1], last_lr[1], 0x18000, line_start, size))
  diff_size = len(stream) - before
  print i, diff_size
  stream_size.append(diff_size % 256)
  stream_size.append(diff_size >> 8)

# Initial state of vram
left, right = getlr(large)
left_sc5, right_sc5 = map_sc5((left, right))
zero_sc5 = [0] * (128 * 212)
save_sc5("".join(chr(i) for i in left), "poster_left.sc5", 0, 212)
save_diff(right_sc5, zero_sc5, 0x18000, 0, 212, "poster_right.d5")

# States turtles_slide1 and turtles_slide2
last_left, last_right = left_sc5, right_sc5
start = 256 - 20
size = 20
hscroll = 100
stream = []
stream_size = []
for i in xrange(0, 14):
  last_large = large[:]
  print i, " offset ", hscroll + 256 - size
  # Emulate vdp command
  for j in xrange(i * 4):
    top = 103 - j
    bottom = 108 + j
    offset = hscroll + 256 - size
    last_large[top * 512 + offset: top * 512 + offset + 8] = [0xa] * 8
    last_large[bottom * 512 + offset: bottom * 512 + offset + 8] = [0x8] * 8
  last_left, last_right = map_sc5(getlr(last_large))
  # Diffblit
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
  left, right = lr = map_sc5(getlr(large))
  last_lr = [last_left, last_right]
  extend_half_screen(0, 212 / 2, lr, last_lr, stream, stream_size)
  extend_half_screen(212 / 2, 212 / 2, lr, last_lr, stream, stream_size)
f = open("poster_slide_diff.d5", "wb")
f.write("".join(chr(i) for i in stream))
f.close()
stream_size.extend([0, 0])
f = open("poster_slide_size.bin", "wb")
f.write("".join(chr(i) for i in stream_size))
f.close()

# States turtles_slide3
stream = []
stream_size = []
for i in xrange(14, 20):
  last_large = large[:]
  print i, " offset ", hscroll + 256 - size
  # Emulate vdp command
  for j in xrange(i * 4):
    top = 103 - j
    bottom = 108 + j
    offset = hscroll + 256 - size
    last_large[top * 512 + offset: top * 512 + offset + 8] = [0xa] * 8
    last_large[bottom * 512 + offset: bottom * 512 + offset + 8] = [0x8] * 8
  last_left, last_right = map_sc5(getlr(last_large))
  # Diffblit
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
  left, right = lr = map_sc5(getlr(large))
  last_lr = [last_left, last_right]
  extend_half_screen(
    0, 212 / 4, lr, last_lr, stream, stream_size)
  extend_half_screen(
    0, 212 / 4, lr, last_lr, stream, stream_size)
f = open("poster_slide3_diff.d5", "wb")
f.write("".join(chr(i) for i in stream))
f.close()
stream_size.extend([0, 0])
f = open("poster_slide3_size.bin", "wb")
f.write("".join(chr(i) for i in stream_size))
f.close()

