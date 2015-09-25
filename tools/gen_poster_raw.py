# Convert poster rgb to screen 5.

from convert_raw import convert_sc5, save_sc5
from compress_graphics import compress_diff, save_diff, split_diff

class Bitmap(object):
  def __init__(self, width, height, contents = None):
    self.width = width
    self.height = height
    if contents is not None:
      self.contents = contents
      assert(width * height == len(contents))
    else:
      self.contents = [0] * (width * height)

  def copy_line(self, y, x, source, x2, size):
    self.contents[y * self.width + x: y * self.width + x + size] = (
      source.contents[y * source.width + x2: y * source.width + x2 + size])

  def copy_block(self, y, x, source, y2, x2, ysize, xsize):
    for i in xrange(ysize):
      self.contents[(y + i) * self.width + x: 
                    (y + i) * self.width + x + xsize] = (
        source.contents[(y2 + i) * source.width + x2: 
                        (y2 + i) * source.width + x2 + xsize])
      
  def getlr(self):
    left = Bitmap(256, 212)
    left.copy_block(0, 0, self, 0, 0, 212, 256)
    right = Bitmap(256, 212)
    right.copy_block(0, 0, self, 0, 256, 212, 256)
    return left.contents, right.contents

  def getlr_sc5(self):
    return map(lambda x: convert_sc5(x, 0, 212), self.getlr())

  def clone(self):
    return Bitmap(self.width, self.height, self.contents[:])

class Stream(object):
  def __init__(self):
    self.stream = []
    self.stream_size = []

  def extend_half_screen(self, line_start, size, vram_after, vram_before):
    before = len(self.stream)
    lr = vram_after.getlr_sc5()
    last_lr = vram_before.getlr_sc5()
    for i in xrange(2):
      self.stream.extend(compress_diff(
        lr[i], last_lr[i], 0x10000 + 0x8000 * i, 
        line_start, size, close_stream=False))
    self.stream.append(0)
    diff_size = len(self.stream) - before
    print diff_size
    self.stream_size.append(diff_size % 256)
    self.stream_size.append(diff_size >> 8)

  def save(self, diff_name, size_name):
    f = open(diff_name, "wb")
    f.write("".join(chr(i) for i in self.stream))
    f.close()
    self.stream_size.extend([0, 0])
    f = open(size_name, "wb")
    f.write("".join(chr(i) for i in self.stream_size))
    f.close()


def copy(last_large, top, stride, offset, size, raw, stride2, offset2):
  last_large[top * stride + offset: top * stride + offset + size] = (
    raw[top * stride2 + offset2: top * stride2 + offset2 + size])

# Draw initial state of vram.
raw = Bitmap(256, 212, map(ord, open("raw/turtles.raw", "rb").read()))
background_a = Bitmap(256, 212, [0xa] * 256 * 212)
background_8 = Bitmap(256, 212, [0x8] * 256 * 212)
large = Bitmap(512, 212)
large.copy_block(0, 0, raw, 0, 0, 212, 128)
for i in xrange(26):
  top = 100 - i * 4
  bottom = 108 + i * 4
  size = 20 + i * 4
  hscroll = 100 - i * 4
  offset = hscroll + 256 - size
  large.copy_block(top, offset, raw, top, 130, 4, size)
  large.copy_block(bottom, offset, raw, bottom, 130, 4, size)
large.copy_block(0, 256 + 128, raw, 0, 128, 192, 128)

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
  stream.extend(compress_diff(
    lr[0], last_lr[0], 0x10000, line_start, size, close_stream=False))
  stream.extend(compress_diff(
    lr[1], last_lr[1], 0x18000, line_start, size, close_stream=False))
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

# Save initial state of vram.
left, right = large.getlr()
left_sc5, right_sc5 = large.getlr_sc5()
zero_sc5 = [0] * (128 * 212)
save_sc5("".join(chr(i) for i in left), "poster_left.sc5", 0, 212)
save_diff(right_sc5, zero_sc5, 0x18000, 0, 212, "poster_right.d5")

# States turtles_slide1 and turtles_slide2
class StateEngine(object):
  def __init__(self, large):
    self.start = 256 - 20
    self.size = 20
    self.hscroll = 100
    self.large = large
  def run(self, irange, stream):
    for i in irange:
      last_large = self.large.clone()
      print (1138 + i, " offset ", self.hscroll + 256 - self.size, 
             " size ", self.size)
      # Emulate vdp command
      top = 104 - i * 4
      bottom = 108
      offset = self.hscroll + 256 - self.size
      last_large.copy_block(top, offset, background_a, 0, 0, i * 4, 8)
      last_large.copy_block(bottom, offset, background_8, 0, 0, i * 4, 8)
      # Diffblit
      top = 100 - i * 4
      bottom = 108
      offset = self.hscroll + 256 - self.size
      self.large.copy_block(
          top, offset, raw, top, 130, i * 4 + 4, self.size)
      self.large.copy_block(
          bottom, offset, raw, bottom, 130, i * 4 + 4, self.size)
      self.start -= 4
      self.size += 4
      self.hscroll -= 4
      stream.extend_half_screen(0, 212 / 2, large, last_large)
      stream.extend_half_screen(212 / 2, 212 / 2, large, last_large)

engine = StateEngine(large)
stream = Stream()
engine.run(range(0, 14), stream)
stream.save("poster_slide_diff.d5", "poster_slide_size.bin")

# State turtles_slide3
large = engine.large.contents
raw = raw.contents
background_a = background_a.contents
background_8 = background_8.contents
start = engine.start
size = engine.size
hscroll = engine.hscroll

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
bottomstarty = 34
topchunks = [
  [70, 240, 10000],
  [70, 320, 10000],
  [80, 360, 10000],
  [80, 470, 10000],
  [70, 350, 10000],
  [70, 320, 10000],
]
bottomchunks = [
  [70, 200, 10000],
  [60, 200, 10000],
  [60, 320, 10000],
  [70, 250, 10000],
  [70, 350, 10000],
  [70, 320, 10000],
]
stream = []
stream_size = []
commands = []
for i, topc, bottomc in zip(xrange(18, 20), topchunks, bottomchunks):
  last_large = large[:]
  print 1138 + i, " offset ", hscroll + 256 - size, " size ", size
  offset = hscroll + 256 - size
  vdpc = 52
  rem = size - vdpc
  bottomvdpc = 52
  bottomrem = size - bottomvdpc
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
    if j >= bottomstarty:
      copy(last_large, bottom, 512, offset + bottomrem, bottomvdpc, 
           raw, 256, 130 + bottomrem)
  last_left, last_right = map_sc5(getlr(last_large))
  # Diffblit
  for j in xrange(i * 4 + 4):
    top = 103 - j
    bottom = 108 + j
    offset = hscroll + 256 - size
    copy(large, top, 512, offset, size, raw, 256, 130)
    copy(large, bottom, 512, offset, size, raw, 256, 130)
  top = 103 - i * 4 + 1
  bottom = 108 + bottomstarty
  if offset + rem < 256:
    rem2 = 256 - offset
    vdpc2 = size - rem2
  if offset + bottomrem < 256:
    bottomrem2 = 256 - offset
    bottomvdpc2 = size - bottomrem2
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
                  (130 + bottomrem, 768 + bottom, 
                  offset + bottomrem, 512 + bottom, 
                  256 - offset - bottomrem, i * 4 - bottomstarty))
  commands.append("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + bottomrem + (256-offset-bottomrem), 768 + bottom, 
                  0, 768 + bottom, 
                  bottomvdpc2, i * 4 - bottomstarty))
  start -= 4
  size += 4
  hscroll -= 4
  left, right = lr = map_sc5(getlr(large))
  last_lr = [last_left, last_right]
  chunk_half_screen(
    0, 212 / 2, lr, last_lr, stream, stream_size, topc)
  chunk_half_screen(
    212 / 2, 212 / 2, lr, last_lr, stream, stream_size, bottomc)
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

# State turtles_slide5
stream = []
stream_size = []
commands = []
precommands = []
topchunks = topchunks[2:]
bottomchunks = bottomchunks[2:]
page0addr = 0
for i, topc, bottomc in zip(xrange(20, 23), topchunks, bottomchunks):
  last_large = large[:]
  print 1138 + i, " offset ", hscroll + 256 - size, " size ", size
  offset = hscroll + 256 - size
  vdpc = 54
  rem = size - vdpc
  bottomvdpc = 56 # 52
  bottomrem = size - bottomvdpc
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
    if j >= bottomstarty:
      copy(last_large, bottom, 512, offset + bottomrem, bottomvdpc, 
           raw, 256, 130 + bottomrem)
  last_left, last_right = map_sc5(getlr(last_large))
  # Diffblit
  for j in xrange(i * 4 + 4):
    top = 103 - j
    bottom = 108 + j
    offset = hscroll + 256 - size
    copy(large, top, 512, offset, size, raw, 256, 130)
    copy(large, bottom, 512, offset, size, raw, 256, 130)
  top = 103 - i * 4 + 1
  bottom = 108 + bottomstarty
  if offset + rem < 256:
    rem2 = 256 - offset
    vdpc2 = size - rem2
  if offset + bottomrem < 256:
    bottomrem2 = 256 - offset
    bottomvdpc2 = size - bottomrem2
  # Top turtle
  precommands.append("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                     (130 + rem, 768 + top, 
                     offset + rem, page0addr, 
                     256 - offset - rem, i * 4 - topstarty))
  commands.append("; start at %d ends at %d\n" % (offset + rem, offset + size))
  commands.append("\tVDP_YMMM %d, %d, %d, %d\n" %
                  (page0addr, offset + rem, 512 + top, i * 4 - topstarty))
  commands.append("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + rem + (256-offset-rem), 768 + top, 
                  0, 768 + top, 
                  vdpc2, i * 4 - topstarty))
  page0addr += i * 4 - topstarty
  # Bottom turtle
  commands.append("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + bottomrem, 768 + bottom, 
                  offset + bottomrem, 512 + bottom, 
                  256 - offset - bottomrem, i * 4 - bottomstarty))
  commands.append("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + bottomrem + (256-offset-bottomrem), 768 + bottom, 
                  0, 768 + bottom, 
                  bottomvdpc2, i * 4 - bottomstarty))
  start -= 4
  size += 4
  hscroll -= 4
  left, right = lr = map_sc5(getlr(large))
  last_lr = [last_left, last_right]
  chunk_half_screen(
    0, 212 / 2, lr, last_lr, stream, stream_size, topc)
  chunk_half_screen(
    212 / 2, 212 / 2, lr, last_lr, stream, stream_size, bottomc)
f = open("poster_slide5_diff.d5", "wb")
f.write("".join(chr(i) for i in stream))
f.close()
stream_size.extend([0, 0])
f = open("poster_slide5_size.bin", "wb")
f.write("".join(chr(i) for i in stream_size))
f.close()
f = open("poster_slide5_cmd.inc", "wt")
f.write("".join(commands))
f.close()
f = open("poster_slide5_pre.inc", "wt")
f.write("".join(precommands))
f.close()
