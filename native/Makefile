# Compiler
CXX := g++

# Compiler flags
CXXFLAGS := -std=c++17 -fPIC

# Include directories
INCLUDES := -I include -I generated/include -I thirdparty/include

# Library directories
LIBDIRS := $(shell for dir in $$(find ../../cesium-native/build/ -maxdepth 1 -name "Cesium*"); do echo "-L$$(realpath $$dir)"; done)
LIBDIRS += -L/Users/nickfisher/.ezvcpkg/2024.07.12/installed/arm64-osx/lib -L/opt/homebrew/lib/

# Third-party libraries
THIRDPARTY := $(shell for lib in $$(find "/Users/nickfisher/.ezvcpkg/2024.07.12/installed/arm64-osx/lib/" -name "libabsl*" -o -name "libz*.a" -o -name "libwebp*.a" -o -name "libfmt.a"); do realpath "$$lib"; done)

# Libraries
LIBS := -lcurl -lssl -lcrypto \
    -lCesiumGltf -lCesiumGltfContent -lCesiumGltfReader \
    -lCesiumNativeTiles -lCesiumNativeTilesContent -lCesiumNativeTilesReader \
    -lCesiumNativeTilesWriter -lCesiumNativeTilesSelection \
    -lCesiumAsync -lCesiumGeospatial -lCesiumGeometry -lCesiumUtility \
    -lCesiumJsonReader -lCesiumQuantizedMeshTerrain -lCesiumRasterOverlays \
    -luriparser -lssl -lcrypto -lasync++ -llibmodpbase64 -lz -lktx -ls2 \
    -lmeshoptimizer -lturbojpeg -ldraco -ljpeg -lglm -lspdlog

# Frameworks
FRAMEWORKS := -framework CoreFoundation -framework SystemConfiguration

# Source files
SRC := src/CesiumTilesetCApi.cpp
OBJ := src/CesiumTilesetCApi.o

# Dynamic library name
DYLIB := libCesiumTilesetCApi.dylib

# Main target
TARGET := tileset_test

all: $(TARGET)

$(OBJ): $(SRC)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(DYLIB): $(OBJ)
	$(CXX) -shared -o $@ $< $(LIBDIRS) $(LIBS) $(FRAMEWORKS) $(THIRDPARTY)

$(TARGET): $(DYLIB) tileset_test.c
	$(CXX) $(CXXFLAGS) $(INCLUDES) tileset_test.c -L. -lCesiumTilesetCApi -o $@

clean:
	rm -f $(OBJ) $(DYLIB) $(TARGET)

.PHONY: all clean