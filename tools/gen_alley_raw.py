# Convert city2 rgb to screen 5.

import convert_raw

raw = open("/home/ricbit/work/tmnt/raw/alley1.raw", "rb").read()

convert_raw.save_sc5(raw, "/home/ricbit/work/tmnt/alley1a.sc5", 0, 64)
convert_raw.save_sc5(raw, "/home/ricbit/work/tmnt/alley1b.sc5", 64, 16)

