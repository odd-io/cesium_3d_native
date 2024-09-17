# Instructions for building the Cesium 3D Native libraries

At runtime, the cesium_3d_native dart package must be linked with the Cesium Native libraries (and its dependencies). 

We have already built these libraries for macOS, Windows, Android and iOS; the hook/build.dart build script will pull these automatically from Cloudflare whenever a Dart/Flutter application that depends on this package is run.

Run `build.sh` if you need to (re)build these libraries (for exampe, if the upstream Cesium Native package is updated).

