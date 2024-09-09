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

// Simplified view state structure
typedef struct {
    double position[3];
    double direction[3];
    double up[3];
    double viewportWidth;
    double viewportHeight;
    double horizontalFov;
} CesiumViewState;

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

#ifdef __cplusplus
}
#endif

#endif // CESIUM_TILESET_H