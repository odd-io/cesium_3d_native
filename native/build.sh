libdirs=$(for dir in $(find ../../cesium-native/build/ -maxdepth 1 -name "Cesium*"); do echo "-L$(realpath $dir)"; done)
thirdparty=$(for lib in $(find "/Users/nickfisher/.ezvcpkg/2024.07.12/installed/arm64-osx/lib/" -name "libabsl*" -o -name "libz*.a" -o -name "libwebp*.a" -o -name "libfmt.a"); do realpath "$lib"; done)
# g++ -c -I include -I generated/include \
#     -I ~/Documents/odd-io/asyncplusplus/include \
#     -I ~/Documents/odd-io/spdlog/include \
#     -I ~/Documents/odd-io/GSL/include \
#     -I /Users/nickfisher/.ezvcpkg/2024.07.12/installed/arm64-osx/include \
#     src/cesium_tileset.c -std=c++17 
g++ -c -I include -I generated/include \
    -I ~/Documents/odd-io/asyncplusplus/include \
    -I ~/Documents/odd-io/spdlog/include \
    -I ~/Documents/odd-io/GSL/include \
    -I /Users/nickfisher/.ezvcpkg/2024.07.12/installed/arm64-osx/include \
    src/cesium_tileset.c -std=c++17 -o src/cesium_tileset.o

# echo "src/cesium_tileset.o complete"
# echo $libdirs
g++ -I include -I generated/include \
    -I ~/Documents/odd-io/asyncplusplus/include \
    -I ~/Documents/odd-io/spdlog/include \
    -I ~/Documents/odd-io/GSL/include \
    -I /Users/nickfisher/.ezvcpkg/2024.07.12/installed/arm64-osx/include \
    tileset_test.c src/cesium_tileset.o $thirdparty -std=c++17 -framework CoreFoundation  -framework SystemConfiguration \
    -L/Users/nickfisher/.ezvcpkg/2024.07.12/installed/arm64-osx/lib \
    $libdirs \
    -L/opt/homebrew/lib/ \
    -lcurl -lssl -lcrypto \
    -lCesiumGltf \
    -lCesiumGltfContent \
    -lCesiumGltfReader \
    -lCesium3DTiles \
    -lCesium3DTilesContent \
    -lCesium3DTilesReader \
    -lCesium3DTilesWriter \
    -lCesium3DTilesSelection \
    -lCesiumAsync \
    -lCesiumGeospatial \
    -lCesiumGeometry \
    -lCesiumUtility \
    -lCesiumJsonReader \
    -lCesiumQuantizedMeshTerrain \
    -lCesiumRasterOverlays \
    -luriparser \
    -lssl \
    -lcrypto \
    -lasync++ \
    -llibmodpbase64 \
    -lz \
    -lktx \
    -ls2 \
    -lmeshoptimizer \
    -lturbojpeg \
    -ldraco \
    -ljpeg \
    -lglm \
    -lspdlog \
    -o tileset_test
    #  \
    # $(echo "$thirdparty" | tr '\n' ' ') \
    # $(echo "$libs" | tr '\n' ' ') \
    # /Users/nickfisher/Documents/odd-io/curl-8.9.1/lib/.libs/libcurl.a \
    # -std=c++17 -framework CoreFoundation  -framework SystemConfiguration \
    #  -L/Users/nickfisher/Documents/odd-io/curl-8.9.1/lib/.libs/\
    # $libdirs \
    