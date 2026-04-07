#!/data/data/com.termux/files/usr/bin/bash

termux-setup-storage

cd ~

export DEBIAN_FRONTEND=noninteractive

apt update -y
apt upgrade -y -o Dpkg::Options::="--force-confold"

apt install -y git termux-api file ffmpeg libwebp mesa-vulkan-icd-swrast mesa-vulkan-icd-freedreno vulkan-loader

git clone https://github.com/niyeee4/rife-ncnn-vulkan-termux

cd rife-ncnn-vulkan-termux

rm -f 191.mp4 191.gif

mkdir -p $PREFIX/bin
cp rifevulkan $PREFIX/bin/

chmod +x $PREFIX/bin/rifevulkan

echo -e "type '\e[31mrifevulkan\e[0m' for video frame interpolation"
