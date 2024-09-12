# Instructions for building the Cesium 3D Native libraries

At runtime, the cesium_3d_native dart package must be linked with the Cesium Native libraries (and its dependencies). 

We have already built these libraries for macOS, Windows, Android and iOS; the hook/build.dart build script will pull these automatically from Cloudflare whenever a Dart/Flutter application that depends on this package is run.

Follow these instructions if you need to (re)build these libraries (for exampe, if the upstream Cesium Native package is updated).

## macOS

git clone git@github.com:CesiumGS/cesium-native.git --recurse-submodules
cd cesium-native
mkdir build
cd build 
cmake -DCMAKE_OSX_ARCHITECTURES=arm64 -DCESIUM_TESTS_ENABLED=OFF ..
cmake --build . # --config Debug
libdir=/tmp/cesium_3d_native_libs
mkdir -p $libdir
for file in $(find . -name "*.a"); do cp $file $libdir; done
pkgdir=$HOME/.ezvcpkg # the cesium-native build process uses vcpkg for dependencies like zstd/absl/etc. These will be stored as static libraries in a subdirectory under $HOME/.ezvcpkg (e.g. for me it's "/Users/nickfisher/.ezvcpkg/2024.07.12"). If you have multiple subdirectories, you'll need to figure out which one and change pkgdir appropriately.
for file in $(find $pkgdir -name "*.a"); do cp $file $libdir; done 



