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

echo -n "Interpolation (2/4/6/8): "
read MULTI
[ -z "$MULTI" ] && MULTI=2

echo -n "Crf (5-25) lower = higher quality (larger file size): "
read CRF
[ -z "$CRF" ] && CRF=18

MODEL="rife-v4.6"
DEST="/sdcard/rifevulkan/${NAME}_x${MULTI}.${EXT}"

FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$INPUT")
NUM=${FPS%/*}
DEN=${FPS#*/}
NEWFPS="$((NUM*MULTI))/$DEN"

CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$INPUT")
PIXFMT=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=nw=1:nk=1 "$INPUT")
PROFILE=$(ffprobe -v error -select_streams v:0 -show_entries stream=profile -of default=nw=1:nk=1 "$INPUT")

case "$CODEC" in
  hevc) VCODEC="libx265";;
  h264) VCODEC="libx264";;
  vp9)  VCODEC="libvpx-vp9";;
  av1)  VCODEC="libaom-av1";;
  *)    VCODEC="libx264";;
esac

PIX_OPT=""
[ -n "$PIXFMT" ] && PIX_OPT="-pix_fmt $PIXFMT"

PROF_OPT=""
if [[ "$VCODEC" == "libx264" && "$PROFILE" == "High" ]]; then
  PROF_OPT="-profile:v high"
elif [[ "$VCODEC" == "libx265" && "$PROFILE" == "Main 10" ]]; then
  PROF_OPT="-profile:v main10"
fi

echo "FPS: $FPS -> $NEWFPS"
echo "Codec: $CODEC -> $VCODEC"
echo "PixelFormat: $PIXFMT"
echo "Profile: $PROFILE"
echo "Output: $DEST"

rm -rf frames tmp out
mkdir -p frames tmp out

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

ffmpeg -framerate "$NEWFPS" -pattern_type glob -i "out/*.png" -c:v $VCODEC -crf $CRF -preset medium $PIX_OPT $PROF_OPT -r "$NEWFPS" -c:a copy "$DEST"

rm -f "$INPUT"
rm -rf frames tmp out

termux-media-scan "$DEST"
echo -e "\e[32mDone: $DEST\e[0m"
