# Find the h scroll values for the title slide.

import cv2

frames = [1374, 1403]

def smallest(img):
  for x in xrange(320):
    if sum(img[83, x]) == 0:
      return x
  return 0

for i in xrange(*frames):
  img = cv2.imread('frames/frame%04d.png' % i)
  print smallest(img)
    
