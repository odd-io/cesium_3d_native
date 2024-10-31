#ifndef CESIUM_TILESET_H
#define CESIUM_TILESET_H

#define GLM_FORCE_XYZW_ONLY
#define GLM_FORCE_EXPLICIT_CTOR 
#define GLM_FORCE_SIZE_T_LENGTH 

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef _WIN32
#include "CesiumTilesetWin32.h"
#else
#define API_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
namespace DartCesiumNative {
#endif

// Here we define structs that act as opaque pointers to various Cesium native C++ classes.
// These can be safely passed to/from the Dart/C API boundary; on the native side, 
// these can be resolved to their C++ types with reinterpret_cast, e.g.:
// void myMethod(CesiumTileset* cesiumTileset)  {
//      Cesium3DTilesSelection::Tileset* tileset = reinterpret_cast<Cesium3DTilesSelection::Tileset>(cesiumTileset);
// }
typedef struct CesiumTileset CesiumTileset; //  Cesium3DTilesSelection::Tileset
typedef struct CesiumTile CesiumTile; //  Cesium3DTilesSelection::Tile
typedef struct CesiumGltfModel CesiumGltfModel; //  CesiumGltf::Model

// Options to use when loading tilesets. A subset of TilesetOptions.
struct CesiumTilesetOptions {
    bool forbidHoles;
    bool enableLodTransitionPeriod;
    float lodTransitionLength;
    bool enableOcclusionCulling;
    bool enableFogCulling;
    bool enableFrustumCulling;
    bool enforceCulledScreenSpaceError;
    double culledScreenSpaceError;
    double maximumScreenSpaceError;
    uint32_t maximumSimultaneousTileLoads;
    uint32_t maximumSimultaneousSubtreeLoads;
    uint32_t loadingDescendantLimit;
};
typedef struct CesiumTilesetOptions CesiumTilesetOptions;

// Holds pointers to all current tiles with render content.
struct CesiumTilesetRenderableTiles {
    const CesiumTile* tiles[4096];
    // CesiumTileSelectionState states[4096];
    size_t numTiles;
};
typedef struct CesiumTilesetRenderableTiles CesiumTilesetRenderableTiles;


// This is copied verbatim from CesiumTileLoadState in Tile.h so we can generate the correct values with Dart ffigen
enum CesiumTileLoadState {
    CT_LS_UNLOADING = -2,
    CT_LS_FAILED_TEMPORARILY = -1,
    CT_LS_UNLOADED = 0,
    CT_LS_CONTENT_LOADING = 1,
    CT_LS_CONTENT_LOADED = 2,
    CT_LS_DONE = 3,
    CT_LS_FAILED = 4,
};
typedef enum CesiumTileLoadState CesiumTileLoadState;

// A convenience enum to check what type of content a Tile represents
enum CesiumTileContentType {
    CT_TC_EMPTY,
    CT_TC_RENDER,
    CT_TC_EXTERNAL,
    CT_TC_UNKNOWN,
    CT_TC_ERROR,
};
typedef enum CesiumTileContentType CesiumTileContentType;

typedef struct { 
    double x;
    double y;
    double z;
} double3;

typedef struct { 
    double col1[4];
    double col2[4];
    double col3[4];
    double col4[4];
} double4x4;

// Simplified view state structure
typedef struct {
    double position[3];
    double direction[3];
    double up[3];
    double viewportWidth;
    double viewportHeight;
    double horizontalFov;
    double verticalFov;
} CesiumViewState;

typedef struct CesiumBoundingSphere {
    double center[3];
    double radius;
} CesiumBoundingSphere;

typedef struct CesiumOrientedBoundingBox {
    double center[3];
    double halfAxes[9];  // 3x3 matrix stored in column-major order
} CesiumOrientedBoundingBox;

typedef struct CesiumBoundingRegion {
    double west;
    double south;
    double east;
    double north;
    double minimumHeight;
    double maximumHeight;
} CesiumBoundingRegion;

enum CesiumBoundingVolumeType {
    CT_BV_SPHERE,
    CT_BV_ORIENTED_BOX,
    CT_BV_REGION
};
typedef enum CesiumBoundingVolumeType CesiumBoundingVolumeType;

struct CesiumBoundingVolume {
    CesiumBoundingVolumeType type;
    union {
        CesiumBoundingSphere sphere;
        CesiumOrientedBoundingBox orientedBox;
        CesiumBoundingRegion region;
    } volume;
};
typedef struct CesiumBoundingVolume CesiumBoundingVolume;

struct CesiumCartographic { 
  double longitude; // radians
  double latitude;  // radians
  double height; // metres
};
typedef struct CesiumCartographic CesiumCartographic; 

enum CesiumTileSelectionState {
    CT_SS_NONE,
    CT_SS_CULLED,
    CT_SS_RENDERED,
    CT_SS_REFINED,
    CT_SS_RENDERED_AND_KICKED,
    CT_SS_REFINED_AND_KICKED
};
typedef enum CesiumTileSelectionState CesiumTileSelectionState;

struct SerializedCesiumGltfModel {
    uint8_t* data;
    size_t length;
};
typedef struct SerializedCesiumGltfModel SerializedCesiumGltfModel;

// Initializes all bindings. Must be called before any other CesiumTileset_ function.
// numThreads refers to the number of threads that will be created for the Async system (job queue).
//
API_EXPORT void CesiumTileset_initialize(uint32_t numThreads);

API_EXPORT void CesiumTileset_pumpAsyncQueue();

// Create a Tileset from a URL
API_EXPORT CesiumTileset* CesiumTileset_create(const char* url, CesiumTilesetOptions cesiumTilesetOptions, void(*onRootTileAvailableEvent)());

// Create a Tileset from a Cesium ion asset. 
API_EXPORT CesiumTileset* CesiumTileset_createFromIonAsset(int64_t assetId, const char* accessToken, CesiumTilesetOptions cesiumTilesetOptions, void(*onRootTileAvailableEvent)());

API_EXPORT float CesiumTileset_computeLoadProgress(CesiumTileset* tileset);

API_EXPORT int CesiumTileset_getLastFrameNumber(CesiumTileset* tileset);

API_EXPORT int CesiumTileset_getNumTilesLoaded(CesiumTileset* tileset);

// Returns true if an error was encountered attempting to load this tileset. 
API_EXPORT int CesiumTileset_hasLoadError(CesiumTileset* tileset);

// Retrieve the error message encountered when loading this tileset. Returns NULL if none.
API_EXPORT void CesiumTileset_getErrorMessage(CesiumTileset* tileset, char* out);

// Destroy a Tileset. This is an asynchronous operation; pass a callback as onTileDestroyEvent to be notified when destruction is complete.
API_EXPORT void CesiumTileset_destroy(CesiumTileset* tileset, void(*onTileDestroyEvent)());

// Update the view and get the number of tiles to render
API_EXPORT int CesiumTileset_updateView(CesiumTileset* tileset, const CesiumViewState viewState, float deltaTime);

// Asynchronously update the view and get the number of tiles to render
API_EXPORT void CesiumTileset_updateViewAsync(CesiumTileset* tileset, const CesiumViewState viewState, float deltaTime, void(*callback)(int));

// Gets the cartographic position of the camera in its current orientation (with respect to WGS84).
API_EXPORT CesiumCartographic CesiumTileset_getPositionCartographic(CesiumViewState viewState);

// Gets the cartographic position of the given point (with respect to WGS84).
API_EXPORT CesiumCartographic CesiumTileset_cartesianToCartographic(double x, double y, double z);

// Gets the Cartesian coordinates of the given latitude/longitude (on the WGS84 ellipsoid).
// Latitude/longitude are in radians, height is in metres.
API_EXPORT double3 CesiumTileset_cartographicToCartesian(double latitude, double longitude, double height);

// Return the number of tiles kicked on the last update. This will remain valid until the next call to CesiumTileset_updateView.
API_EXPORT int32_t CesiumTileset_getTilesKicked(CesiumTileset* tileset);

// Returns the tile to render at this frame at the given index. Returns NULL if index is out-of-bounds.
API_EXPORT CesiumTile* CesiumTileset_getTileToRenderThisFrame(CesiumTileset* tileset, int index);

// Get the render data for a specific tile
API_EXPORT void CesiumTileset_getTileRenderData(CesiumTileset* tileset, int index, void** renderData);

// Get the load state for the tile at the given index
API_EXPORT CesiumTileLoadState CesiumTileset_getTileLoadState(CesiumTile* tile);

// Get the type of content for the tile at the given index
API_EXPORT CesiumTileContentType CesiumTileset_getTileContentType(CesiumTile* tile);

API_EXPORT CesiumTilesetRenderableTiles CesiumTileset_getRenderableTiles(CesiumTile* cesiumTile);

API_EXPORT int32_t CesiumTileset_getNumberOfTilesLoaded(CesiumTileset* tileset);

API_EXPORT CesiumTile* CesiumTileset_getRootTile(CesiumTileset* tileset);

API_EXPORT CesiumBoundingVolume CesiumTile_getBoundingVolume(CesiumTile* tile, bool convertToOrientedBox);

API_EXPORT double CesiumTile_squaredDistanceToBoundingVolume(CesiumTile* oTile, CesiumViewState oViewState);

API_EXPORT double3 CesiumTile_getBoundingVolumeCenter(CesiumTile* tile);

API_EXPORT double4x4 CesiumTile_getTransform(CesiumTile* tile);

// Get a handle to the CesiumGltf::Model object for a given tile
API_EXPORT CesiumGltfModel* CesiumTile_getModel(CesiumTile* tile);

API_EXPORT double4x4 CesiumGltfModel_applyRtcCenter(CesiumGltfModel* model, double4x4 transform);

// Check if a tile has a valid model
API_EXPORT int CesiumTile_hasModel(CesiumTile* tile);

API_EXPORT CesiumTileSelectionState CesiumTile_getTileSelectionState(CesiumTile* tile, int frameNumber);

// Get the number of meshes in the model
API_EXPORT int32_t CesiumGltfModel_getMeshCount(CesiumGltfModel* model);

// Get the number of materials in the model
API_EXPORT int32_t CesiumGltfModel_getMaterialCount(CesiumGltfModel* model);

// Get the number of textures in the model
API_EXPORT int32_t CesiumGltfModel_getTextureCount(CesiumGltfModel* model);

API_EXPORT SerializedCesiumGltfModel CesiumGltfModel_serialize(CesiumGltfModel* opaqueModel);

API_EXPORT void CesiumGltfModel_serializeAsync(CesiumGltfModel* opaqueModel, void(*callback)(SerializedCesiumGltfModel));

API_EXPORT void CesiumGltfModel_free_serialized(SerializedCesiumGltfModel serialized);

#ifdef __cplusplus
}
}
#endif

#endif // CESIUM_TILESET_H