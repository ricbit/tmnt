BACK_BUILDING = back_building_attr.z5 back_building_patt.sc5 \
                back_building_size.bin back_building_patt_base.bin \
                back_building_palette.bin
          
TOP_BUILDING = top_building_patt.sc5 top_building_attr.sc5 \
               top_building_dyn_attr.bin

OBJECTS = attract.asm handles.inc city1.z5 city2a.z5 city2b.z5 city2c.z5 \
          cityline.z5 \
          $(BACK_BUILDING) back_building_patt.z5 \
          top_building_patt.z5 top_building_attr.z5 top_building_dyn_attr.bin

all : attract.com

attract.com : $(OBJECTS)
	./sjasmplus attract.asm --lst=attract.lst --sym=attract.sym
	cp attract.com disk
	cp attract.dat disk

handles.inc : tools/gen_handles.py
	python $^ > $@

%.z5 : %.sc5
	python tools/compress_graphics.py $^ $@

%.sc5 : raw/%.raw
	python tools/convert_raw.py $^ $@

city2a.sc5 city2b.sc5 city2c.sc5: raw/city2.raw tools/gen_city_raw.py
	python tools/gen_city_raw.py

gen_back_building_sprites : tools/gen_back_building_sprites.cc
	g++ -std=c++11 $^ -o $@ -O2 -Wall

$(BACK_BUILDING) : raw/city1.raw raw/city2.raw raw/cityline.raw \
                   gen_back_building_sprites
	./gen_back_building_sprites

$(TOP_BUILDING) : raw/city2.raw tools/gen_top_building_sprites.py
	python tools/gen_top_building_sprites.py
