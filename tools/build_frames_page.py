import re, itertools

screenheight = 30 + 41 + 192

f = open("log.txt", "rt")
lines = []
framelines = []
smart = None
current = 0
for line in f:
  m = re.match("Frame (\d+), lines=(\d+)", line)
  if m is not None:
    curlines = int(m.group(2))
    lines.append(curlines)
    framelines.append([0] * screenheight)
f.close()

def frame(i):
  out = []
  out.append('Frame %03d<br>' % (i + 518))
  out.append('<div style="width:20px;height:%dpx;background:red;float:left;">'%
             screenheight)
  for k, v in itertools.groupby(framelines[i]):
    V = list(v)
    out.append('<div style="width:10px; height:%dpx;background:#000"></div>' % 
               len(V))
  out.append('</div>')
  spacing = (30+41-24) if lines[i] == 192 else (10+41-14)
  out.append('<div><div style="height:%dpx;"></div>' % spacing)
  out.append('<img src="tmnt%03d.png"></div>' % (i + 1))
  out.append('<br style="clear: both;">\n')
  return ''.join(out)

f = open("frames.html", "wt")
f.write("<html><body>")
for i in xrange(500, 517+980, 50):
  f.write('<a href="msxframes/frame%04d.html">Frames %d-%d</a><br>' % 
          (i, i, i + 99))
  g = open("msxframes/frame%04d.html" % i, "wt")
  g.write("<html><body>")
  for j in xrange(i, i + 100):
    if j > 517 and j < 517 + 980:
      g.write(frame(j - 518))
  g.write("</body></html>")
  g.close()    
f.write("</body></html>")
f.close()


