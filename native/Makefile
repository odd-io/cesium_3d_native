# Compiler
CXX := g++

# Compiler flags
CXXFLAGS := -std=c++17

# Include directories
INCLUDES := -I include -I generated/include \
    -I ~/Documents/odd-io/asyncplusplus/include \
    -I ~/Documents/odd-io/spdlog/include \
    -I ~/Documents/odd-io/GSL/include \
    -I /Users/nickfisher/.ezvcpkg/2024.07.12/installed/arm64-osx/include

# Library directories
LIBDIRS := $(shell for dir in $$(find ../../cesium-native/build/ -maxdepth 1 -name "Cesium*"); do echo "-L$$(realpath $$dir)"; done)
LIBDIRS += -L/Users/nickfisher/.ezvcpkg/2024.07.12/installed/arm64-osx/lib -L/opt/homebrew/lib/

# Third-party libraries
THIRDPARTY := $(shell for lib in $$(find "/Users/nickfisher/.ezvcpkg/2024.07.12/installed/arm64-osx/lib/" -name "libabsl*" -o -name "libz*.a" -o -name "libwebp*.a" -o -name "libfmt.a"); do realpath "$$lib"; done)

# Libraries
LIBS := -lcurl -lssl -lcrypto \
    -lCesiumGltf -lCesiumGltfContent -lCesiumGltfReader \
    -lCesium3DTiles -lCesium3DTilesContent -lCesium3DTilesReader \
    -lCesium3DTilesWriter -lCesium3DTilesSelection \
    -lCesiumAsync -lCesiumGeospatial -lCesiumGeometry -lCesiumUtility \
    -lCesiumJsonReader -lCesiumQuantizedMeshTerrain -lCesiumRasterOverlays \
    -luriparser -lssl -lcrypto -lasync++ -llibmodpbase64 -lz -lktx -ls2 \
    -lmeshoptimizer -lturbojpeg -ldraco -ljpeg -lglm -lspdlog

# Frameworks
FRAMEWORKS := -framework CoreFoundation -framework SystemConfiguration

# Source files
SRC := src/cesium_tileset.c
OBJ := src/cesium_tileset.o

# Main target
TARGET := tileset_test

all: $(TARGET)

$(OBJ): $(SRC)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(TARGET): $(OBJ) tileset_test.c
	$(CXX) $(CXXFLAGS) $(INCLUDES) tileset_test.c $< $(THIRDPARTY) $(FRAMEWORKS) $(LIBDIRS) $(LIBS) -o $@

clean:
	rm -f $(OBJ) $(TARGET)

.PHONY: all clean