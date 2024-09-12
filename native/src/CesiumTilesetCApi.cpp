#include "CesiumTilesetCApi.h"

#include <Cesium3DTilesSelection/Tileset.h>
#include <Cesium3DTilesSelection/TilesetExternals.h>
#include <CesiumAsync/IAssetAccessor.h>
#include <CesiumAsync/AsyncSystem.h>
#include <Cesium3DTilesContent/registerAllTileContentTypes.h>
#include <Cesium3DTilesSelection/BoundingVolume.h>
#include <CesiumGeometry/BoundingSphere.h>
#include <CesiumGeometry/OrientedBoundingBox.h>
#include <CesiumGeospatial/BoundingRegion.h>
#include <CesiumGltfWriter/GltfWriter.h>

#include <memory>
#include <optional>
#include <vector>
#include <set>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <atomic>
#include <functional>

#include "CurlAssetAccessor.hpp"
#include "PrepareRenderer.hpp"

#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/buffer.h>
#include <string>
#include <cstring>


#include <spdlog/spdlog.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/async.h>
#include <spdlog/sinks/basic_file_sink.h>


extern "C" {

using namespace Cesium3DTilesSelection;

#include <queue>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <atomic>
#include <functional>

class SimpleTaskProcessor : public CesiumAsync::ITaskProcessor {
public:
    SimpleTaskProcessor() : running(true) {
        workerThread = std::thread(&SimpleTaskProcessor::processJobs, this);
    }

    ~SimpleTaskProcessor() {
        {
            std::unique_lock<std::mutex> lock(queueMutex);
            running = false;
            condition.notify_one();
        }
        if (workerThread.joinable()) {
            workerThread.join();
        }
    }

    virtual void startTask(std::function<void()> f) override {
        std::unique_lock<std::mutex> lock(queueMutex);
        jobQueue.push(std::move(f));
        condition.notify_one();
    }

private:
    void processJobs() {
        while (running) {
            std::function<void()> job;
            {
                std::unique_lock<std::mutex> lock(queueMutex);
                condition.wait(lock, [this] { return !jobQueue.empty() || !running; });
                if (!running && jobQueue.empty()) {
                    return;
                }
                job = std::move(jobQueue.front());
                jobQueue.pop();
            }
            job();
        }
    }

    std::queue<std::function<void()>> jobQueue;
    std::mutex queueMutex;
    std::condition_variable condition;
    std::thread workerThread;
    std::atomic<bool> running;
};

// class SimpleTaskProcessor : public CesiumAsync::ITaskProcessor {
// public:
//   virtual void startTask(std::function<void()> f) override { 
//     f(); 
//   }
// };

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

// CesiumTileset_initialize() only needs to be called once over the lifetime of an application.
// Specifically, the API does not need re-initializiang after a Dart/Flutter hot reload.
// This flag is set to true after the first call to CesiumTileset_initialize(); all subsequent calls will be ignored.
static bool _initialized = false;
static CesiumAsync::AsyncSystem asyncSystem { nullptr };
void CesiumTileset_initialize() {
    if(_initialized) {
        return;
    }
 
    asyncSystem = CesiumAsync::AsyncSystem {  std::make_shared<SimpleTaskProcessor>() };

    auto console = spdlog::stdout_color_mt("cesium_logger");
    spdlog::set_default_logger(console);

    // Set the log level (optional)
    spdlog::set_level(spdlog::level::info); // Or info, warn, error, etc.

    // Enable backtrace logging (optional)
    spdlog::enable_backtrace(32); // Keep a backtrace of 32 messages
    
    Cesium3DTilesContent::registerAllTileContentTypes();
    
    spdlog::default_logger()->info("Cesium Native bindings initialized");

    _initialized = true;

}

CesiumTileset* CesiumTileset_create(const char* url, void(*onRootTileAvailableEvent)()) {
    auto pAssetAccessor = std::dynamic_pointer_cast<CesiumAsync::IAssetAccessor>(std::make_shared<CurlAssetAccessor>());
    auto pResourcePreparer = std::dynamic_pointer_cast<Cesium3DTilesSelection::IPrepareRendererResources>(std::make_shared<SimplePrepareRendererResource>());
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
        url,
        options
    );
    
    pTileset->tileset->getRootTileAvailableEvent().thenInMainThread([=]() { 
        onRootTileAvailableEvent();
    });
   
    asyncSystem.dispatchMainThreadTasks();
    return pTileset;
}

CesiumTileset* CesiumTileset_createFromIonAsset(int64_t assetId, const char* accessToken, void(*onRootTileAvailableEvent)()) {
    auto pAssetAccessor = std::dynamic_pointer_cast<CesiumAsync::IAssetAccessor>(std::make_shared<CurlAssetAccessor>(accessToken));
    auto pResourcePreparer = std::dynamic_pointer_cast<Cesium3DTilesSelection::IPrepareRendererResources>(std::make_shared<SimplePrepareRendererResource>());
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

    pTileset->tileset->getRootTileAvailableEvent().thenInMainThread([=]() { 
        onRootTileAvailableEvent();
    });
   
    asyncSystem.dispatchMainThreadTasks();
     
    return pTileset;
}

void CesiumTileset_pumpAsyncQueue() { 
    asyncSystem.dispatchMainThreadTasks();
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

int CesiumTileset_updateView(CesiumTileset* tileset, const CesiumViewState viewState, float deltaTime) {
    if (!tileset) return -1;

    Cesium3DTilesSelection::ViewState cesiumViewState = Cesium3DTilesSelection::ViewState::create(
        glm::dvec3(viewState.position[0], viewState.position[1], viewState.position[2]),
        glm::dvec3(viewState.direction[0], viewState.direction[1], viewState.direction[2]),
        glm::dvec3(viewState.up[0], viewState.up[1], viewState.up[2]),
        glm::dvec2(viewState.viewportWidth, viewState.viewportHeight),
        viewState.horizontalFov,
        viewState.horizontalFov * viewState.viewportHeight / viewState.viewportWidth
    );

    tileset->lastUpdateResult = tileset->tileset->updateView({cesiumViewState}, deltaTime);
    // spdlog::default_logger()->info("load progress {}", tileset->tileset->computeLoadProgress());
    // spdlog::default_logger()->info("queue len {}", tileset->lastUpdateResult.workerThreadTileLoadQueueLength);
    // spdlog::default_logger()->info("mainThreadTileLoadQueueLength {}", tileset->lastUpdateResult.mainThreadTileLoadQueueLength);
    // spdlog::default_logger()->info("tilesVisited {}", tileset->lastUpdateResult.tilesVisited);
    // spdlog::default_logger()->info("culledTilesVisited {}", tileset->lastUpdateResult.culledTilesVisited);
    // spdlog::default_logger()->info("tilesCulled {}", tileset->lastUpdateResult.tilesCulled);
    // spdlog::default_logger()->info("tilesOccluded {}", tileset->lastUpdateResult.tilesOccluded);
    // spdlog::default_logger()->info("tilesKicked {}", tileset->lastUpdateResult.tilesKicked);
    // spdlog::default_logger()->info("tilesWaitingForOcclusionResults {}", tileset->lastUpdateResult.tilesWaitingForOcclusionResults);
  
    return static_cast<int>(tileset->lastUpdateResult.tilesToRenderThisFrame.size());
}

int CesiumTileset_getTilesKicked(CesiumTileset* tileset) {
    return static_cast<int>(tileset->lastUpdateResult.tilesKicked);
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
        // spdlog::default_logger()->info("Tile loaded, ignoring.");
        return;
    }

    auto pAssetAccessor = std::dynamic_pointer_cast<CesiumAsync::IAssetAccessor>(std::make_shared<CurlAssetAccessor>(""));
    auto pResourcePreparer = std::dynamic_pointer_cast<Cesium3DTilesSelection::IPrepareRendererResources>(std::make_shared<SimplePrepareRendererResource>());

    auto pMockedCreditSystem = std::make_shared<CesiumUtility::CreditSystem>();
        
    TilesetContentOptions contentOptions;
    std::vector<CesiumAsync::IAssetAccessor::THeader> requestHeaders;
    Cesium3DTilesSelection::TileLoadInput input { *tile, contentOptions, asyncSystem, pAssetAccessor, spdlog::default_logger(), requestHeaders };        
    auto loader = tile->getLoader();
    
    auto loadResult = loader->loadTileContent(input);
    
    asyncSystem.dispatchMainThreadTasks();

}   

CesiumTileContentType CesiumTileset_getTileContentType(CesiumTile* cesiumTile) {
    auto tile = (Tile*)cesiumTile;
    auto state = tile->getState();
        
    if(tile->isEmptyContent()) { 
        auto& content = tile->getContent();
        auto ext = content.getExternalContent();
        // spdlog::default_logger()->info("EMPTY");
        return CT_TC_EMPTY;
    } else if(tile->isExternalContent()) {
        // spdlog::default_logger()->info("EXTERNAL");
        auto content = tile->getContent().getExternalContent();
        auto metadata = content->metadata;
        // spdlog::default_logger()->info("{}", metadata.schemaUri.value_or("No schema URI"));
        // if(metadata.schema) {
        //     spdlog::default_logger()->info("Has schema!");
        // } else { 
        //     spdlog::default_logger()->info("No schema");
        //     if(metadata.metadata) {
        //         spdlog::default_logger()->info("Has metadata");
        //     } else {
        //         spdlog::default_logger()->info("No metadata");
        //     }

        //     spdlog::default_logger()->info("{} groups", metadata.groups.size());;
        // }
        return CT_TC_EXTERNAL;
    } else if(tile->isRenderContent()) {
        // spdlog::default_logger()->info("RENDER");
        return CT_TC_RENDER;
    } else {
        auto& content = tile->getContent();
        if(content.isUnknownContent()) {
            // spdlog::default_logger()->info("UNKNOWN");
            return CT_TC_UNKNOWN;
        }
        // spdlog::default_logger()->info("ERROR");
        return CT_TC_ERROR;
    }
}

CesiumTileLoadState CesiumTileset_getTileLoadState(CesiumTile* tile) {
    auto state = ((Cesium3DTilesSelection::Tile*)tile)-> getState();
    return (CesiumTileLoadState)state;
}

int CesiumTileset_getNumTilesLoaded(CesiumTileset* tileset) {
    return tileset->tileset->getNumberOfTilesLoaded();
}

static void recurse(Tile* tile, const std::function<void(Tile* const)>& visitor) {
    visitor(tile);
    
    for (Tile& childTile : tile->getChildren()) {
        recurse(&childTile, visitor);
    }
}

void CesiumTileset_getRenderableTiles(CesiumTile* cesiumTile, CesiumTilesetRenderableTiles* const out) {
    std::set<const Tile* const> content;
    auto* tile = reinterpret_cast<Tile*>(cesiumTile);
    const auto& visitor = [&](Tile* const tile) {
        if(tile->isRenderContent()) {
            content.insert(tile);
        }
    };
    recurse(tile, visitor);
    out->numTiles = (int32_t)content.size();
    if(out->numTiles > out->maxSize) {
        out->numTiles = out->maxSize;
    }
    int i = 0;
    for(auto it =content.begin(); it != content.end(); it++) {
        out->tiles[i] = reinterpret_cast<const CesiumTile* const>(*it);
        i++;
    }
}

CesiumTile* CesiumTileset_getRootTile(CesiumTileset* tileset) {
    auto root = tileset->tileset->getRootTile();
    return (CesiumTile*)root;
}

int32_t CesiumTileset_getNumberOfTilesLoaded(CesiumTileset* tileset) {
    return tileset->tileset->getNumberOfTilesLoaded();
}

double4x4 CesiumTile_getTransform(CesiumTile* cesiumTile) {
    Cesium3DTilesSelection::Tile* tile = reinterpret_cast<Cesium3DTilesSelection::Tile*>(cesiumTile);

    auto transform = tile->getTransform();
    return double4x4 {
        transform[0][0],
        transform[0][1],
        transform[0][2],
        transform[0][3],
        transform[1][0],
        transform[1][1],
        transform[1][2],
        transform[1][3],
        transform[2][0],
        transform[2][1],
        transform[2][2],
        transform[2][3],
        transform[3][0],
        transform[3][1],
        transform[3][2],
        transform[3][3],
    };
}


CesiumBoundingVolume CesiumTile_getBoundingVolume(CesiumTile* cesiumTile, bool convertToOrientedBox) {
    Cesium3DTilesSelection::Tile* tile = reinterpret_cast<Cesium3DTilesSelection::Tile*>(cesiumTile);
    const Cesium3DTilesSelection::BoundingVolume& bv = tile->getBoundingVolume();
    
    CesiumBoundingVolume result;

    if (std::holds_alternative<CesiumGeometry::BoundingSphere>(bv)) {
        spdlog::default_logger()->info("SPHERE");
        const auto& sphere = std::get<CesiumGeometry::BoundingSphere>(bv);
        result.type = CT_BV_SPHERE;
        result.volume.sphere.center[0] = sphere.getCenter().x;
        result.volume.sphere.center[1] = sphere.getCenter().y;
        result.volume.sphere.center[2] = sphere.getCenter().z;
        result.volume.sphere.radius = sphere.getRadius();
    }
    else if (std::holds_alternative<CesiumGeometry::OrientedBoundingBox>(bv)) {
        spdlog::default_logger()->info("OBB");
        const auto& obb = std::get<CesiumGeometry::OrientedBoundingBox>(bv);
        result.type = CT_BV_ORIENTED_BOX;
        result.volume.orientedBox.center[0] = obb.getCenter().x;
        result.volume.orientedBox.center[1] = obb.getCenter().y;
        result.volume.orientedBox.center[2] = obb.getCenter().z;
        for(int i = 0; i < 3; i++) {
            auto axis = obb.getHalfAxes()[i];
            for (int j = 0; j < 3; ++j) {
                result.volume.orientedBox.halfAxes[(i*3)+j] = axis[j];
            }
        }
    }
    else if (std::holds_alternative<CesiumGeospatial::BoundingRegion>(bv)) {
        spdlog::default_logger()->info("REGION");
        const auto& region = std::get<CesiumGeospatial::BoundingRegion>(bv);
        
        if(convertToOrientedBox) {
            auto obb = region.getBoundingBox();
            result.type = CT_BV_ORIENTED_BOX;
            result.volume.orientedBox.center[0] = obb.getCenter().x;
            result.volume.orientedBox.center[1] = obb.getCenter().y;
            result.volume.orientedBox.center[2] = obb.getCenter().z;
            for(int i = 0; i < 3; i++) {
                auto axis = obb.getHalfAxes()[i];
                for (int j = 0; j < 3; ++j) {
                    result.volume.orientedBox.halfAxes[(i*3)+j] = axis[j];
                }
            }
        } else {
            result.type = CT_BV_REGION;
            result.volume.region.west = region.getRectangle().getWest();
            result.volume.region.south = region.getRectangle().getSouth();
            result.volume.region.east = region.getRectangle().getEast();
            result.volume.region.north = region.getRectangle().getNorth();
            result.volume.region.minimumHeight = region.getMinimumHeight();
            result.volume.region.maximumHeight = region.getMaximumHeight();
        }
    }
    else if (std::holds_alternative<CesiumGeospatial::BoundingRegionWithLooseFittingHeights>(bv)) {
        spdlog::default_logger()->info("REGION LOOSE");
        const auto& region = std::get<CesiumGeospatial::BoundingRegionWithLooseFittingHeights>(bv);
             if(convertToOrientedBox) {
            auto obb = region.getBoundingRegion().getBoundingBox();
            result.type = CT_BV_ORIENTED_BOX;
            result.volume.orientedBox.center[0] = obb.getCenter().x;
            result.volume.orientedBox.center[1] = obb.getCenter().y;
            result.volume.orientedBox.center[2] = obb.getCenter().z;
            for(int i = 0; i < 3; i++) {
                auto axis = obb.getHalfAxes()[i];
                for (int j = 0; j < 3; ++j) {
                    result.volume.orientedBox.halfAxes[(i*3)+j] = axis[j];
                }
            }
        } else {
            result.type = CT_BV_REGION;
            result.volume.region.west = region.getBoundingRegion().getRectangle().getWest();
            result.volume.region.south = region.getBoundingRegion().getRectangle().getSouth();
            result.volume.region.east = region.getBoundingRegion().getRectangle().getEast();
            result.volume.region.north = region.getBoundingRegion().getRectangle().getNorth();
            result.volume.region.minimumHeight = region.getBoundingRegion().getMinimumHeight();
            result.volume.region.maximumHeight = region.getBoundingRegion().getMaximumHeight();
        }
    }
    else {
        spdlog::default_logger()->info("OTHER");
        // Handle unexpected bounding volume type
        result.type = CT_BV_SPHERE;
        result.volume.sphere = {{0, 0, 0}, 0};
    }

    return result;
}

double CesiumTile_squaredDistanceToBoundingVolume(CesiumTile* oTile, CesiumViewState oViewState) {
    Cesium3DTilesSelection::ViewState viewState = Cesium3DTilesSelection::ViewState::create(
        glm::dvec3(oViewState.position[0], oViewState.position[1], oViewState.position[2]),
        glm::dvec3(oViewState.direction[0], oViewState.direction[1], oViewState.direction[2]),
        glm::dvec3(oViewState.up[0], oViewState.up[1], oViewState.up[2]),
        glm::dvec2(oViewState.viewportWidth, oViewState.viewportHeight),
        oViewState.horizontalFov,
        oViewState.horizontalFov * oViewState.viewportHeight / oViewState.viewportWidth
    );
    
    Cesium3DTilesSelection::Tile* tile = reinterpret_cast<Cesium3DTilesSelection::Tile*>(oTile);
    return viewState.computeDistanceSquaredToBoundingVolume(tile->getBoundingVolume());
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
    auto tile = reinterpret_cast<Cesium3DTilesSelection::Tile*>(cesiumTile);
    
    if(CesiumTileset_getTileContentType(cesiumTile) == CT_TC_RENDER) {
        spdlog::default_logger()->info("Loading render tile");
        auto& content = tile->getContent();
        auto renderContent = content.getRenderContent();

        if(!renderContent) {
            spdlog::default_logger()->info("No render content");
        } else { 
            auto model = renderContent->getModel();            
            // spdlog::default_logger()->info("Got model with {} buffers", model.buffers.size());
        }
        // CesiumTileset_loadTile(cesiumTile);
    }
    
    // Recursively process children
    for (Tile& childTile : tile->getChildren()) {
        CesiumTile_traverse((CesiumTile*) &childTile);
    }
}

CesiumGltfModel* CesiumTile_getModel(CesiumTile* tile) {
    Cesium3DTilesSelection::Tile* cesiumTile = reinterpret_cast<Cesium3DTilesSelection::Tile*>(tile);
    if (cesiumTile->isRenderContent()) {
        const auto& content = cesiumTile->getContent();
        const auto* renderContent = content.getRenderContent();
        if (renderContent) {
            return reinterpret_cast<CesiumGltfModel*>(const_cast<CesiumGltf::Model*>(&renderContent->getModel()));
        }
    }
    return nullptr;
}

int CesiumTile_hasModel(CesiumTile* tile) {
    return CesiumTile_getModel(tile) != nullptr;
}

int32_t CesiumGltfModel_getMeshCount(CesiumGltfModel* model) {
    if (!model) return 0;
    const CesiumGltf::Model* gltfModel = reinterpret_cast<const CesiumGltf::Model*>(model);
    return static_cast<int32_t>(gltfModel->meshes.size());
}

int32_t CesiumGltfModel_getMaterialCount(CesiumGltfModel* model) {
    if (!model) return 0;
    const CesiumGltf::Model* gltfModel = reinterpret_cast<const CesiumGltf::Model*>(model);
    return static_cast<int32_t>(gltfModel->materials.size());
}

int32_t CesiumGltfModel_getTextureCount(CesiumGltfModel* model) {
    if (!model) return 0;
    const CesiumGltf::Model* gltfModel = reinterpret_cast<const CesiumGltf::Model*>(model);
    return static_cast<int32_t>(gltfModel->textures.size());
}

std::string base64_encode(const unsigned char* input, int length) {
    BIO *bio, *b64;
    BUF_MEM *bufferPtr;

    b64 = BIO_new(BIO_f_base64());
    bio = BIO_new(BIO_s_mem());
    bio = BIO_push(b64, bio);

    BIO_set_flags(bio, BIO_FLAGS_BASE64_NO_NL); // Ignore newlines - write everything in one line
    BIO_write(bio, input, length);
    BIO_flush(bio);
    BIO_get_mem_ptr(bio, &bufferPtr);
    BIO_set_close(bio, BIO_NOCLOSE);
    BIO_free_all(bio);

    std::string output(bufferPtr->data, bufferPtr->length);
    BUF_MEM_free(bufferPtr);

    return output;
}

uint8_t* CesiumGltfModel_serialize_to_data_uri(CesiumGltfModel* opaqueModel, uint32_t* length) {
    CesiumGltfWriter::GltfWriter writer;

    auto model = reinterpret_cast<CesiumGltf::Model*>(opaqueModel);
    
    std::vector<std::byte> bufferData;
    for (CesiumGltf::Buffer& buffer : model->buffers) {
         if(buffer.uri) {
            spdlog::default_logger()->error(buffer.uri.value());
            spdlog::default_logger()->flush();
            exit(-1);
        } else {
            std::string base64Data = base64_encode(
                reinterpret_cast<const unsigned char*>(buffer.cesium.data.data()),
                buffer.cesium.data.size()
            );
            std::string newString("data:application/octet-stream;base64," + base64Data);
            buffer.uri.emplace(newString);
        } 
    }
  
    CesiumGltfWriter::GltfWriterOptions options;
    options.binaryChunkByteAlignment = 4;  
    options.prettyPrint = false;
    
    // since we've stored all buffer data in the URI property, we don't need to store the 
    auto result = writer.writeGlb(*model, gsl::span<const std::byte>(bufferData), options);

    for(auto& err : result.errors) { 
        spdlog::default_logger()->error(err);
    }

    for(auto& msg : result.warnings) { 
        spdlog::default_logger()->warn(msg);
    }

    uint8_t* serialized = (uint8_t*) calloc(result.gltfBytes.size(), 1);

    memcpy(serialized, result.gltfBytes.data(), result.gltfBytes.size());

    *length = result.gltfBytes.size();

    return serialized;
    
}

uint8_t* CesiumGltfModel_serialize(CesiumGltfModel* opaqueModel, uint32_t* length) {
    CesiumGltfWriter::GltfWriter writer;

    auto model = reinterpret_cast<CesiumGltf::Model*>(opaqueModel);
    
    // The glb format only permits a single BIN chunk.
    // We therefore need to concatenate all buffer data and update the bufferView so that:
    // - the buffer index always points to zero
    // - the offset is now relative to the start of this buffer
    std::vector<int64_t> offsets;
    int64_t offset = 0;
    std::vector<std::byte> bufferData;
    for (CesiumGltf::Buffer& buffer : model->buffers) {
        if(buffer.uri) {
            spdlog::default_logger()->error(buffer.uri.value());
            spdlog::default_logger()->flush();
            exit(-1);
        }
        offsets.push_back(offset);
        offset += buffer.byteLength;
        bufferData.insert(bufferData.end(), buffer.cesium.data.begin(), buffer.cesium.data.end());
    }

    for (CesiumGltf::BufferView& bufferView : model->bufferViews) {
        int offset = offsets[bufferView.buffer];
        bufferView.byteOffset += offset;
        bufferView.buffer = 0;
    }

    CesiumGltfWriter::GltfWriterOptions options;
    options.binaryChunkByteAlignment = 4;  
    options.prettyPrint = false;
    
    // since we've stored all buffer data in the URI property, we don't need to store the 
    auto result = writer.writeGlb(*model, gsl::span<const std::byte>(bufferData), options);

    for(auto& err : result.errors) { 
        spdlog::default_logger()->error(err);
    }

    for(auto& msg : result.warnings) { 
        spdlog::default_logger()->warn(msg);
    }

    uint8_t* serialized = (uint8_t*) calloc(result.gltfBytes.size(), 1);

    memcpy(serialized, result.gltfBytes.data(), result.gltfBytes.size());

    *length = result.gltfBytes.size();

    return serialized;
    
}

void CesiumGltfModel_free_serialized(uint8_t* data) {
    free(data);
}

}