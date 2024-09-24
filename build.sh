if [ -z "$CESIUM_REPO" ]; then
    echo "You must set the \$CESIUM_REPO environment variable before calling this script";
    exit -1;
fi

if [ ! -d "$CESIUM_REPO" ]; then 
    echo "\$CESIUM_REPO environment variable does not point to the cesium native git repository.";
    exit -1;
fi

echo "Using Cesium Native repository at $CESIUM_REPO"

cd $CESIUM_REPO 
mkdir -p build

build_macos() {
    for arch in x64 arm64; do
        mkdir -p "build/macos/$arch" 
        pushd "build/macos/$arch"
        cmake -DCMAKE_OSX_ARCHITECTURES=${arch} -DCESIUM_TESTS_ENABLED=OFF ../../../
        cmake --build . # --config Debug
        echo "Building Cesium Native for macOS $arch"
        static_libs=$(find . -name "*.a")
        ezvcpkg_dir=$(grep ezvcpkg cmake_install.cmake | head -n1 | cut -d' ' -f9 | sed 's/^"//; s/"[)]$//; s/packages.*//')
        echo "ezvcpkg_dir: $ezvcpkg_dir"
        ezvcpkg_libs=$(find "$ezvcpkg_dir" -path "*$arch*.a")
        zip_file="cesium-native-v0.39.0-macos-${arch}-release.zip"
        for file in $static_libs; do
            if [ ! -f "$zip_file" ]; then
                zip -j "$zip_file" "$file"
            else
                zip -uj "$zip_file" "$file"
            fi
        done
        echo "ezvcpkg: $ezvcpkg_libs"
        for file in $ezvcpkg_libs; do
            zip -uj "$zip_file" "$file" 
        done
        popd
    done
}

build_android() {
    for arch in armeabi-v7a arm64-v8a x86 x86_64; do
        mkdir -p "build/android/$arch"
        pushd "build/android/$arch"
        cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
              -DANDROID_ABI=$arch \
              -DANDROID_PLATFORM=android-21 \
              -DCESIUM_TESTS_ENABLED=OFF \
              ../../../
        cmake --build .
        echo "Building Cesium Native for Android $arch"
        static_libs=$(find . -name "*.a")
        zip_file="cesium-native-v0.39.0-android-${arch}-release.zip"
        for file in $static_libs; do
            if [ ! -f "$zip_file" ]; then
                zip -j "$zip_file" "$file"
            else
                zip -uj "$zip_file" "$file"
            fi
        done
        popd
    done
}

build_ios() {
    for arch in arm64 x86_64; do
        mkdir -p "build/ios/$arch" 
        pushd "build/ios/$arch"
        
        if [ "$arch" == "arm64" ]; then
            sdk="iphoneos"
        else
            sdk="iphonesimulator"
        fi
        
        # For some reason the default vcpkg dir isn't downloading/keeping the KHR headers
        # so you need to manually run:
        # > brew install vcpkg
        # > vcpkg install ktx:arm64-ios
        # export VCPKG_INCLUDE_DIR=/path/to/your/manual/vcpkg/installed/arm64-ios/include/
        
        cmake -DCMAKE_INCLUDE_PATH=/Users/nickfisher/Documents/vcpkg/installed/arm64-ios/include/ \
            -DCMAKE_TOOLCHAIN_FILE=/Users/nickfisher/Documents/odd-io/cesium_3d_native/native/ios.toolchain.cmake \
            -DPLATFORM=OS64 \
            -DARCHS=arm64 \
            -DCMAKE_CXX_FLAGS="-I$VCPKG_INCLUDE_DIR" -DCMAKE_SYSTEM_NAME=iOS \
            -DVCPKG_TRIPLET=arm64-ios -DCESIUM_TESTS_ENABLED=OFF \
            ..
        
        cmake --build . --config Release
        
        echo "Building Cesium Native for iOS $arch"
        static_libs=
        ezvcpkg_dir=$(grep ezvcpkg cmake_install.cmake | head -n1 | cut -d' ' -f9 | sed 's/^"//; s/"[)]$//; s/packages.*//')
        echo "ezvcpkg_dir: $ezvcpkg_dir"
        ezvcpkg_libs=
        
        zip_file="cesium-native-v0.39.0-ios-${arch}-release.zip"
        for file in $(find . -name "*.a"); do
            if [ ! -f "$zip_file" ]; then
                zip -j "$zip_file" "$file"
            else
                zip -uj "$zip_file" "$file"
            fi
        done
        
        echo "ezvcpkg: $ezvcpkg_libs"
        for file in $(find "$ezvcpkg_dir" -path "*$arch*.a" -not -path "*debug*"); do
            zip -uj "$zip_file" "$file" 
        done
        
        popd
    done
    
    # Create a universal (fat) library
    mkdir -p "build/ios/universal"
    pushd "build/ios/universal"
    
    for lib in $(find ../arm64 -name "*.a" | xargs -n1 basename); do
        lipo -create "../arm64/$lib" "../x86_64/$lib" -output "$lib"
    done
    
    zip_file="cesium-native-v0.39.0-ios-universal-release.zip"
    for file in *.a; do
        if [ ! -f "$zip_file" ]; then
            zip -j "$zip_file" "$file"
        else
            zip -uj "$zip_file" "$file"
        fi
    done
    
    popd
}

build_macos
build_android
build_ios