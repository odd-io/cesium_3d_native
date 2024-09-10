#include "CesiumTilesetCApi.h"
#include <Cesium3DTilesSelection/Tileset.h>
#include <Cesium3DTilesSelection/TilesetExternals.h>
#include <CesiumAsync/IAssetAccessor.h>
#include <CesiumAsync/AsyncSystem.h>

#include <memory>
#include <optional>
#include <vector>

#include "CurlAssetAccessor.hpp"
#include "PrepareRenderer.hpp"
#include <Cesium3DTilesContent/registerAllTileContentTypes.h>



#include <spdlog/spdlog.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/async.h>
#include <spdlog/sinks/basic_file_sink.h>

#include <Cesium3DTilesSelection/BoundingVolume.h>
#include <CesiumGeometry/BoundingSphere.h>
#include <CesiumGeometry/OrientedBoundingBox.h>
#include <CesiumGeospatial/BoundingRegion.h>

extern "C" {

using namespace Cesium3DTilesSelection;

class SimpleTaskProcessor : public CesiumAsync::ITaskProcessor {
public:
  virtual void startTask(std::function<void()> f) override { 
    f(); 
  }
};

struct CesiumTileset {
    std::unique_ptr<Cesium3DTilesSelection::Tileset> tileset;
    Cesium3DTilesSelection::ViewUpdateResult lastUpdateResult;
    bool loadError = false;
    std::string loadErrorMessage;
};

// Helper function to convert Cesium's glm::dvec3 to our double3
double3 glmTodouble3(const glm::dvec3& vec) {
    return {vec.x, vec.y, vec.z};
}

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

    asyncSystem.dispatchMainThreadTasks();
 
    return pTileset;
}

void CesiumTileset_getErrorMessage(CesiumTileset* tileset, char* out) {
    auto message = tileset->loadErrorMessage;
       
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

    // spdlog::default_logger()->info("queue len {}", tileset->lastUpdateResult.workerThreadTileLoadQueueLength);
    // spdlog::default_logger()->info("mainThreadTileLoadQueueLength {}", tileset->lastUpdateResult.mainThreadTileLoadQueueLength);
    // spdlog::default_logger()->info("tilesVisited {}", tileset->lastUpdateResult.tilesVisited);
    // spdlog::default_logger()->info("culledTilesVisited {}", tileset->lastUpdateResult.culledTilesVisited);
    // spdlog::default_logger()->info("tilesCulled {}", tileset->lastUpdateResult.tilesCulled);
    // spdlog::default_logger()->info("tilesOccluded {}", tileset->lastUpdateResult.tilesOccluded);
    // spdlog::default_logger()->info("tilesKicked {}", tileset->lastUpdateResult.tilesKicked);
    // spdlog::default_logger()->info("tilesWaitingForOcclusionResults {}", tileset->lastUpdateResult.tilesWaitingForOcclusionResults);
  
    int tilesToRender = static_cast<int>(tileset->lastUpdateResult.tilesToRenderThisFrame.size());

    return tilesToRender;
}

int CesiumTileset_hasLoadError(CesiumTileset* tileset) {
    return tileset->loadError;
}

CesiumTile* CesiumTileset_getTileToRenderThisFrame(CesiumTileset* tileset, int index) {
    if(index > tileset->lastUpdateResult.tilesToRenderThisFrame.size()) {
        return nullptr;
    }
    return (CesiumTile*)tileset->lastUpdateResult.tilesToRenderThisFrame[index];
}

int CesiumTileset_getTileCount(CesiumTileset* tileset) {
    if (!tileset) return 0;
    return static_cast<int>(tileset->lastUpdateResult.tilesToRenderThisFrame.size());
}

void CesiumTileset_loadTile(CesiumTile* cesiumTile) {
    auto tile = (Tile*)cesiumTile;
    auto state = tile->getState();

    spdlog::default_logger()->info("Load state: {}", (int)state);
    return;

    if(state == TileLoadState::Done) {
        spdlog::default_logger()->info("Tile loaded, ignoring.");
        return;
    }

    auto pAssetAccessor = std::dynamic_pointer_cast<CesiumAsync::IAssetAccessor>(std::make_shared<CurlAssetAccessor>(""));
    auto pResourcePreparer = std::dynamic_pointer_cast<Cesium3DTilesSelection::IPrepareRendererResources>(std::make_shared<SimplePrepareRendererResource>());
    CesiumAsync::AsyncSystem asyncSystem{std::make_shared<SimpleTaskProcessor>()};
    auto pMockedCreditSystem = std::make_shared<CesiumUtility::CreditSystem>();
        
    TilesetContentOptions contentOptions;
    std::vector<CesiumAsync::IAssetAccessor::THeader> requestHeaders;
    Cesium3DTilesSelection::TileLoadInput input { *tile, contentOptions, asyncSystem, pAssetAccessor, spdlog::default_logger(), requestHeaders };        
    auto loader = tile->getLoader();
    
    auto loadResult = loader->loadTileContent(input);
    
    asyncSystem.dispatchMainThreadTasks();

    auto tileLoadResult = loadResult.wait();
    
    state = tile->getState();
    spdlog::default_logger()->info("New Load State : {}", (int)state);
}   

CesiumTileContentType CesiumTileset_getTileContentType(CesiumTile* cesiumTile) {
    auto tile = (Tile*)cesiumTile;
    auto state = tile->getState();

    CesiumTileset_loadTile(cesiumTile);
        
    if(tile->isEmptyContent()) { 
        auto& content = tile->getContent();
        auto ext = content.getExternalContent();

        spdlog::default_logger()->info("EMPTY");
        return CT_TC_EMPTY;
    } else if(tile->isExternalContent()) {
        spdlog::default_logger()->info("EXTERNAL");
        auto content = tile->getContent().getExternalContent();
        auto metadata = content->metadata;
        spdlog::default_logger()->info("{}", metadata.schemaUri.value_or("No schema URI"));
        if(metadata.schema) {
            spdlog::default_logger()->info("Has schema!");
        } else { 
            spdlog::default_logger()->info("No schema");
            if(metadata.metadata) {
                spdlog::default_logger()->info("Has metadata");
            } else {
                spdlog::default_logger()->info("No metadata");
            }

            spdlog::default_logger()->info("{} groups", metadata.groups.size());;
        }
        
        
        
        return CT_TC_EXTERNAL;
    } else if(tile->isRenderContent()) {
        spdlog::default_logger()->info("RENDER");
        return CT_TC_RENDER;
    } else {
        auto& content = tile->getContent();
        if(content.isUnknownContent()) {

            spdlog::default_logger()->info("UNKNOWN");
            return CT_TC_UNKNOWN;
        }
        spdlog::default_logger()->info("ERROR");
        return CT_TC_ERROR;
    }
}

CesiumTileLoadState CesiumTileset_getTileLoadState(CesiumTile* tile) {
    auto state = ((Cesium3DTilesSelection::Tile*)tile)-> getState();
    return (CesiumTileLoadState)state;
}

void recursiveGetContent(Tile* tile, std::vector<const TileRenderContent*>& renderable) {
    // Check if the tile has render content
    if (tile->isRenderContent()) {
        const TileRenderContent* renderContent = tile->getContent().getRenderContent();
        renderable.push_back(renderContent);
    }

    // Recursively process children
    for (Tile& childTile : tile->getChildren()) {
        recursiveGetContent(&childTile, renderable);
    }
}

int CesiumTileset_getNumTilesLoaded(CesiumTileset* tileset) {
    return tileset->tileset->getNumberOfTilesLoaded();
}

void CesiumTileset_getRenderableTiles(CesiumTile* cesiumTile, CesiumTilesetRenderContentTraversalResult* out) {
    std::vector<const TileRenderContent*> content;
    recursiveGetContent((Tile*)cesiumTile, content);
    (*out).numRenderContent = (int32_t)content.size();
    memcpy((void*)out->renderContent, content.data(), content.size());
}

CesiumTile* CesiumTileset_getRootTile(CesiumTileset* tileset) {
    auto root = tileset->tileset->getRootTile();
    return (CesiumTile*)root;
}

int32_t CesiumTileset_getNumberOfTilesLoaded(CesiumTileset* tileset) {
    return tileset->tileset->getNumberOfTilesLoaded();
}

CesiumBoundingVolume CesiumTile_getBoundingVolume(CesiumTile* cesiumTile) {
    Cesium3DTilesSelection::Tile* tile = reinterpret_cast<Cesium3DTilesSelection::Tile*>(cesiumTile);
    const Cesium3DTilesSelection::BoundingVolume& bv = tile->getBoundingVolume();
    
    CesiumBoundingVolume result;

    if (std::holds_alternative<CesiumGeometry::BoundingSphere>(bv)) {
        const auto& sphere = std::get<CesiumGeometry::BoundingSphere>(bv);
        result.type = CT_BV_SPHERE;
        result.volume.sphere.center[0] = sphere.getCenter().x;
        result.volume.sphere.center[1] = sphere.getCenter().y;
        result.volume.sphere.center[2] = sphere.getCenter().z;
        result.volume.sphere.radius = sphere.getRadius();
    }
    else if (std::holds_alternative<CesiumGeometry::OrientedBoundingBox>(bv)) {
        const auto& obb = std::get<CesiumGeometry::OrientedBoundingBox>(bv);
        result.type = CT_BV_ORIENTED_BOX;
        result.volume.orientedBox.center[0] = obb.getCenter().x;
        result.volume.orientedBox.center[1] = obb.getCenter().y;
        result.volume.orientedBox.center[2] = obb.getCenter().z;
        for (int i = 0; i < 9; ++i) {
            auto axis =obb.getHalfAxes()[i / 3];
            result.volume.orientedBox.halfAxes[i] = axis[i % 3];
        }
    }
    else if (std::holds_alternative<CesiumGeospatial::BoundingRegion>(bv)) {
        const auto& region = std::get<CesiumGeospatial::BoundingRegion>(bv);
        result.type = CT_BV_REGION;
        result.volume.region.west = region.getRectangle().getWest();
        result.volume.region.south = region.getRectangle().getSouth();
        result.volume.region.east = region.getRectangle().getEast();
        result.volume.region.north = region.getRectangle().getNorth();
        result.volume.region.minimumHeight = region.getMinimumHeight();
        result.volume.region.maximumHeight = region.getMaximumHeight();
    }
    else {
        // Handle unexpected bounding volume type
        result.type = CT_BV_SPHERE;
        result.volume.sphere = {{0, 0, 0}, 0};
    }

    return result;
}

double3 CesiumTile_getBoundingVolumeCenter(CesiumTile* cesiumTile) {
    Cesium3DTilesSelection::Tile* tile = reinterpret_cast<Cesium3DTilesSelection::Tile*>(cesiumTile);
    const Cesium3DTilesSelection::BoundingVolume& bv = tile->getBoundingVolume();
    
    glm::dvec3 center;

    if (std::holds_alternative<CesiumGeometry::BoundingSphere>(bv)) {
        center = std::get<CesiumGeometry::BoundingSphere>(bv).getCenter();
    }
    else if (std::holds_alternative<CesiumGeometry::OrientedBoundingBox>(bv)) {
        center = std::get<CesiumGeometry::OrientedBoundingBox>(bv).getCenter();
    }
    else if (std::holds_alternative<CesiumGeospatial::BoundingRegion>(bv)) {
        const auto& region = std::get<CesiumGeospatial::BoundingRegion>(bv);
        // For a bounding region, we'll use the center of the region at the average height
        center = region.getBoundingBox().getCenter();
    }
    else {
        // Handle unexpected bounding volume type
        center = glm::dvec3(0.0, 0.0, 0.0);
    }

    return glmTodouble3(center);
}

void CesiumTile_traverse(CesiumTile* cesiumTile) {
    auto tile = (Tile*)cesiumTile;
    spdlog::default_logger()->info("Traversing tile with {} children", tile->getChildren().size());
    CesiumTileset_getTileContentType(cesiumTile);
    // Recursively process children
    for (Tile& childTile : tile->getChildren()) {
        CesiumTile_traverse((CesiumTile*) &childTile);
    }
}

}