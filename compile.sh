python tools/gen_handles.py > handles.inc
./sjasmplus attract.asm --lst=attract.lst --sym=attract.sym
cp attract.com disk
cp attract.dat disk
