#ifndef CESIUM_TILESET_H
#define CESIUM_TILESET_H

#define GLM_FORCE_XYZW_ONLY
#define GLM_FORCE_EXPLICIT_CTOR 
#define GLM_FORCE_SIZE_T_LENGTH 

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
namespace DartCesiumNative {
#else
typedef int bool;    
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
  double longitude;
  double latitude;
  double height;
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
void CesiumTileset_initialize(uint32_t numThreads);

void CesiumTileset_pumpAsyncQueue();

// Create a Tileset from a URL
CesiumTileset* CesiumTileset_create(const char* url, void(*onRootTileAvailableEvent)());

// Create a Tileset from a Cesium ion asset. 
CesiumTileset* CesiumTileset_createFromIonAsset(int64_t assetId, const char* accessToken, void(*onRootTileAvailableEvent)());

float CesiumTileset_computeLoadProgress(CesiumTileset* tileset);

int CesiumTileset_getLastFrameNumber(CesiumTileset* tileset);

int CesiumTileset_getNumTilesLoaded(CesiumTileset* tileset);

// Returns true if an error was encountered attempting to load this tileset. 
int CesiumTileset_hasLoadError(CesiumTileset* tileset);

// Retrieve the error message encountered when loading this tileset. Returns NULL if none.
void CesiumTileset_getErrorMessage(CesiumTileset* tileset, char* out);

// Destroy a Tileset. This is an asynchronous operation; pass a callback as onTileDestroyEvent to be notified when destruction is complete.
void CesiumTileset_destroy(CesiumTileset* tileset, void(*onTileDestroyEvent)());

// Update the view and get the number of tiles to render
int CesiumTileset_updateView(CesiumTileset* tileset, const CesiumViewState viewState, float deltaTime);

// Asynchronously update the view and get the number of tiles to render
void CesiumTileset_updateViewAsync(CesiumTileset* tileset, const CesiumViewState viewState, float deltaTime, void(*callback)(int));

CesiumCartographic CesiumTileset_getPositionCartographic(CesiumViewState viewState);

// Return the number of tiles kicked on the last update. This will remain valid until the next call to CesiumTileset_updateView.
int32_t CesiumTileset_getTilesKicked(CesiumTileset* tileset);

// Returns the tile to render at this frame at the given index. Returns NULL if index is out-of-bounds.
CesiumTile* CesiumTileset_getTileToRenderThisFrame(CesiumTileset* tileset, int index);

// Get the render data for a specific tile
void CesiumTileset_getTileRenderData(CesiumTileset* tileset, int index, void** renderData);

// Get the load state for the tile at the given index
CesiumTileLoadState CesiumTileset_getTileLoadState(CesiumTile* tile);

// Get the type of content for the tile at the given index
CesiumTileContentType CesiumTileset_getTileContentType(CesiumTile* tile);

CesiumTilesetRenderableTiles CesiumTileset_getRenderableTiles(CesiumTile* cesiumTile);

int32_t CesiumTileset_getNumberOfTilesLoaded(CesiumTileset* tileset);

CesiumTile* CesiumTileset_getRootTile(CesiumTileset* tileset);

CesiumBoundingVolume CesiumTile_getBoundingVolume(CesiumTile* tile, bool convertToOrientedBox);

double CesiumTile_squaredDistanceToBoundingVolume(CesiumTile* oTile, CesiumViewState oViewState);

double3 CesiumTile_getBoundingVolumeCenter(CesiumTile* tile);

double4x4 CesiumTile_getTransform(CesiumTile* tile);

// Get a handle to the CesiumGltf::Model object for a given tile
CesiumGltfModel* CesiumTile_getModel(CesiumTile* tile);

double4x4 CesiumGltfModel_getTransform(CesiumGltfModel* model);

// Check if a tile has a valid model
int CesiumTile_hasModel(CesiumTile* tile);

CesiumTileSelectionState CesiumTile_getTileSelectionState(CesiumTile* tile, int frameNumber);

// Get the number of meshes in the model
int32_t CesiumGltfModel_getMeshCount(CesiumGltfModel* model);

// Get the number of materials in the model
int32_t CesiumGltfModel_getMaterialCount(CesiumGltfModel* model);

// Get the number of textures in the model
int32_t CesiumGltfModel_getTextureCount(CesiumGltfModel* model);

SerializedCesiumGltfModel CesiumGltfModel_serialize(CesiumGltfModel* opaqueModel);
void CesiumGltfModel_serializeAsync(CesiumGltfModel* opaqueModel, void(*callback)(SerializedCesiumGltfModel));

void CesiumGltfModel_free_serialized(SerializedCesiumGltfModel serialized);

#ifdef __cplusplus
}
}
#endif

#endif // CESIUM_TILESET_H