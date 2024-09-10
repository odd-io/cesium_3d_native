#include "CesiumTilesetCApi.h"
#include <Cesium3DTilesSelection/Tileset.h>
#include <Cesium3DTilesSelection/TilesetExternals.h>
#include <CesiumAsync/IAssetAccessor.h>
#include <CesiumAsync/AsyncSystem.h>
#include <memory>
#include <vector>
#include "CurlAssetAccessor.hpp"
#include "PrepareRenderer.hpp"
#include <Cesium3DTilesContent/registerAllTileContentTypes.h>

#include <spdlog/spdlog.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/async.h>
#include <spdlog/sinks/basic_file_sink.h>

extern "C" {

using namespace Cesium3DTilesSelection;

class SimpleTaskProcessor : public CesiumAsync::ITaskProcessor {
public:
  virtual void startTask(std::function<void()> f) override { f(); }
};

struct CesiumTileset {
    std::unique_ptr<Cesium3DTilesSelection::Tileset> tileset;
    Cesium3DTilesSelection::ViewUpdateResult lastUpdateResult;
    bool loadError = false;
    std::string loadErrorMessage;
};

void CesiumTileset_initialize() {
    Cesium3DTilesContent::registerAllTileContentTypes();

    auto console = spdlog::stdout_color_mt("cesium_logger");
    spdlog::set_default_logger(console);

    // Set the log level (optional)
    spdlog::set_level(spdlog::level::info); // Or info, warn, error, etc.

    // Enable backtrace logging (optional)
    spdlog::enable_backtrace(32); // Keep a backtrace of 32 messages

    spdlog::default_logger()->info("Initialized");
}

CesiumTileset* CesiumTileset_create(const char* url) {
    auto pAssetAccessor = std::dynamic_pointer_cast<CesiumAsync::IAssetAccessor>(std::make_shared<CurlAssetAccessor>());
    auto pResourcePreparer = std::dynamic_pointer_cast<Cesium3DTilesSelection::IPrepareRendererResources>(std::make_shared<SimplePrepareRendererResource>());
    CesiumAsync::AsyncSystem asyncSystem{std::make_shared<SimpleTaskProcessor>()};
    auto pMockedCreditSystem = std::make_shared<CesiumUtility::CreditSystem>();

    Cesium3DTilesSelection::TilesetExternals externals {
      pAssetAccessor,
      pResourcePreparer,
      asyncSystem,
      pMockedCreditSystem};

    externals.pAssetAccessor = pAssetAccessor;
    externals.pPrepareRendererResources = pResourcePreparer;

    auto pTileset = new CesiumTileset();
    pTileset->tileset = std::make_unique<Cesium3DTilesSelection::Tileset>(
        externals,
        url
    );
    return pTileset;
}

CesiumTileset* CesiumTileset_createFromIonAsset(int64_t assetId, const char* accessToken) {
    auto pAssetAccessor = std::dynamic_pointer_cast<CesiumAsync::IAssetAccessor>(std::make_shared<CurlAssetAccessor>(accessToken));
    auto pResourcePreparer = std::dynamic_pointer_cast<Cesium3DTilesSelection::IPrepareRendererResources>(std::make_shared<SimplePrepareRendererResource>());
    CesiumAsync::AsyncSystem asyncSystem{std::make_shared<SimpleTaskProcessor>()};
    auto pMockedCreditSystem = std::make_shared<CesiumUtility::CreditSystem>();

    Cesium3DTilesSelection::TilesetExternals externals {
      pAssetAccessor,
      pResourcePreparer,
      asyncSystem,
      pMockedCreditSystem};
    externals.pAssetAccessor = pAssetAccessor;
    externals.pPrepareRendererResources = pResourcePreparer;

    TilesetOptions options;

    
    auto pTileset = new CesiumTileset();
    options.loadErrorCallback = [=](const TilesetLoadFailureDetails& details) {
        pTileset->loadErrorMessage = details.message;
        spdlog::default_logger()->error(details.message);
        pTileset->loadError = true;
    };
    pTileset->tileset = std::make_unique<Cesium3DTilesSelection::Tileset>(
        externals,
        assetId,
        accessToken,
        options
    );
 
    return pTileset;
}

void CesiumTileset_getErrorMessage(CesiumTileset* tileset, char* out) {
    auto message = tileset->loadErrorMessage;
    spdlog::default_logger()->error(tileset->loadErrorMessage);
    spdlog::default_logger()->error("{}", (int64_t)message.c_str());
    
    if(message.length() == 0) {
        memset(out, 0, 255);
    } else {
        int length = message.length();
        if(length > 255) {
            length = 255;
        }
        strncpy(out, message.c_str(), length);
    }
}

void CesiumTileset_destroy(CesiumTileset* tileset) {
    delete tileset;
}

CesiumViewState CesiumTileset_createViewState(double positionX, double positionY, double positionZ, double directionX, double directionY, double directionZ, double upX, double upY, double upZ,
double viewportWidth, double viewportHeight, double horizontalFov) { 
    return CesiumViewState { 
        { positionX, positionY, positionZ },
        { directionX, directionY, directionZ },
        { upX, upY, upZ },
        viewportWidth,
        viewportHeight,
        horizontalFov
    };
}



int CesiumTileset_updateView(CesiumTileset* tileset, const CesiumViewState viewState) {
    if (!tileset) return -1;
    Cesium3DTilesSelection::ViewState cesiumViewState = Cesium3DTilesSelection::ViewState::create(
        glm::dvec3(viewState.position[0], viewState.position[1], viewState.position[2]),
        glm::dvec3(viewState.direction[0], viewState.direction[1], viewState.direction[2]),
        glm::dvec3(viewState.up[0], viewState.up[1], viewState.up[2]),
        glm::dvec2(viewState.viewportWidth, viewState.viewportHeight),
        viewState.horizontalFov,
        viewState.horizontalFov * viewState.viewportHeight / viewState.viewportWidth
    );

    tileset->lastUpdateResult = tileset->tileset->updateView({cesiumViewState});

    int tilesToRender = static_cast<int>(tileset->lastUpdateResult.tilesToRenderThisFrame.size());

    spdlog::default_logger()->info("Tiles to render: {}", tilesToRender);
    return tilesToRender;
}

int CesiumTileset_hasLoadError(CesiumTileset* tileset) {
    return tileset->loadError;
}

int CesiumTileset_getTileCount(CesiumTileset* tileset) {
    if (!tileset) return 0;
    return static_cast<int>(tileset->lastUpdateResult.tilesToRenderThisFrame.size());
}

CesiumTileContentType CesiumTileset_getTileContentType(CesiumTileset* tileset, int index) {
    auto tile = tileset->lastUpdateResult.tilesToRenderThisFrame[index];
    auto state = tile->getState();
    
    if(tile->isEmptyContent()) { 
        return CT_TC_EMPTY;
    } else if(tile->isExternalContent()) {
        return CT_TC_EXTERNAL;
    } else if(tile->isRenderContent()) {
        return CT_TC_RENDER;
    } else {
        auto& content = tile->getContent();
        if(content.isUnknownContent()) {
            return CT_TC_UNKNOWN;
        }
        return CT_TC_ERROR;
    }
}

CesiumTileLoadState CesiumTileset_getTileLoadState(CesiumTile* tile) {
    auto state = ((Cesium3DTilesSelection::Tile*)tile)-> getState();
    return (CesiumTileLoadState)state;
}

void CesiumTileset_getTileData(CesiumTileset* tileset, int index, void** data) {
    if (!tileset || index < 0 || index >= tileset->lastUpdateResult.tilesToRenderThisFrame.size()) {
        *data = nullptr;
        return;
    }

    auto tile = tileset->lastUpdateResult.tilesToRenderThisFrame[index];
    
    auto& content = tile->getContent();
    
    if(content.isRenderContent()) {
        auto renderContent = content.getRenderContent();
        auto model = renderContent->getModel();
        *data = renderContent;
    } else if(content.isExternalContent()) { 
        *data = content.getExternalContent();
    } else {
        *data = nullptr;
    }   
}

void processTileContent(Tile* tile) {
    std::cout << "PROCESSING " << std::endl;
    // const TileContent& content = tile->getContent();
    // if (content.isRenderContent()) {
    //     const TileRenderContent* renderContent = content.getRenderContent();
    //     if (renderContent) {
    //         // Access the glTF model
    //         const CesiumGltf::Model& model = renderContent->getModel();
    //         // Process the model (e.g., render it, extract information, etc.)
    //         // ...
    //     }
    // }
}

void traverseTileset(Tile* tile) {
    // Check if the tile has render content
    // tile->is
    // if (tile->isRenderContent()) {
    // const TileContent& content = tile->getContent();
    // // if (content.isRenderContent()) {
    // //     const TileRenderContent* renderContent = content.getRenderContent();
    // //     if (renderContent) {
    // //         // Access the glTF model
    // //         const CesiumGltf::Model& model = renderContent->getModel();
    // //         // Process the model (e.g., render it, extract information, etc.)
    // //         // ...
    // //     }
    // // }
    // }

    // Recursively process children
    for (Tile& childTile : tile->getChildren()) {
        traverseTileset(&childTile);
    }
}

const TileRenderContent* recursiveGetContent(Tile* tile) {
    // Check if the tile has render content
    if (tile->isRenderContent()) {
        const TileRenderContent* renderContent = tile->getContent().getRenderContent();
        return renderContent;
    }

    // Recursively process children
    for (Tile& childTile : tile->getChildren()) {
        auto result = recursiveGetContent(&childTile);
        if(result) {
            return result;
        }
    }
    return nullptr;
}

void CesiumTileset_checkRoot(CesiumTileset* tileset) {
    auto root = tileset->tileset->getRootTile();
    traverseTileset(root);
}

void* CesiumTileset_getFirstRenderContent(CesiumTile* tile) {
    return (void*) recursiveGetContent((Tile*)tile);
}

CesiumTile* CesiumTileset_getRootTile(CesiumTileset* tileset) {
    auto root = tileset->tileset->getRootTile();
    return (CesiumTile*)root;
}

int32_t CesiumTileset_getNumberOfTilesLoaded(CesiumTileset* tileset) {
    return tileset->tileset->getNumberOfTilesLoaded();
}


}