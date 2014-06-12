# Find the v scroll values for the title bounce.

import cv2

frames = [1301, 1351]

def smallest(img):
  for j in xrange(220, 0, -1):
    for x in xrange(320):
      if sum(img[j, x]) == 0:
        return j
  return 0

for i in xrange(*frames):
  img = cv2.imread('frames/frame%04d.png' % i)
  print smallest(img)
    
