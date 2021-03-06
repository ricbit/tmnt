import re, itertools

screenheight = 30 + 41 + 192

colormap = {
  "smart_palette": "red",
  "smart_zblit": "blue",
  "smart_vdp_command": "green",
  "diffblit": "#5050ff",  
  "VIRQ": "#b0b0b0",
  "HIRQ": "#e0e0e0",
  "HMMV": "orange",
  "YMMM": "pink",
  "HMMM": "yellow",
  "LMMM": "magenta"
}

def convert(line, curlines):
  if curlines == 192:
    if line >= 192:
      return line - 192
    else:
      return line + 41 + 30
  else:
    if line >= 212:
      return line - 212
    else:
      return line + 41 + 10

f = open("log.txt", "rt")
lines = []
framelines = []
vdplines = []
irqlines = []
smart = None
vdp = None
irq = None
current = -1
for line in f:
  m = re.match("Frame (\d+), lines=(\d+)", line)
  if m is not None:
    if smart is not None:
      end = convert(curlines - 1, curlines)
      print framenumber,start,end
      framelines[current][start:end+1] = [colormap[smart]] * (end - start + 1)
    if vdp is not None:
      vdpend = convert(curlines - 1, curlines)
      print framenumber,vdpstart,vdpend
      vdplines[current][vdpstart:vdpend+1] = (
          [colormap[vdp]] * (vdpend - vdpstart + 1))
    framenumber = m.group(1)
    curlines = int(m.group(2))
    lines.append(curlines)
    framelines.append(["#000"] * screenheight)
    vdplines.append(["#000"] * screenheight)
    irqlines.append(["#000"] * screenheight)
    start = 0
    vdpstart = 0
    current += 1
    continue
  m = re.match("(\w+) (?:starting|queued) at (-?\d+)", line)
  if m is not None:
    smart = m.group(1)
    start = convert(int(m.group(2)), curlines)
    continue
  m = re.match("(\w+) ending at (-?\d+)", line)
  if m is not None:
    end = convert(int(m.group(2)), curlines)
    print framenumber,start,end
    framelines[current][start:end+1] = [colormap[smart]] * (end - start + 1)
    smart = None
    if m.group(1) == "smart_vdp_command":
      vdpstart = convert(int(m.group(2)), curlines)
    continue
  m = re.match("(\w+) stopping at (-?\d+)", line)
  if m is not None:
    vdpend = convert(int(m.group(2)), curlines)
    print framenumber,vdpstart,vdpend
    vdplines[current][vdpstart:vdpend+1] = (
        [colormap[vdp]] * (vdpend - vdpstart + 1))
    vdp = None
    continue
  m = re.match("(\wIRQ) at (-?\d+)", line)
  if m is not None:
    irq = m.group(1)
    irqstart = convert(int(m.group(2)), curlines)
    continue
  m = re.match("(\w+) cmd", line)
  if m is not None:
    vdp = m.group(1)
    print vdp
    continue
  m = re.match("IRQ return at (-?\d+)", line)
  if m is not None:
    irqend = convert(int(m.group(1)), curlines)
    print framenumber,irqstart,irqend
    irqlines[current][irqstart:irqend+1] = (
        [colormap[irq]] * (irqend - irqstart + 1))
    irq = None
    continue
     
f.close()
FIRST = 521

def frame(i):
  out = []
  out.append('Frame %03d<br>' % (i + FIRST))
  out.append('<div style="width:20px;height:%dpx;' % screenheight)
  out.append('background:black;float:left;">')
  for k, v in itertools.groupby(irqlines[i]):
    out.append('<div style="width:20px; height:%dpx;background:%s"></div>' % 
               (len(list(v)), k))
  out.append('</div>')
  out.append('<div style="width:20px;height:%dpx;' % screenheight)
  out.append('background:black;float:left;">')
  for k, v in itertools.groupby(framelines[i]):
    out.append('<div style="width:20px; height:%dpx;background:%s"></div>' % 
               (len(list(v)), k))
  out.append('</div>')
  out.append('<div style="width:20px;height:%dpx;' % screenheight)
  out.append('background:black;float:left;">')
  for k, v in itertools.groupby(vdplines[i]):
    out.append('<div style="width:20px; height:%dpx;background:%s"></div>' % 
               (len(list(v)), k))
  out.append('</div>')
  spacing = (30+41-24) if lines[i] == 192 else (10+41-14)
  out.append('<div><div style="height:%dpx;"></div>' % spacing)
  out.append('<img src="tmnt%03d.png"></div>' % (i + 1 + 3))
  out.append('<br style="clear: both;">\n')
  return ''.join(out)

def caption():
  out = []
  out.append('<div style="position:fixed; background:black; left:450px;')
  out.append('color:white;padding:20px;">')
  def tag(color, text):
    out.append('<div style="display:inline-block;width:20px; height:20px;')
    out.append('background: %s; margin: 5px;">&nbsp;' % color)
    out.append('</div> %s<br>' % text)
  tag(colormap['VIRQ'], 'VIRQ')
  tag(colormap['HIRQ'], 'HIRQ')
  tag(colormap['smart_palette'], 'Palette change')
  tag(colormap['smart_zblit'], 'Compressed blit')
  tag(colormap['diffblit'], 'Differential blit')
  tag(colormap['smart_vdp_command'], 'VDP command setup')
  tag(colormap['HMMM'], 'VDP command HMMM executing')
  tag(colormap['YMMM'], 'VDP command YMMM executing')
  tag(colormap['LMMM'], 'VDP command LMMM executing')
  tag(colormap['HMMV'], 'VDP command HMMV executing')
  out.append('</div>')
  return ''.join(out)

f = open("frames.html", "wt")
f.write("<html><body>")
for i in xrange(500, FIRST-1+980, 50):
  f.write('<a href="msxframes/frame%04d.html">Frames %d-%d</a><br>' % 
          (i, i, i + 99))
  g = open("msxframes/frame%04d.html" % i, "wt")
  g.write("<html><body>")
  g.write(caption())
  for j in xrange(i, i + 100):
    if j >= FIRST and j < FIRST - 1 + 980:
      g.write(frame(j - FIRST))
  g.write("</body></html>")
  g.close()    
f.write("</body></html>")
f.close()


