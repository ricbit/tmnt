# Convert city2 rgb to screen 5.

import convert_raw

raw1 = open("raw/alley1.raw", "rb").read()
raw2 = open("raw/alley2.raw", "rb").read()

convert_raw.save_sc5(raw1, "alley1a.sc5", 0, 64)
convert_raw.save_sc5(raw1, "alley1b.sc5", 64, 16)
convert_raw.save_sc5(raw2, "alley2a.sc5", 0, 168)
convert_raw.save_sc5(raw2, "alley2b.sc5", 168, 88)
convert_raw.save_sc5(raw2, "alley2c.sc5", 256, 104)

