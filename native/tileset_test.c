#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "CesiumTilesetCApi.h"

#define PI 3.14159265358979323846

void print_tile_info(CesiumTileset* tileset) {
    int tileCount = CesiumTileset_getTileCount(tileset);
    printf("Tiles to render: %d\n", tileCount);

    // for (int i = 0; i < tileCount; ++i) {
    //     CesiumTileLoadState loadState = CesiumTileset_getTileLoadState(tileset->tileset->, i);
    //     CesiumTileContentType ct = CesiumTileset_getTileContentType(tileset, i);
    //     printf(" Tile %d Load State: %d Content Type %d \n", i, loadState, ct);
    // }
    printf("\n");

    CesiumTileset_checkRoot(tileset);

}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <ion_id> <access_token>\n", argv[0]);
        return 1;
    }

    CesiumTileset_initialize();
    const char* assetId = argv[1];
    const char* accessToken = argv[2];

    printf("Creating tileset from ion asset id : %s\n", assetId);

    // Create a tileset
    CesiumTileset* tileset = CesiumTileset_createFromIonAsset(atoi(assetId), accessToken);

    if (!tileset) {
        fprintf(stderr, "Failed to create tileset\n");
        return 1;
    }

    printf("Tileset created successfully\n");

    // Create a view state
    CesiumViewState viewState = {
        .position = {0.0, 0.0, 1000000.0},  // High altitude view
        .direction = {0.0, 0.0, -1.0},      // Looking straight down
        .up = {0.0, 1.0, 0.0},              // Up is aligned with Y-axis
        .viewportWidth = 1920.0,
        .viewportHeight = 1080.0,
        .horizontalFov = 60.0 * PI / 180.0  // 60 degrees in radians
    };
    
    int updatedTiles = CesiumTileset_updateView(tileset, viewState);

    printf("updated %d\n", updatedTiles);

    // // Update view and print tile info for a few frames
    // for (int frame = 0; frame < 5; ++frame) {
    //     printf("Frame %d:\n", frame);

    //     // Update the view (in a real application, you'd update the camera position here)
    //     viewState.position[0] += 1000.0;  // Move the camera a bit each frame
    //     int updatedTiles = CesiumTileset_updateView(tileset, &viewState);

    //     printf("Updated tiles: %d\n", updatedTiles);
    //     print_tile_info(tileset);
    // }

    // auto root = CesiumTileset_getRootTile(tileset);

    // auto renderContent = CesiumTileset_getFirstRenderContent(root);

    // if(renderContent) {
    //     printf("Got render content!");
    // } else { 
    //     printf("No render content!");
    // }

    // // Clean up
    // CesiumTileset_destroy(tileset);
    // printf("Tileset destroyed\n");

    return 0;
}