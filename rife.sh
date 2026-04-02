#!/bin/bash
export LD_LIBRARY_PATH=/system/lib64:$LD_LIBRARY_PATH

echo "Pick video from system..."
TMPFILE="__input.tmp"
rm -f "$TMPFILE"
termux-storage-get "$TMPFILE" &

while [ ! -f "$TMPFILE" ]; do sleep 1; done
sleep 1

echo -n "Enter name (no extension): "
read NAME
EXT=$(file --mime-type -b "$TMPFILE" | cut -d'/' -f2)
case "$EXT" in
  mp4) EXT="mp4";;
  quicktime) EXT="mov";;
  x-matroska) EXT="mkv";;
  *) EXT="mp4";;
esac
INPUT="${NAME}.${EXT}"
mv "$TMPFILE" "$INPUT"
echo "Selected: $INPUT"

echo "Models:"
MODELS=(); i=0
for d in */ ; do
  [ -f "$d/flownet.param" ] && echo "[$i] $d" && MODELS+=("$d") && ((i++))
done
[ ${#MODELS[@]} -eq 0 ] && echo "No models found" && exit 1
echo -n "Select model: "; read MID; MODEL="${MODELS[$MID]}"

echo -n "Interpolation (2/4/6/8): "; read MULTI; [ -z "$MULTI" ] && MULTI=2
DEST="/sdcard/rifevulkan/${NAME}_x${MULTI}.mov"
FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT")
NUM=${FPS%/*}; DEN=${FPS#*/}; NEWFPS="$((NUM*MULTI))/$DEN"
echo "FPS: $FPS -> $NEWFPS"; echo "Output: $DEST"

rm -rf frames tmp out; mkdir -p frames tmp out
echo "Extracting frames..."
ffmpeg -i "$INPUT" -vsync 0 frames/%08d.png
cp -r frames/* tmp/

STEP=1
while [ $STEP -lt $MULTI ]; do
  echo "Interpolating x2..."
  rm -rf out; mkdir out
  ./rife-ncnn-vulkan -i tmp -o out -m "$MODEL"
  rm -rf tmp; mkdir tmp; cp -r out/* tmp/
  STEP=$((STEP*2))
done

mv tmp out
echo "Encoding..."
mkdir -p /sdcard/rifevulkan
ffmpeg -framerate "$NEWFPS" -pattern_type glob -i "out/*.png" -c:v prores_ks -profile:v 3 -pix_fmt yuv422p10le -r "$NEWFPS" "$DEST"

rm -f "$INPUT"
rm -rf frames tmp out

termux-media-scan "$DEST"
echo -e "\e[31mDone! Output file: $DEST\e[0m"
