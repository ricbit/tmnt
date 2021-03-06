BACK_BUILDING = back_building_attr.z5 back_building_patt.sc5 \
                back_building_size.bin back_building_patt_base.bin \
                back_building_palette.bin
          
TOP_BUILDING = top_building_patt.sc5 top_building_attr.sc5 \
               top_building_dyn_attr.bin

CITY_PIXELS = city2a.sc5 city2b.sc5 city2c.sc5 city2d.sc5 city2e.sc5 \
              city2f.sc5 city2g.sc5

ALLEY_PIXELS = alley1a.sc5 alley1b.sc5 alley2a.sc5 alley2b.sc5 alley2c.sc5

MOON_SPRITES = moon_pattern.sc5 moon_attr.sc5

POSTER_PIXELS = poster_left.sc5 poster_right.d5 \
                poster_slide_diff.d5 poster_slide_size.bin \
                poster_slide3_diff.d5 poster_slide3_size.bin \
                poster_slide4_diff.d5 poster_slide4_size.bin \
                poster_slide5_diff.d5 poster_slide5_size.bin \
                poster_slide3_cmd.inc poster_slide4_cmd.inc \
                poster_slide5_cmd.inc poster_slide5_pre.inc

OBJECTS = attract.asm handles.inc city1.z5 $(CITY_PIXELS:%.sc5=%.z5) \
          cityline.z5 tmnt.z5 cloud2.z5 cloud3.z5 alleyline.z5 \
          $(BACK_BUILDING:%.sc5=%.z5) $(ALLEY_PIXELS:%.sc5=%.z5) \
          $(TOP_BUILDING:%.sc5=%.z5) $(MOON_SPRITES:%.sc5=%.z5) \
          $(POSTER_PIXELS:%.sc5=%.z5) \
          absolute_scroll.bin advance_pcm.bin cloud_fade_palette.bin \
          city_fade_palette.bin title_bounce_palette.bin bottom_palette.bin \
          alley_palette.bin manhole.z5 top_palette.bin info_music.fm \
          title_bounce_scroll.bin title_slide_scroll.bin raw/theme.pcm

all : attract.com

clean :
	rm -f *sc5 *z5 *bin *inc *d5 gen_back_building_sprites \
           attract.com attract.dat attract.lst attract.sym \
           info_music.fm frames.html msxframes/*

run : attract.com
	./openmsx -machine Panasonic_FS-A1GT -diska disk

save : tmntmsx.avi

vlc : tmntmsx.avi
	vlc tmntmsx.avi

log.txt tmntmsx.avi : attract.com tmnt.tcl 
	./openmsx -machine Panasonic_FS-A1GT -diska disk -script tmnt.tcl \
        -ext debugdevice > log.txt 2>&1

frames.html : tmntmsx.avi log.txt tools/build_frames_page.py
	mkdir -p msxframes
	ffmpeg -i tmntmsx.avi -r 60 msxframes/tmnt%03d.png
	python tools/build_frames_page.py

attract.com : $(OBJECTS)
	./sjasmplus attract.asm --lst=attract.lst --sym=attract.sym
	mkdir -p disk
	cp attract.com disk
	cp attract.dat disk

handles.inc : tools/gen_handles.py
	python $^ > $@

%.z5 : %.sc5 tools/compress_graphics.py
	python tools/compress_graphics.py $< $@

%.sc5 : raw/%.raw tools/convert_raw.py
	python tools/convert_raw.py $< $@

%_fade_palette.bin : raw/%.act
	python tools/gen_cloud_fade.py $< $@

%_palette.bin : raw/%.act
	python tools/convert_act.py $< $@

$(CITY_PIXELS) : city_pixels.i
.INTERMEDIATE : city_pixels.i
city_pixels.i: raw/city2.raw tools/gen_city_raw.py
	python tools/gen_city_raw.py

gen_back_building_sprites : tools/gen_back_building_sprites.cc
	g++ -std=c++14 $^ -o $@ -O2 -Wall

$(BACK_BUILDING) : back_building.i
.INTERMEDIATE : back_building.i
back_building.i: raw/city1.raw raw/city2.raw raw/cityline.raw \
                 gen_back_building_sprites
	./gen_back_building_sprites

$(TOP_BUILDING) : top_building.i
.INTERMEDIATE : top_building.i
top_building.i : raw/city2.raw tools/gen_top_building_sprites.py
	python tools/gen_top_building_sprites.py

$(ALLEY_PIXELS) : alley_pixels.i
.INTERMEDIATE : alley_pixels.i
alley_pixels.i : raw/alley1.raw raw/alley2.raw tools/gen_alley_raw.py
	python tools/gen_alley_raw.py

$(MOON_SPRITES) : moon_sprites.i
.INTERMEDIATE : moon_sprites.i
moon_sprites.i : raw/moon.raw raw/cloud2.raw
	python tools/gen_moon_sprites.py

absolute_scroll.bin :
	python tools/gen_absolute_scroll.py

advance_pcm.bin :
	python tools/gen_advance_pcm.py

title_bounce_scroll.bin : raw/title_bounce_scroll.txt
	python tools/gen_title_bounce.py < $<

title_slide_scroll.bin : raw/title_slide_scroll.txt
	python tools/gen_title_slide.py < $<

$(POSTER_PIXELS) : poster_pixels.i
.INTERMEDIATE : poster_pixels.i
poster_pixels.i : raw/turtles.raw tools/gen_poster_raw.py \
                  tools/compress_graphics.py
	python tools/gen_poster_raw.py

info_music.fm: raw/info.bas tools/grabfm.tcl
	mkdir -p music
	cp raw/info.bas music/autoexec.bas
	./openmsx -machine Panasonic_FS-A1GT -diska music \
            -script tools/grabfm.tcl

