100 CLEAR 1000
110 _MUSIC(1,0,1,1,1,1,1,1)
120 SOUND 6,0
130 SOUND 7,&B110001
140 DEFSTR A-Z
150 A0="v13@39o3l16t120"
160 B0="v15@6o5l16t120"
170 C0="v12@14o7l16t120"
180 D0="v10@10o6l16t120"
190 F0="v10@24o4l16t120"
200 P0="v5@a15t120y22,0y24,0"
210 X0="l64t120"
220 A1="c8>c<a8>c<g8>c<a8>c<c8>c<a8>c<g8>c<e8>c<"
230 A2="d8>d<b8>d<a8>d<b8>d<d8>d<b8>d<a8>d<g-8>d<
240 A3="f8>fd8fc8f<a8>f<g8>ge8gd8g<b8>g<"
250 A4="a->e-fa-8&a-<b->fgb-8&b-<"
260 B1="r1r8r16ga>c<ag"
270 B2="r1r8r16ab>d<ba"
280 B3=">r4r8r16cdfdcr4r8r16deged<"
290 B4="r16>e-fa-8&a-r16fgb-8&b-<"
300 C1="c<bb-ab-b>c<bb-ab-b>c<bb-ab-aa-aa-ga-g>"
310 C2="dd-c<b>cd-dd-c<b>cd-dd-c<b>c<bb-bb-ab-a>"
320 C3="fee-de-ef<f>f<f>f<f>gg-fefg-g<g>g<g>g<g>"
330 C4="a-<a->a-<a->a-<a->b-<b->b-<b->b-<b->"
340 D1="e8cf8e8&ecf8ce-ecfce&e4&e8"
350 D2="f+8dg8f+8&f+dg8dff+dgdf+&f+4&f+8"
360 D3="a-afb-fa&a4&a8b-bg>c<gb&b4&b8"
370 D4=">c4&c8d4&d8<"
380 E1="g8&ga8g4a8&ag-gcacg&g8ce8g"
390 E2="a8&ab8a4b8&ba-adbda&a8df+8a"
400 E3="b>c<f>d<f>c&c8<fa8>cd-d<g>e<g>d4<gb>d<"
410 E4=">e-8&e-<a->ce-f8&f<b->df<"
420 P1="m!b!h8h16h8h16h8h16h8m!b!h16 m!b!h16h16h16h8h16h8h16s!m!b!c!h16h16h16"
430 P3="m!b!h8h16h8h16h8h16s!m!b!c!h16h16m!b!h16":P3=P3+P3
440 P4="m!b!h8h16s!m!b!c!h16h16m!b!h16":P4=P4+P4
450 HH="v11cv8cv6cv5c"
460 CC="s0m4000c8"+HH
470 X1=HH+"r16"+HH:X1=X1+X1+X1+X1+HH+HH+HH+X1+X1+CC
480 X3=HH+"r16"+HH:X3=X3+X3+X3+CC:X3=X3+X3
490 X4=HH+"r16"+HH+CC:X4=X4+X4
500 PLAY#2,A0,B0,C0,D0,D0,F0,P0,X0
510 PLAY#2,A1,B1,C1,D1,E1,A1,P1,X1
520 PLAY#2,A2,B2,C2,D2,E2,A2,P1,X1
530 PLAY#2,A3,B3,C3,D3,E3,A3,P3,X3
540 PLAY#2,A4,B4,C4,D4,E4,A4,P4,X4
