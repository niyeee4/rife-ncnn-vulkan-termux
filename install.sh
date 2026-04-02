cd

apt update && apt upgrade -y libwebp mesa-vulkan-icd-swrast mesa-vulkan-icd-freedreno swiftshader -y

apt install -y vulkan-loader-android -y

cd

git clone https://github.com/niyeee4/rife-ncnn-vulkan-termux

cd rife-ncnn-vulkan-termux

cp rifevulkan $PREFIX/bin/

chmod +x $PREFIX/bin/rifevulkan

echo -e "type '\e[31mrifevulkan\e[0m' for video frame interpolation"
