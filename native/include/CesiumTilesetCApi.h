#ifndef CESIUM_TILESET_H
#define CESIUM_TILESET_H

#define GLM_FORCE_XYZW_ONLY
#define GLM_FORCE_EXPLICIT_CTOR 
#define GLM_FORCE_SIZE_T_LENGTH 

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

// Opaque pointer to the Tileset
typedef struct CesiumTileset CesiumTileset;

// This is copied verbatim from CesiumTileLoadState in Tile.h so we can generate the correct values with Dart ffigen
typedef enum CesiumTileLoadState {
    CT_LS_UNLOADING = -2,
    CT_LS_FAILED_TEMPORARILY = -1,
    CT_LS_UNLOADED = 0,
    CT_LS_CONTENT_LOADING = 1,
    CT_LS_CONTENT_LOADED = 2,
    CT_LS_DONE = 3,
    CT_LS_FAILED = 4,
} CesiumTileLoadState;

// A convenience enum to check what type of content a Tile represents
typedef enum CesiumTileContentType {
    CT_TC_EMPTY,
    CT_TC_RENDER,
    CT_TC_EXTERNAL,
    CT_TC_UNKNOWN,
    CT_TC_ERROR,
} CesiumTileContentType;

// Simplified view state structure
typedef struct {
    double position[3];
    double direction[3];
    double up[3];
    double viewportWidth;
    double viewportHeight;
    double horizontalFov;
} CesiumViewState;

// Initializes all bindings. Must be called before any other CesiumTileset_ function.
void CesiumTileset_initialize();

// Create a Tileset from a URL
CesiumTileset* CesiumTileset_create(const char* url);

// Create a Tileset from a Cesium ion asset
CesiumTileset* CesiumTileset_createFromIonAsset(int64_t assetId, const char* accessToken);

// Destroy a Tileset
void CesiumTileset_destroy(CesiumTileset* tileset);

// Update the view and get tiles to render
int CesiumTileset_updateView(CesiumTileset* tileset, const CesiumViewState* viewState);

// Get the number of tiles to render after updating the view
int CesiumTileset_getTileCount(const CesiumTileset* tileset);

// Get the render data for a specific tile
void CesiumTileset_getTileRenderData(const CesiumTileset* tileset, int index, void** renderData);

// Get the load state for the tile at the given index
CesiumTileLoadState CesiumTileset_getTileLoadState(const CesiumTileset* tileset, int index);

// Get the type of content for the tile at the given index
CesiumTileContentType CesiumTileset_getTileContentType(const CesiumTileset* tileset, int index);

#ifdef __cplusplus
}
#endif

#endif // CESIUM_TILESET_H