#!/bin/bash

STX=$(printf '\x02')
ETX=$(printf '\x03')
ESC=$(printf '\x1b')

convert \
  -size 200x100 xc:white \
  -font Courier \
  -pointsize 50 \
  -gravity center \
  -draw "text 0,0 'Hello'" \
  output.bmp
size=$(printf "%05d" $(wc -c < output.bmp))

printf "%b" \
 "$STX" \
 "${ESC}A" \
 "${ESC}A104000680" \
 "${ESC}IG0" \
 "${ESC}H0080" \
 "${ESC}V0080" \
 "${ESC}BG02080018"

echo -n "${ESC}GM${size},"
cat output.bmp

printf "%b" \
 "${ESC}Q000001" \
 "${ESC}Z" \
 "$ETX"
