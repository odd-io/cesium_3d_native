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
    export ANDROID_NDK=${ANDROID_NDK_HOME}

    if [ -z "$VCPKG_ROOT" ]; then  
        echo "VCPKG_ROOT must be set";
        exit -1;
    fi
    export EZVCPKG_BASEDIR=$VCPKG_ROOT
    # for arch in armeabi-v7a arm64-v8a x86 x86_64; do
    for arch in armeabi-v7a; do
        
        if [ "$arch" = "arm64-v8a" ]; then
            VCKG_TRIPLET=arm64-android    
        elif [ "$arch" = "armeabi-v7a" ]; then
            VCPKG_TRIPLET=arm-neon-android
        elif [ "$arch" = "x86" ]; then
            VCPKG_TRIPLET=x86-android
        elif [ "$arch" = "x86_64" ]; then
            VCPKG_TRIPLET=x64-android
        else
            echo "Unsupported architecture: $arch"
            exit 1
        fi
        # fetch BoringSSL via vcpkg 
        vcpkg install boringssl:$VCPKG_TRIPLET
        vcpkg install libidn2:$VCPKG_TRIPLET  
        VCPKG_ARCH_DIR=$VCPKG_ROOT/installed/$VCPKG_TRIPLET/
        OPENSSL_ROOT_DIR=$VCPKG_ARCH_DIR

        # build Cesium Native
        mkdir -p "build/android/$arch"
        pushd "build/android/$arch"

        # fetch libcurl src via wget & build
        wget https://curl.se/download/curl-8.10.1.tar.gz && tar -zxf curl-8.10.1.tar.gz 
        pushd curl-8.10.1
        mkdir build
        cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$arch \
            -DANDROID_PLATFORM=android-21 \
            -DCMAKE_BUILD_TYPE=Release \
            -DCURL_EXTRA_CONFIGURE_ARGS="--with-libidn2" \
            -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT_DIR" \
            -DOPENSSL_SSL_LIBRARY="$OPENSSL_ROOT_DIR/lib/libssl.a" \
            -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_ROOT_DIR/lib/libcrypto.a" \
            -DOPENSSL_INCLUDE_DIR="$OPENSSL_ROOT_DIR/include" \
            -DBUILD_CURL_EXE=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCURL_STATICLIB=ON \
            -DOPENSSL_USE_STATIC_LIBS=TRUE \
            ../
        cmake --build .
        popd

        cmake -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/2024.07.12/scripts/buildsystems/vcpkg.cmake \
      -DCMAKE_POSITION_INDEPENDENT_CODE=1 \
      -DCMAKE_BUILD_TYPE=Release \
      -DVCPKG_TRIPLET=$VCPKG_TRIPLET \
      -DCESIUM_TESTS_ENABLED=0 \
      -DANDROID_PLATFORM=android-21 \
      -DANDROID_STL=c++_shared \
      -DANDROID_ABI=x86_64 \
      -DCMAKE_SYSTEM_NAME=Android \
      -DCMAKE_ANDROID_NDK=$ANDROID_NDK_HOME \
      -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
      -DAsync++_DIR=$VCPKG_ROOT/2024.07.12/packages/asyncplusplus_${VCPKG_TRIPLET}/share/async++ -DCatch2_DIR=$VCPKG_ROOT/2024.07.12/packages/catch2_${VCPKG_TRIPLET}/share/Catch2/ -Ddraco_DIR=$VCPKG_ROOT/2024.07.12/packages/draco_${VCPKG_TRIPLET}/share/draco/ -Dexpected-lite_DIR=$VCPKG_ROOT/2024.07.12/packages/expected-lite_${VCPKG_TRIPLET}/share/expected-lite/ -Dglm_DIR=$VCPKG_ROOT/2024.07.12/packages/glm_${VCPKG_TRIPLET}/share/glm/ \
        -Dmeshoptimizer_DIR=$VCPKG_ROOT/2024.07.12/packages/meshoptimizer_${VCPKG_TRIPLET}/share/meshoptimizer/ \
        -DMicrosoft.GSL_DIR=$VCPKG_ROOT/2024.07.12/packages/ms-gsl_${VCPKG_TRIPLET}/share/Microsoft.GSL \
        -Dhttplib_DIR=$VCPKG_ROOT/2024.07.12/packages/cpp-httplib_${VCPKG_TRIPLET}/share/httplib/ \
        -DKtx_DIR=$VCPKG_ROOT/2024.07.12/packages/ktx_${VCPKG_TRIPLET}/share/ktx/ \
        -Dlibmorton_DIR=$VCPKG_ROOT/2024.07.12/packages/libmorton_${VCPKG_TRIPLET}/share/libmorton/ \
        -Dlibjpeg-turbo_DIR=$VCPKG_ROOT/2024.07.12/packages/libjpeg-turbo_${VCPKG_TRIPLET}/share/libjpeg-turbo/ \
        -DOpenSSL_DIR=$VCPKG_ROOT/2024.07.12/packages/openssl_${VCPKG_TRIPLET}/share/openssl/ \
        -Ds2_DIR=$VCPKG_ROOT/2024.07.12/packages/s2geometry_${VCPKG_TRIPLET}/share/s2/ \
        -Dspdlog_DIR=$VCPKG_ROOT/2024.07.12/packages/spdlog_${VCPKG_TRIPLET}/share/spdlog/ \
        -Dtinyxml2_DIR=$VCPKG_ROOT/2024.07.12/packages/tinyxml2_${VCPKG_TRIPLET}/share/tinyxml2/ \
        -Dunofficial-sqlite3_DIR=$VCPKG_ROOT/2024.07.12/packages/sqlite3_${VCPKG_TRIPLET}/share/unofficial-sqlite3/ \
        -Duriparser_DIR=$VCPKG_ROOT/2024.07.12/packages/uriparser_${VCPKG_TRIPLET}/share/uriparser/ \
        -DWebP_DIR=$VCPKG_ROOT/2024.07.12/packages/libwebp_${VCPKG_TRIPLET}/share/WebP/ -Dzstd_DIR=$VCPKG_ROOT/2024.07.12/packages/zstd_${VCPKG_TRIPLET}/share/zstd/ -DOPENSSL_ROOT_DIR=$VCPKG_ROOT/installed/${VCPKG_TRIPLET} \
        -DOPENSSL_USE_STATIC_LIBS=TRUE \
        -DOPENSSL_CRYPTO_LIBRARY=$VCPKG_ROOT/installed/${VCPKG_TRIPLET}/lib/libcrypto.a \
        -DOPENSSL_SSL_LIBRARY=$VCPKG_ROOT/installed/${VCPKG_TRIPLET}/lib/libssl.a \
        -DOPENSSL_INCLUDE_DIR=$VCPKG_ROOT/installed/${VCPKG_TRIPLET}/include \
        -Dabsl_DIR=$VCPKG_ROOT/2024.07.12/packages/abseil_${VCPKG_TRIPLET}/share/absl/ -Dfmt_DIR=$VCPKG_ROOT/2024.07.12/packages/fmt_${VCPKG_TRIPLET}/share/fmt/ ../../../
        cmake --build .
        echo "Building Cesium Native for Android $arch"
        static_libs="${VCPKG_ARCH_DIR}/lib/libidn2.a ${VCPKG_ARCH_DIR}/lib/libiconv.a ${VCPKG_ARCH_DIR}/lib/libunistring.a $(find . -name "*.a")"
        zip_file="cesium-native-v0.39.0-android-${arch}-release.zip"
        for file in "${static_libs}"; do
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

# build_macos
build_android
# build_ios