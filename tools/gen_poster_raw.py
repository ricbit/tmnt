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
    self.stream_size.append(diff_size % 256)
    self.stream_size.append(diff_size >> 8)

  def chunk_half_screen(self, line_start, size, lr, last_lr, chunk):
    before = len(self.stream)
    new_stream = []
    for i in xrange(2):
      new_stream.extend(compress_diff(
        lr[i], last_lr[i], 0x10000 + 0x8000 * i, 
        line_start, size, close_stream=False))
    packs = split_diff(new_stream, chunk)
    print [len(i) for i in packs]
    for p in packs:
      self.stream.extend(p)
      self.stream.append(0)
      diff_size = len(self.stream) - before
      self.stream_size.append(diff_size % 256)
      self.stream_size.append(diff_size >> 8)
      before = len(self.stream)

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

# Save initial state of vram.
left, right = large.getlr()
left_sc5, right_sc5 = large.getlr_sc5()
zero_sc5 = [0] * (128 * 212)
save_sc5("".join(chr(i) for i in left), "poster_left.sc5", 0, 212)
save_diff(right_sc5, zero_sc5, 0x18000, 0, 212, "poster_right.d5")

class State(object):
  pass

class Commands(object):
  def __init__(self):
    self.commands = []
  def add(self, cmd):
    self.commands.append(cmd)
  def save(self, name):
    f = open(name, "wt")
    f.write("".join(self.commands))
    f.close()

class StateEngine(object):
  def __init__(self, large):
    self.start = 256 - 20
    self.size = 20
    self.hscroll = 100
    self.large = large
    self.processors = []
  def run(self, irange, stream, commands=Commands(), vdpc=30):
    state = State()
    state.topstarty = 12
    state.bottomstarty = 34
    for i in irange:
      # Set up internal state.
      state.i = i
      state.large = large
      state.size = self.size
      state.commands = commands
      state.stream = stream
      state.last_large = self.large.clone()
      print (1138 + i, " offset ", self.hscroll + 256 - self.size, 
             " size ", self.size)
      # Call state processors.
      state.top = 104 - i * 4
      state.bottom = 108
      state.offset = self.hscroll + 256 - self.size
      state.vdpc = vdpc
      state.rem = self.size - state.vdpc
      state.bottomrem = self.size - state.vdpc
      state.vdpc2 = self.size - 256 + state.offset
      state.bottomvdpc2 = self.size - 256 + state.offset
      for p in self.processors:
        p(state)
      # Update state.
      self.start -= 4
      self.size += 4
      self.hscroll -= 4

def small_hmmv(state):
  state.last_large.copy_block(
      state.top, state.offset, background_a, 0, 0, state.i * 4, 8)
  state.last_large.copy_block(
      state.bottom, state.offset, background_8, 0, 0, state.i * 4, 8)

def state_diffblit(state):
  state.large.copy_block(
      state.top - 4, state.offset, raw, 
      state.top - 4, 130, state.i * 4 + 4, state.size)
  state.large.copy_block(
      state.bottom, state.offset, raw, 
      state.bottom, 130, state.i * 4 + 4, state.size)

def extend_stream(state):
  state.stream.extend_half_screen(
      0, 212 / 2, state.large, state.last_large)
  state.stream.extend_half_screen(
      212 / 2, 212 / 2, state.large, state.last_large)

# States turtles_slide1 and turtles_slide2
engine = StateEngine(large)
stream = Stream()
engine.processors = [small_hmmv, state_diffblit, extend_stream]
engine.run(range(0, 14), stream)
stream.save("poster_slide_diff.d5", "poster_slide_size.bin")

def slide3_vram_move(state):
  state.last_large.copy_block(
      state.top, state.offset + state.rem, raw, 
      state.top, 130 + state.rem, state.i * 4, state.vdpc)
  state.last_large.copy_block(
      state.bottom, state.offset + state.rem, raw, 
      state.bottom, 130 + state.rem, state.i * 4, state.vdpc)

def slide3_vdp_cmd(state):
  state.commands.add("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
               (130 + state.rem, 768 + state.top, 
               state.offset + state.rem - 256, 768 + state.top, 
               state.vdpc, state.i * 4))
  state.commands.add("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
               (130 + state.rem, 768 + state.bottom, 
               state.offset + state.rem - 256, 768 + state.bottom, 
               state.vdpc, state.i * 4))

def slide4_vdp_cmd(state):
  # Top turtle
  state.commands.add("; start at %d ends at %d\n" % 
                  (state.offset + state.rem, state.offset + state.size))
  state.commands.add("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + state.rem, 768 + state.top, 
                  state.offset + state.rem, 512 + state.top, 
                  256 - state.offset - state.rem, 
                  state.i * 4 - state.topstarty))
  state.commands.add("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + (256 - state.offset), 
                  768 + state.top, 0, 768 + state.top, 
                  state.vdpc2, state.i * 4 - state.topstarty))
  # Bottom turtle
  state.commands.add("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + state.bottomrem, 
                  768 + state.bottom + state.bottomstarty, 
                  state.offset + state.bottomrem, 
                  512 + state.bottom + state.bottomstarty, 
                  256 - state.offset - state.bottomrem, 
                  state.i * 4 - state.bottomstarty))
  state.commands.add("\tVDP_HMMM %d, %d, %d, %d, %d, %d\n" %
                  (130 + (256 - state.offset), 
                  768 + state.bottom + state.bottomstarty, 
                  0, 768 + state.bottom + state.bottomstarty, 
                  state.bottomvdpc2, state.i * 4 - state.bottomstarty))

# State turtles_slide3
stream = Stream()
commands = Commands()
engine.processors = [small_hmmv, state_diffblit, slide3_vram_move, slide3_vdp_cmd, extend_stream]
engine.run(range(14, 18), stream, commands)
stream.save("poster_slide3_diff.d5", "poster_slide3_size.bin")
commands.save("poster_slide3_cmd.inc")

large = engine.large.contents[:]
start = engine.start
size = engine.size
hscroll = engine.hscroll

# State turtles_slide4
stream = Stream()
commands = Commands()
engine.processors = [small_hmmv, slide4_vdp_cmd]
engine.run(range(18, 20), stream, commands, vdpc=52)
commands.save("poster_slide4_cmd.inc")

raw = raw.contents[:]
background_a = background_a.contents
background_8 = background_8.contents

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
stream = Stream()
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
  start -= 4
  size += 4
  hscroll -= 4
  left, right = lr = map_sc5(getlr(large))
  last_lr = [last_left, last_right]
  stream.chunk_half_screen(
    0, 212 / 2, lr, last_lr, topc)
  stream.chunk_half_screen(
    212 / 2, 212 / 2, lr, last_lr, bottomc)
stream.save("poster_slide4_diff.d5", "poster_slide4_size.bin")

# State turtles_slide5
stream = Stream()
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
  stream.chunk_half_screen(
    0, 212 / 2, lr, last_lr, topc)
  stream.chunk_half_screen(
    212 / 2, 212 / 2, lr, last_lr, bottomc)
stream.save("poster_slide5_diff.d5", "poster_slide5_size.bin")
f = open("poster_slide5_cmd.inc", "wt")
f.write("".join(commands))
f.close()
f = open("poster_slide5_pre.inc", "wt")
f.write("".join(precommands))
f.close()
