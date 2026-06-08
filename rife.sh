#!/bin/bash
export LD_LIBRARY_PATH=/system/lib64:$LD_LIBRARY_PATH

cleanup() {
  rm -f "$TMPFILE" "$INPUT" __tmpvid.*
  rm -rf frames tmp out
}
trap cleanup EXIT
trap 'exit 1' INT TERM

echo "Pick video from system... (Ctrl+C to cancel)"
TMPFILE="__input.tmp"
rm -f "$TMPFILE"
termux-storage-get "$TMPFILE" &

while [ ! -f "$TMPFILE" ]; do sleep 1; done
sleep 1

EXT_RAW=$(file --mime-type -b "$TMPFILE" | cut -d'/' -f2)
case "$EXT_RAW" in
  mp4|mpeg4)      EXT="mp4";;
  quicktime)      EXT="mov";;
  x-matroska)     EXT="mkv";;
  x-msvideo)      EXT="avi";;
  x-ms-wmv)       EXT="wmv";;
  webm)           EXT="webm";;
  ogg)            EXT="ogv";;
  x-flv)          EXT="flv";;
  3gpp)           EXT="3gp";;
  x-m4v)          EXT="m4v";;
  x-ms-asf)       EXT="asf";;
  *)              EXT="mp4";;
esac

while true; do
  echo -n "Enter name (no extension): "
  read NAME
  if [ -f "${NAME}.${EXT}" ] || [ -f "/sdcard/rifevulkan/${NAME}_x"*".${EXT}" ] 2>/dev/null; then
    echo -e "\e[33mWarning: '${NAME}' already exists, enter a different name\e[0m"
  else
    break
  fi
done

INPUT="${NAME}.${EXT}"
mv "$TMPFILE" "$INPUT"

echo -n "Interpolation (multi 2/4/6/8): "
read MULTI
[ -z "$MULTI" ] && MULTI=2

CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$INPUT")
PIXFMT=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=nw=1:nk=1 "$INPUT")
PROFILE=$(ffprobe -v error -select_streams v:0 -show_entries stream=profile -of default=nw=1:nk=1 "$INPUT")
HAS_AUDIO=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$INPUT")
FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$INPUT")
NUM=${FPS%/*}; DEN=${FPS#*/}
NEWFPS="$((NUM * MULTI))/$DEN"

case "$CODEC" in
  h264)         VCODEC="libx264";    USE_CRF=1;;
  hevc)         VCODEC="libx265";    USE_CRF=1;;
  vp9)          VCODEC="libvpx-vp9"; USE_CRF=1;;
  vp8)          VCODEC="libvpx";     USE_CRF=1;;
  av1)          VCODEC="libaom-av1"; USE_CRF=1;;
  rawvideo)     VCODEC="huffyuv";    USE_CRF=0;;
  huffyuv)      VCODEC="huffyuv";    USE_CRF=0;;
  ffv1)         VCODEC="ffv1";       USE_CRF=0;;
  utvideo)      VCODEC="utvideo";    USE_CRF=0;;
  prores)       VCODEC="prores_ks";  USE_CRF=0;;
  dnxhd)        VCODEC="dnxhd";      USE_CRF=0;;
  mpeg4)        VCODEC="mpeg4";      USE_CRF=0;;
  mpeg2video)   VCODEC="mpeg2video"; USE_CRF=0;;
  mpeg1video)   VCODEC="mpeg1video"; USE_CRF=0;;
  mjpeg)        VCODEC="mjpeg";      USE_CRF=0;;
  wmv1)         VCODEC="wmv1";       USE_CRF=0;;
  wmv2)         VCODEC="wmv2";       USE_CRF=0;;
  theora)       VCODEC="libtheora";  USE_CRF=0;;
  flv1)         VCODEC="flv";        USE_CRF=0;;
  h263)         VCODEC="h263";       USE_CRF=0;;
  h263p)        VCODEC="h263p";      USE_CRF=0;;
  msmpeg4v2)    VCODEC="msmpeg4v2";  USE_CRF=0;;
  msmpeg4v3)    VCODEC="msmpeg4";    USE_CRF=0;;
  cinepak)      VCODEC="cinepak";    USE_CRF=0;;
  rv30|rv40)    VCODEC="libx264";    USE_CRF=1; echo -e "\e[33mWarning: RealVideo encoder not available, falling back to libx264\e[0m";;
  svq3)         VCODEC="libx264";    USE_CRF=1; echo -e "\e[33mWarning: SVQ3 encoder not available, falling back to libx264\e[0m";;
  indeo3)       VCODEC="libx264";    USE_CRF=1; echo -e "\e[33mWarning: Indeo3 encoder not available, falling back to libx264\e[0m";;
  *)            VCODEC="libx264";    USE_CRF=1; echo -e "\e[33mWarning: Unknown codec '$CODEC', falling back to libx264\e[0m";;
esac

if [ $USE_CRF -eq 1 ]; then
  echo -n "Crf (5-25) lower = higher quality (larger file size): "
  read CRF
  [ -z "$CRF" ] && CRF=18
  case "$VCODEC" in
    libx264|libx265)                 QUALITY_OPT="-crf $CRF"; PRESET_OPT="-preset medium";;
    libvpx-vp9|libaom-av1|libvpx)   QUALITY_OPT="-crf $CRF -b:v 0"; PRESET_OPT="";;
  esac
else
  echo -e "\e[33mWarning: '$CODEC' does not support CRF\e[0m"
  case "$VCODEC" in
    huffyuv|utvideo)       QUALITY_OPT=""; PRESET_OPT="";;
    ffv1)                  QUALITY_OPT="-level 3 -slices 24 -slicecrc 1"; PRESET_OPT="";;
    prores_ks)             QUALITY_OPT="-profile:v 4444 -q:v 1"; PRESET_OPT="";;
    dnxhd)                 QUALITY_OPT="-b:v 36M"; PRESET_OPT="";;
    libtheora)             QUALITY_OPT="-q:v 10"; PRESET_OPT="";;
    *)                     QUALITY_OPT="-q:v 1"; PRESET_OPT="";;
  esac
fi

PIX_OPT=""
[ -n "$PIXFMT" ] && PIX_OPT="-pix_fmt $PIXFMT"
[[ "$PIXFMT" == "bgra" || "$PIXFMT" == "bgrx" ]] && PIX_OPT="-pix_fmt rgb24"

PROF_OPT=""
[[ "$VCODEC" == "libx264" && "$PROFILE" == "High"    ]] && PROF_OPT="-profile:v high"
[[ "$VCODEC" == "libx265" && "$PROFILE" == "Main 10" ]] && PROF_OPT="-profile:v main10"

MODEL="rife-v4.6"
DEST="/sdcard/rifevulkan/${NAME}_x${MULTI}.${EXT}"

echo "FPS        : $FPS -> $NEWFPS"
echo "Codec      : $CODEC -> $VCODEC"
echo "PixelFormat: $PIXFMT"
echo "Profile    : $PROFILE"
echo "Audio      : ${HAS_AUDIO:-none}"
echo "Output     : $DEST"

rm -rf frames tmp out
mkdir -p frames tmp out

echo "Extracting frames..."
ffmpeg -i "$INPUT" -vsync 0 frames/%08d.png
cp -r frames/* tmp/

STEP=1
while [ $STEP -lt $MULTI ]; do
  echo "Interpolating x2 (step $STEP -> $((STEP*2)))..."
  rm -rf out; mkdir out
  ./rife-ncnn-vulkan -i tmp -o out -m "$MODEL"
  rm -rf tmp; mkdir tmp; cp -r out/* tmp/
  STEP=$((STEP * 2))
done
mv tmp out

echo "Encoding video..."
TMPVID="__tmpvid.${EXT}"

ffmpeg -framerate "$NEWFPS" -pattern_type glob -i "out/*.png" \
  -c:v $VCODEC $QUALITY_OPT $PRESET_OPT $PIX_OPT $PROF_OPT \
  -r "$NEWFPS" -an \
  "$TMPVID"

mkdir -p /sdcard/rifevulkan

if [ -n "$HAS_AUDIO" ]; then
  echo "Muxing audio from original..."
  ffmpeg -i "$TMPVID" -i "$INPUT" \
    -map 0:v:0 -map 1:a? \
    -c:v copy -c:a copy \
    "$DEST"
  rm -f "$TMPVID"
else
  mv "$TMPVID" "$DEST"
fi

termux-media-scan "$DEST"
echo -e "\e[32mDone: $DEST\e[0m"
