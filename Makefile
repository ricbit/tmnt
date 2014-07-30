BACK_BUILDING = back_building_attr.z5 back_building_patt.sc5 \
                back_building_size.bin back_building_patt_base.bin \
                back_building_palette.bin
          
TOP_BUILDING = top_building_patt.sc5 top_building_attr.sc5 \
               top_building_dyn_attr.bin

CITY_PIXELS = city2a.sc5 city2b.sc5 city2c.sc5 city2d.sc5 city2e.sc5 \
              city2f.sc5 city2g.sc5

MOON_SPRITES = moon_pattern.sc5 moon_attr.sc5

OBJECTS = attract.asm handles.inc city1.z5 $(CITY_PIXELS:%.sc5=%.z5) \
          cityline.z5 alley1a.z5 alley1b.z5 cloud2.z5 cloud3.z5 \
          $(BACK_BUILDING) back_building_patt.z5 tmnt.z5 \
          $(TOP_BUILDING:%.sc5=%.z5) $(MOON_SPRITES:%.sc5=%.z5)

all : attract.com

clean :
	rm *sc5 *z5 attract.com attract.dat attract.lst attract.sym handles.inc

attract.com : $(OBJECTS)
	./sjasmplus attract.asm --lst=attract.lst --sym=attract.sym
	cp attract.com disk
	cp attract.dat disk

handles.inc : tools/gen_handles.py
	python $^ > $@

%.z5 : %.sc5 tools/compress_graphics.py
	python tools/compress_graphics.py $< $@

%.sc5 : raw/%.raw
	python tools/convert_raw.py $^ $@

$(CITY_PIXELS): raw/city2.raw tools/gen_city_raw.py
	python tools/gen_city_raw.py

gen_back_building_sprites : tools/gen_back_building_sprites.cc
	g++ -std=c++11 $^ -o $@ -O2 -Wall

$(BACK_BUILDING) : raw/city1.raw raw/city2.raw raw/cityline.raw \
                   gen_back_building_sprites
	./gen_back_building_sprites

$(TOP_BUILDING) : raw/city2.raw tools/gen_top_building_sprites.py
	python tools/gen_top_building_sprites.py

alley1a.sc5 alley1b.sc5 : raw/alley1.raw
	python tools/gen_alley1_raw.py

$(MOON_SPRITES) : raw/moon.raw raw/cloud2.raw
	python tools/gen_moon_sprites.py
