# Instructions for building the Cesium 3D Native package

## macOS

git clone git@github.com:CesiumGS/cesium-native.git --recurse-submodules
cd cesium-native
mkdir build
cd build 
cmake -DCMAKE_OSX_ARCHITECTURES=arm64 ..