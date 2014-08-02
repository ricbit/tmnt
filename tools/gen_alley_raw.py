# Convert city2 rgb to screen 5.

import convert_raw

raw1 = open("/home/ricbit/work/tmnt/raw/alley1.raw", "rb").read()
raw2 = open("/home/ricbit/work/tmnt/raw/alley2.raw", "rb").read()

convert_raw.save_sc5(raw1, "/home/ricbit/work/tmnt/alley1a.sc5", 0, 64)
convert_raw.save_sc5(raw1, "/home/ricbit/work/tmnt/alley1b.sc5", 64, 16)
convert_raw.save_sc5(raw2, "/home/ricbit/work/tmnt/alley2a.sc5", 0, 168)
convert_raw.save_sc5(raw2, "/home/ricbit/work/tmnt/alley2b.sc5", 168, 192)

