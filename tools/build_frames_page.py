def frame(i):
  out = []
  out.append('Frame %03d<br><div>' % i)
  out.append('<img src="tmnt%03d.png">' % (i - 517))
  out.append('<span style="width:20px; height:200px;background:red; float:left;">ahha')
  out.append('</span><br style="clear: both;">\n')
  return ''.join(out)

f = open("frames.html", "wt")
f.write("<html><body>")
for i in xrange(500, 517+980, 50):
  f.write('<a href="msxframes/frame%04d.html">Frames %d-%d</a><br>' % 
          (i, i, i + 99))
  g = open("msxframes/frame%04d.html" % i, "wt")
  g.write("<html><body>")
  for j in xrange(i, i + 100):
    if j > 517 and j <= 517 + 980:
      g.write(frame(j))
  g.write("</body></html>")
  g.close()    
f.write("</body></html>")
f.close()


