# Convert poster rgb to screen 5.

from convert_raw import convert_sc5, save_sc5
from compress_graphics import compress_diff, save_diff, split_diff

def copy(last_large, top, stride, offset, size, raw, stride2, offset2):
  last_large[top * stride + offset: top * stride + offset + size] = (
    raw[top * stride2 + offset2: top * stride2 + offset2 + size])

raw = [ord(i) for i in open("raw/turtles.raw", "rb").read()]
background_a = [0xa] * 256
background_8 = [0x8] * 256
large = [0] * (512 * 212)
for i in xrange(212):
  copy(large, i, 512, 0, 128, raw, 256, 0)
start = 256 - 20
size = 20
hscroll = 100
for i in xrange(26):
  for j in xrange(4):
    top = 103 - i * 4 - j
    bottom = 108 + i * 4 + j
    offset = hscroll + 256 - size
    copy(large, top, 512, offset, size, raw, 256, 130)
    copy(large, bottom, 512, offset, size, raw, 256, 130)
  start -= 4
  size += 4
  hscroll -= 4
for i in xrange(192):
  copy(large, i, 512, 256 + 128, 128, raw, 256, 128)

def getlr(large):
  left = [0] * (256 * 212)
  right = [0] * (256 * 212)
  for i in xrange(212):
    copy(left, i, 256, 0, 256, large, 512, 0)
    copy(right, i, 256, 0, 256, large, 512, 256)
  return left, right

def map_sc5(left_right_tuple):
  return map(lambda x: convert_sc5(x, 0, 212), left_right_tuple)

def extend_half_screen(line_start, size, lr, last_lr, stream, stream_size):
  before = len(stream)
  new_stream = []
  new_stream.extend(compress_diff(
    lr[0], last_lr[0], 0x10000, line_start, size, close_stream=False))
  new_stream.extend(compress_diff(
    lr[1], last_lr[1], 0x18000, line_start, size, close_stream=False))
  stream.extend(new_stream)
  stream.append(0)
  diff_size = len(stream) - before
  print diff_size
  stream_size.append(diff_size % 256)
  stream_size.append(diff_size >> 8)

def chunk_half_screen(line_start, size, lr, last_lr, 
                      stream, stream_size, chunk):
  before = len(stream)
  new_stream = []
  new_stream.extend(compress_diff(
    lr[0], last_lr[0], 0x10000, line_start, size, close_stream=False))
  new_stream.extend(compress_diff(
    lr[1], last_lr[1], 0x18000, line_start, size, close_stream=False))
  packs = split_diff(new_stream, chunk)
  print [len(i) for i in packs]
  for p in packs:
    stream.extend(p)
    stream.append(0)
    diff_size = len(stream) - before
    stream_size.append(diff_size % 256)
    stream_size.append(diff_size >> 8)
    before = len(stream)

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
  print 1138 + i, " offset ", hscroll + 256 - size, " size ", size
  # Emulate vdp command
  for j in xrange(i * 4):
    top = 103 - j
    bottom = 108 + j
    offset = hscroll + 256 - size
    copy(last_large, top, 512, offset, 8, background_a, 0, 0)
    copy(last_large, bottom, 512, offset, 8, background_8, 0, 0)
  last_left, last_right = map_sc5(getlr(last_large))
  # Diffblit
  for j in xrange(i * 4 + 4):
    top = 103 - j
    bottom = 108 + j
    offset = hscroll + 256 - size
    copy(large, top, 512, offset, size, raw, 256, 130)
    copy(large, bottom, 512, offset, size, raw, 256, 130)
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

# State turtles_slide3
stream = []
stream_size = []
commands = []
for i in xrange(14, 18):
  last_large = large[:]
  print 1138 + i, " offset ", hscroll + 256 - size, " size ", size
  offset = hscroll + 256 - size
  vdpc = 30
  rem = size - vdpc
  print "start at ", offset + rem, " ends at ", offset + size
  # Emulate vdp command
  for j in xrange(i * 4):
    top = 103 - j
    bottom = 108 + j
    copy(last_large, top, 512, offset, 8, background_a, 0, 0)
    copy(last_large, bottom, 512, offset, 8, background_8, 0, 0)
    copy(last_large, top, 512, offset + rem, vdpc, raw, 256, 130 + rem)
    copy(last_large, bottom, 512, offset + rem, vdpc, raw, 256, 130 + rem)
  last_left, last_right = map_sc5(getlr(last_large))
  # Diffblit
  for j in xrange(i * 4 + 4):
    top = 103 - j
    bottom = 108 + j
    offset = hscroll + 256 - size
    copy(large, top, 512, offset, size, raw, 256, 130)
    copy(large, bottom, 512, offset, size, raw, 256, 130)
  top = 103 - i * 4 + 1
  bottom = 108
  commands.append("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + rem, 768 + top, 
                  offset + rem - 256, 768 + top, 
                  vdpc, i * 4))
  commands.append("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + rem, 768 + bottom, 
                  offset + rem - 256, 768 + bottom, 
                  vdpc, i * 4))
  start -= 4
  size += 4
  hscroll -= 4
  left, right = lr = map_sc5(getlr(large))
  last_lr = [last_left, last_right]
  extend_half_screen(
    0, 212 / 2, lr, last_lr, stream, stream_size)
  extend_half_screen(
    212 / 2, 212 / 2, lr, last_lr, stream, stream_size)
f = open("poster_slide3_diff.d5", "wb")
f.write("".join(chr(i) for i in stream))
f.close()
stream_size.extend([0, 0])
f = open("poster_slide3_size.bin", "wb")
f.write("".join(chr(i) for i in stream_size))
f.close()
f = open("poster_slide3_cmd.inc", "wt")
f.write("".join(commands))
f.close()

# State turtles_slide4
topstarty = 12
topchunks = [
  [70, 220, 10000],
  [70, 270, 10000],
  [70, 270, 10000],
  [70, 270, 10000],
  [70, 270, 10000],
  [70, 270, 10000],
]
stream = []
stream_size = []
commands = []
for i, topc in zip(xrange(18, 22), topchunks):
  last_large = large[:]
  print 1138 + i, " offset ", hscroll + 256 - size, " size ", size
  offset = hscroll + 256 - size
  vdpc = 46
  rem = size - vdpc
  print "start at ", offset + rem, " ends at ", offset + size
  # Emulate vdp command top
  for j in xrange(i * 4):
    top = 103 - j
    copy(last_large, top, 512, offset, 8, background_a, 0, 0)
    if j >= topstarty:
      copy(last_large, top, 512, offset + rem, vdpc, raw, 256, 130 + rem)
  # Emulate vdp command bottom
  for j in xrange(i * 4):
    bottom = 108 + j
    copy(last_large, bottom, 512, offset, 8, background_8, 0, 0)
    if j >= 16:
      copy(last_large, bottom, 512, offset + rem, vdpc, raw, 256, 130 + rem)
  last_left, last_right = map_sc5(getlr(last_large))
  # Diffblit
  for j in xrange(i * 4 + 4):
    top = 103 - j
    bottom = 108 + j
    offset = hscroll + 256 - size
    copy(large, top, 512, offset, size, raw, 256, 130)
    copy(large, bottom, 512, offset, size, raw, 256, 130)
  top = 103 - i * 4 + 1
  bottom = 108 + 16
  if offset + rem < 256:
    rem2 = 256 - offset
    vdpc2 = size - rem2
  # Top turtle
  commands.append("; start at %d ends at %d\n" % (offset + rem, offset + size))
  commands.append("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + rem, 768 + top, 
                  offset + rem, 512 + top, 
                  256 - offset - rem, i * 4 - topstarty))
  commands.append("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + rem + (256-offset-rem), 768 + top, 
                  0, 768 + top, 
                  vdpc2, i * 4 - topstarty))
  # Bottom turtle
  commands.append("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + rem, 768 + bottom, 
                  offset + rem, 512 + bottom, 
                  256 - offset - rem, i * 4 - 16))
  commands.append("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + rem + (256-offset-rem), 768 + bottom, 
                  0, 768 + bottom, 
                  vdpc2, i * 4 - 16))
  start -= 4
  size += 4
  hscroll -= 4
  left, right = lr = map_sc5(getlr(large))
  last_lr = [last_left, last_right]
  chunk_half_screen(
    0, 212 / 2, lr, last_lr, stream, stream_size, topc)
  chunk_half_screen(
    212 / 2, 212 / 2, lr, last_lr, stream, stream_size, [70, 220, 10000])
f = open("poster_slide4_diff.d5", "wb")
f.write("".join(chr(i) for i in stream))
f.close()
stream_size.extend([0, 0])
f = open("poster_slide4_size.bin", "wb")
f.write("".join(chr(i) for i in stream_size))
f.close()
f = open("poster_slide4_cmd.inc", "wt")
f.write("".join(commands))
f.close()
