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

# The Android build process is slightly more complicated.
# We can't use libcurl/libssl from vcpkg, since there's a bug on Android preventing certificates from being opened:
# https://github.com/openssl/openssl/issues/13565
# We therefore use BoringSSL, but this means we need to build libcurl from scratch

build_android() {

    if [ -z "$ANDROID_NDK_HOME" ]; then  
        echo "ANDROID_NDK_HOME must be set";
        exit -1;
    fi

    if [ -z "$VCPKG_ROOT" ]; then  
        echo "VCPKG_ROOT must be set";
        exit -1;
    fi
    
    for arch in armeabi-v7a arm64-v8a x86 x86_64; do
        
        # fetch BoringSSL via vcpkg 
        vcpkg install boringssl:arm64-android
        VCPKG_ARCH_DIR=$VCPKG_ROOT/installed/arm64-android/
        OPENSSL_ROOT_DIR=$VCPKG_ARCH_DIR

        # fetch libcurl src via wget & build
        wget https://curl.se/download/curl-8.10.1.tar.gz && tar -zxf curl-8.10.1.tar.gz 
        cd curl-8.10.1 && mkdir build
        cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$arch \
            -DANDROID_PLATFORM=android-21 \
            -DCMAKE_BUILD_TYPE=Release \
            -DCURL_EXTRA_CONFIGURE_ARGS="--with-libidn2" \
            -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT_DIR" \
            -DOPENSSL_SSL_LIBRARY="$OPENSSL_ROOT/lib/libssl.a" \
            -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_ROOT/lib/libcrypto.a" \
            -DOPENSSL_INCLUDE_DIR="$OPENSSL_ROOT/include" \
            -DBUILD_CURL_EXE=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCURL_STATICLIB=ON \
            -DOPENSSL_USE_STATIC_LIBS=TRUE \
            ../
        cmake --build .

        # build Cesium Native
        mkdir -p "build/android/$arch"
        pushd "build/android/$arch"
        cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
              -DCMAKE_POSITION_INDEPENDENT_CODE=1 \
              -DCMAKE_BUILD_TYPE=Release \
              -DVCPKG_TRIPLET=arm64-android  \
              -DCESIUM_TESTS_ENABLED=0 \
              -DANDROID_PLATFORM=android-21 \
              -DANDROID_STL=c++_shared \
              -DANDROID_ABI=arm64-v8a \
              -DCMAKE_SYSTEM_NAME=Android \
              -DCMAKE_C_COMPILER=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/clang \
              -DCMAKE_CXX_COMPILER=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/clang++ \
              ../../../
        cmake --build .
        echo "Building Cesium Native for Android $arch"
        static_libs="${VCPKG_ARCH_DIR}/lib/libidn2.a ${VCPKG_ARCH_DIR}/lib/libiconv.a ${VCPKG_ARCH_DIR}/lib/libunistring.a $(find . -name "*.a")"
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
        
        cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \                                 
              -DCMAKE_BUILD_TYPE=Release \
              -DVCPKG_TRIPLET=arm64-android  \
              -DCESIUM_TESTS_ENABLED=0 \
              -DANDROID_PLATFORM=android-23 \
              -DANDROID_STL=c++_shared \
              -DANDROID_ABI=arm64-v8a \
              -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a -DCMAKE_SYSTEM_NAME=Android \
              -DVCPKG_TARGET_ARCHITECTURE=arm64 -DVCPKG_CMAKE_SYSTEM_NAME=Android -DCMAKE_C_COMPILER=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/clang \
              -DCMAKE_POSITION_INDEPENDENT_CODE=1 -DCMAKE_CXX_COMPILER=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/clang++ \
              ../../../
        
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