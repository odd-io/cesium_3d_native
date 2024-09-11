#ifndef CESIUM_TILESET_H
#define CESIUM_TILESET_H

#define GLM_FORCE_XYZW_ONLY
#define GLM_FORCE_EXPLICIT_CTOR 
#define GLM_FORCE_SIZE_T_LENGTH 

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

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
typedef struct CesiumTilesetRenderableTiles {
    const CesiumTile ** const tiles;
    int32_t numTiles;
    const int32_t maxSize;
} CesiumTilesetRenderableTiles;

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

// Simplified view state structure
typedef struct {
    double position[3];
    double direction[3];
    double up[3];
    double viewportWidth;
    double viewportHeight;
    double horizontalFov;
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

// Initializes all bindings. Must be called before any other CesiumTileset_ function.
void CesiumTileset_initialize();

// Create a Tileset from a URL
CesiumTileset* CesiumTileset_create(const char* url);

// Create a Tileset from a Cesium ion asset
CesiumTileset* CesiumTileset_createFromIonAsset(int64_t assetId, const char* accessToken);

int CesiumTileset_getNumTilesLoaded(CesiumTileset* tileset);

// Returns true if an error was encountered attempting to load this tileset. 
int CesiumTileset_hasLoadError(CesiumTileset* tileset);

// Retrieve the error message encountered when loading this tileset. Returns NULL if none.
void CesiumTileset_getErrorMessage(CesiumTileset* tileset, char* out);

// Destroy a Tileset
void CesiumTileset_destroy(CesiumTileset* tileset);

CesiumViewState CesiumTileset_createViewState(double positionX, double positionY, double positionZ, double directionX, double directionY, double directionZ, double upX, double upY, double upZ,
double viewportWidth, double viewportHeight, double horizontalFov);

// Update the view and get the number of tiles to render
int CesiumTileset_updateView(CesiumTileset* tileset, const CesiumViewState viewState, float deltaTime);

// Returns the tile to render at this frame at the given index. Returns NULL if index is out-of-bounds.
CesiumTile* CesiumTileset_getTileToRenderThisFrame(CesiumTileset* tileset, int index);

// Get the render data for a specific tile
void CesiumTileset_getTileRenderData(CesiumTileset* tileset, int index, void** renderData);

// Get the load state for the tile at the given index
CesiumTileLoadState CesiumTileset_getTileLoadState(CesiumTile* tile);

// Get the type of content for the tile at the given index
CesiumTileContentType CesiumTileset_getTileContentType(CesiumTile* tile);

void CesiumTileset_getRenderableTiles(CesiumTile* cesiumTile, CesiumTilesetRenderableTiles* const out);

int32_t CesiumTileset_getNumberOfTilesLoaded(CesiumTileset* tileset);

CesiumTile* CesiumTileset_getRootTile(CesiumTileset* tileset);

CesiumBoundingVolume CesiumTile_getBoundingVolume(CesiumTile* tile);

double3 CesiumTile_getBoundingVolumeCenter(CesiumTile* tile);

void CesiumTile_traverse(CesiumTile* tile);

// Get a handle to the CesiumGltf::Model object for a given tile
CesiumGltfModel* CesiumTile_getModel(CesiumTile* tile);

// Check if a tile has a valid model
int CesiumTile_hasModel(CesiumTile* tile);

// Get the number of meshes in the model
int32_t CesiumGltfModel_getMeshCount(CesiumGltfModel* model);

// Get the number of materials in the model
int32_t CesiumGltfModel_getMaterialCount(CesiumGltfModel* model);

// Get the number of textures in the model
int32_t CesiumGltfModel_getTextureCount(CesiumGltfModel* model);

uint8_t* CesiumGltfModel_serialize(CesiumGltfModel* opaqueModel, uint32_t* length);

void CesiumGltfModel_free_serialized(uint8_t* serialized);


#ifdef __cplusplus
}
#endif

#endif // CESIUM_TILESET_H