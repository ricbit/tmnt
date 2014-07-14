# Generate a raw image with all colors of the palette.

image = []
for i in xrange(16):
  image.extend([i] * (256 / 16))
image = image * 16
f = open("palette_sweep.raw", "wb")
f.write("".join(chr(i) for i in image))
f.close()
