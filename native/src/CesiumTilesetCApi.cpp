#include "CesiumTilesetCApi.h"

#undef OPAQUE

#ifdef __ANDROID__
#include "spdlog/sinks/android_sink.h"
#endif

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
#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/buffer.h>
#include <string>
#include <cstring>

#include <glm/ext/matrix_transform.hpp>
#include <spdlog/spdlog.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/async.h>
#include <spdlog/sinks/basic_file_sink.h>

#include <Cesium3DTilesSelection/Tileset.h>
#include <Cesium3DTilesSelection/TilesetExternals.h>
#include <CesiumAsync/IAssetAccessor.h>
#include <CesiumAsync/AsyncSystem.h>
#include <CesiumAsync/CachingAssetAccessor.h>
#include <CesiumAsync/SqliteCache.h>
#include <Cesium3DTilesContent/registerAllTileContentTypes.h>
#include <Cesium3DTilesSelection/BoundingVolume.h>
#include <CesiumGeometry/BoundingSphere.h>
#include <CesiumGeometry/OrientedBoundingBox.h>
#include <CesiumGeospatial/BoundingRegion.h>
#include <CesiumGeospatial/Ellipsoid.h>
#include <CesiumGltfWriter/GltfWriter.h>
#include <CesiumGltfContent/GltfUtilities.h>

// #ifdef _WIN32
// #include "HttpLibAssetAccessor.hpp"
// #else
#include "CurlAssetAccessor.hpp"
// #endif

#include "PrepareRenderer.hpp"
#include "Base64Encode.hpp"

namespace DartCesiumNative {

    using namespace Cesium3DTilesSelection;

class SimpleTaskProcessor : public CesiumAsync::ITaskProcessor {
public:
    SimpleTaskProcessor(size_t numThreads) : running(true) {
        for (size_t i = 0; i < numThreads; ++i) {
            workerThreads.emplace_back(&SimpleTaskProcessor::processJobs, this);
        }
    }

    ~SimpleTaskProcessor() {
        {
            std::unique_lock<std::mutex> lock(queueMutex);
            running = false;
            condition.notify_all();
        }
        for (auto& thread : workerThreads) {
            if (thread.joinable()) {
                thread.join();
            }
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
                if (!jobQueue.empty()) {
                    job = std::move(jobQueue.front());
                    jobQueue.pop();
                }
            }
            if (job) {
                job();
            }
        }
    }

    std::queue<std::function<void()>> jobQueue;
    std::mutex queueMutex;
    std::condition_variable condition;
    std::vector<std::thread> workerThreads;
    std::atomic<bool> running;
};

extern "C" {

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
static CesiumAsync::AsyncSystem asyncSystem { nullptr };
static std::shared_ptr<Cesium3DTilesSelection::IPrepareRendererResources> pResourcePreparer;
static std::shared_ptr<CesiumAsync::IAssetAccessor> pAssetAccessor;
static std::shared_ptr<CesiumAsync::ICacheDatabase> pCacheDatabase;
static std::shared_ptr<CesiumUtility::CreditSystem> pMockedCreditSystem;
static std::thread *main;
API_EXPORT void CesiumTileset_initialize(uint32_t numThreads, const char* cacheDbPath) {
    if(pResourcePreparer) {
        return;
    }

    #ifdef __ANDROID__
    auto console = spdlog::android_logger_mt("cesium_logger", "cesium_native");
    #else
    auto console = spdlog::stdout_color_mt("cesium_logger");
    #endif

    spdlog::set_default_logger(console);
    // TODO: make this a user-configurable
    spdlog::set_level(spdlog::level::info); // Or info, warn, error, etc.
    spdlog::enable_backtrace(32); // Keep a backtrace of 32 messages
    
    pAssetAccessor = std::make_shared<CurlAssetAccessor>();
    
    // Only create caching if a valid path is provided
    if (cacheDbPath && strlen(cacheDbPath) > 0) {
        pCacheDatabase = std::make_shared<CesiumAsync::SqliteCache>(
            spdlog::default_logger(),
            cacheDbPath,
            4096
        );
        if (pCacheDatabase) {
            spdlog::default_logger()->info("SQLite cache created successfully at: {}", cacheDbPath);
            pAssetAccessor = std::make_shared<CesiumAsync::CachingAssetAccessor>(
                spdlog::default_logger(),
                pAssetAccessor,
                pCacheDatabase,
                10000
            );
            spdlog::default_logger()->info("CachingAssetAccessor created with database: {}", cacheDbPath);
        } else {
            spdlog::default_logger()->error("Failed to create SQLite cache at: {}", cacheDbPath);
        }
    } else {
        spdlog::default_logger()->info("No cache path provided, running without tile caching");
    }
    
    asyncSystem = CesiumAsync::AsyncSystem {  std::make_shared<SimpleTaskProcessor>(numThreads) };

    pMockedCreditSystem = std::make_shared<CesiumUtility::CreditSystem>();
    pResourcePreparer = std::dynamic_pointer_cast<Cesium3DTilesSelection::IPrepareRendererResources>(std::make_shared<SimplePrepareRendererResource>());
    
    Cesium3DTilesContent::registerAllTileContentTypes();
    
    spdlog::default_logger()->info("Cesium Native bindings initialized ({} threads)", numThreads);
}

CesiumTileset* CesiumTileset_create(const char* url, CesiumTilesetOptions cesiumTilesetOptions, void(*onRootTileAvailableEvent)()) {

    Cesium3DTilesSelection::TilesetExternals externals {
      pAssetAccessor,
      pResourcePreparer,
      asyncSystem,
      pMockedCreditSystem};

    externals.pAssetAccessor = pAssetAccessor;
    externals.pPrepareRendererResources = pResourcePreparer;
    
    // TODO - pass these in as arguments
    TilesetOptions options;
        options.enableLodTransitionPeriod = cesiumTilesetOptions.enableLodTransitionPeriod;
    
    options.forbidHoles = cesiumTilesetOptions.forbidHoles;
    options.lodTransitionLength = cesiumTilesetOptions.loadingDescendantLimit;
    options.enableOcclusionCulling = cesiumTilesetOptions.enableOcclusionCulling;
    options.enableFogCulling = cesiumTilesetOptions.enableFogCulling;
    options.enableFrustumCulling = cesiumTilesetOptions.enableFrustumCulling;
    
    options.enforceCulledScreenSpaceError = cesiumTilesetOptions.enforceCulledScreenSpaceError;
    options.culledScreenSpaceError = cesiumTilesetOptions.culledScreenSpaceError;
    options.maximumScreenSpaceError =cesiumTilesetOptions.maximumScreenSpaceError;

    options.maximumSimultaneousTileLoads = cesiumTilesetOptions.maximumSimultaneousTileLoads;
    options.maximumSimultaneousSubtreeLoads = cesiumTilesetOptions.maximumSimultaneousSubtreeLoads;
    options.loadingDescendantLimit = cesiumTilesetOptions.loadingDescendantLimit;

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

CesiumTileset* CesiumTileset_createFromIonAsset(int64_t assetId,  const char* accessToken, CesiumTilesetOptions cesiumTilesetOptions, void(*onRootTileAvailableEvent)()) {

    Cesium3DTilesSelection::TilesetExternals externals {
      pAssetAccessor,
      pResourcePreparer,
      asyncSystem,
      pMockedCreditSystem};

    // TODO - pass these in as arguments
    TilesetOptions options;
    
    // options.delayRefinementForOcclusion = true;
    options.enableLodTransitionPeriod = cesiumTilesetOptions.enableLodTransitionPeriod;
    
    options.forbidHoles = cesiumTilesetOptions.forbidHoles;
    options.lodTransitionLength = cesiumTilesetOptions.loadingDescendantLimit;
    options.enableOcclusionCulling = cesiumTilesetOptions.enableOcclusionCulling;
    options.enableFogCulling = cesiumTilesetOptions.enableFogCulling;
    options.enableFrustumCulling = cesiumTilesetOptions.enableFrustumCulling;
    
    options.enforceCulledScreenSpaceError = cesiumTilesetOptions.enforceCulledScreenSpaceError;
    options.culledScreenSpaceError = cesiumTilesetOptions.culledScreenSpaceError;
    options.maximumScreenSpaceError =cesiumTilesetOptions.maximumScreenSpaceError;

    options.maximumSimultaneousTileLoads = cesiumTilesetOptions.maximumSimultaneousTileLoads;
    options.maximumSimultaneousSubtreeLoads = cesiumTilesetOptions.maximumSimultaneousSubtreeLoads;
    options.loadingDescendantLimit = cesiumTilesetOptions.loadingDescendantLimit;
    
    
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

void CesiumTileset_destroy(CesiumTileset* tileset, void(*onTileDestroyEvent)()) {        
    tileset->tileset->getAsyncDestructionCompleteEvent().thenInMainThread([=]() { 
        onTileDestroyEvent();
    });
    asyncSystem.dispatchMainThreadTasks();
    // Delete the CesiumTileset object
    delete tileset;
}


int CesiumTileset_updateView(CesiumTileset* tileset, const CesiumViewState viewState, float deltaTime) {
    if (!tileset) return -1;

    auto ellipsoid = CesiumGeospatial::Ellipsoid::WGS84;

    Cesium3DTilesSelection::ViewState cesiumViewState = Cesium3DTilesSelection::ViewState::create(
        glm::dvec3(viewState.position[0], viewState.position[1], viewState.position[2]),
        glm::dvec3(viewState.direction[0], viewState.direction[1], viewState.direction[2]),
        glm::dvec3(viewState.up[0], viewState.up[1], viewState.up[2]),
        glm::dvec2(viewState.viewportWidth, viewState.viewportHeight),
        viewState.horizontalFov,
        viewState.verticalFov,
        ellipsoid
    );

    tileset->lastUpdateResult = tileset->tileset->updateView({cesiumViewState}, deltaTime);    
  
    return static_cast<int>(tileset->lastUpdateResult.tilesToRenderThisFrame.size());
}

void CesiumTileset_updateViewAsync(CesiumTileset* tileset, const CesiumViewState viewState, float deltaTime, void(*callback)(int)) {
    auto fut = asyncSystem.runInMainThread([=]() { 
        auto result = CesiumTileset_updateView(tileset, viewState, deltaTime);
        callback(result);
    }); 
    asyncSystem.dispatchMainThreadTasks();
}

float CesiumTileset_computeLoadProgress(CesiumTileset* tileset) {   
    return tileset->tileset->computeLoadProgress();
}


CesiumCartographic CesiumTileset_getPositionCartographic(CesiumViewState viewState) {

    auto ellipsoid = CesiumGeospatial::Ellipsoid::WGS84;

    Cesium3DTilesSelection::ViewState cesiumViewState = Cesium3DTilesSelection::ViewState::create(
        glm::dvec3(viewState.position[0], viewState.position[1], viewState.position[2]),
        glm::dvec3(viewState.direction[0], viewState.direction[1], viewState.direction[2]),
        glm::dvec3(viewState.up[0], viewState.up[1], viewState.up[2]),
        glm::dvec2(viewState.viewportWidth, viewState.viewportHeight),
        viewState.horizontalFov,
        viewState.verticalFov,
        ellipsoid
    );
    CesiumCartographic position;
    if(cesiumViewState.getPositionCartographic()) {
        auto val = cesiumViewState.getPositionCartographic().value();
        position.height = val.height;
        position.longitude = val.longitude;
        position.latitude = val.latitude;
    }
    return position;
}

API_EXPORT CesiumCartographic CesiumTileset_cartesianToCartographic(double x, double y, double z) {

    glm::dvec3 point { x, y, z};
    auto ellipsoid = CesiumGeospatial::Ellipsoid::WGS84;
    
    std::optional<CesiumGeospatial::Cartographic> position = ellipsoid.cartesianToCartographic(point);

    CesiumCartographic returnValue;

    if(position.has_value()) {
        returnValue.height = position.value().height;
        returnValue.latitude = position.value().latitude;
        returnValue.longitude = position.value().longitude;
    }
    
    return returnValue;
}

API_EXPORT double3 CesiumTileset_cartographicToCartesian(double latitude, double longitude, double height) {
    CesiumGeospatial::Cartographic cartographic { longitude, latitude, height };
        
    auto ellipsoid = CesiumGeospatial::Ellipsoid::WGS84;
    
    glm::dvec3 point = ellipsoid.cartographicToCartesian(cartographic);

    double3 returnValue { point.x, point.y, point.z };
    
    return returnValue;
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

CesiumTileContentType CesiumTileset_getTileContentType(CesiumTile* cesiumTile) {
    auto tile = (Tile*)cesiumTile;
    auto state = tile->getState();
        
    if(tile->isEmptyContent()) { 
        auto& content = tile->getContent();
        auto ext = content.getExternalContent();
        return CT_TC_EMPTY;
    } else if(tile->isExternalContent()) {
        auto content = tile->getContent().getExternalContent();
        auto metadata = content->metadata;
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

int CesiumTileset_getNumTilesLoaded(CesiumTileset* tileset) {
    return tileset->tileset->getNumberOfTilesLoaded();
}

static void recurse(Tile* tile, const std::function<void(Tile* const)>& visitor) {
    if(tile->getState() != TileLoadState::Done) {
        return;
    }

    visitor(tile);
        
    for (Tile& childTile : tile->getChildren()) {
        recurse(&childTile, visitor);
    }
}

CesiumTilesetRenderableTiles CesiumTileset_getRenderableTiles(CesiumTile* cesiumTile) {
    
    std::set<const Tile*> content;
    auto* tile = reinterpret_cast<Tile*>(cesiumTile);
    
    const auto& visitor = [&](Tile* const tile) {
        if(tile->isRenderable() && tile->isRenderContent()) {
            content.insert(tile);
        }
    };
    
    recurse(tile, visitor);
    
    CesiumTilesetRenderableTiles out;
    out.numTiles = (int32_t)content.size();
    int i = 0;
    for(auto it = content.begin(); it != content.end(); it++) {
        out.tiles[i] = reinterpret_cast<const CesiumTile* const>(*it);
        // out.states[i] = tile->getState();
        i++;
    }
    return out;
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
        for(int i = 0; i < 3; i++) {
            auto axis = obb.getHalfAxes()[i];
            for (int j = 0; j < 3; ++j) {
                result.volume.orientedBox.halfAxes[(i*3)+j] = axis[j];
            }
        }
    }
    else if (std::holds_alternative<CesiumGeospatial::BoundingRegion>(bv)) {
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
        // Handle unexpected bounding volume type
        result.type = CT_BV_SPHERE;
        result.volume.sphere = {{0, 0, 0}, 0};
    }

    return result;
}

double CesiumTile_viewStateSquaredDistanceToBoundingVolume(CesiumTile* oTile, CesiumViewState oViewState) {
    auto ellipsoid = CesiumGeospatial::Ellipsoid::WGS84;

    Cesium3DTilesSelection::ViewState viewState = Cesium3DTilesSelection::ViewState::create(
        glm::dvec3(oViewState.position[0], oViewState.position[1], oViewState.position[2]),
        glm::dvec3(oViewState.direction[0], oViewState.direction[1], oViewState.direction[2]),
        glm::dvec3(oViewState.up[0], oViewState.up[1], oViewState.up[2]),
        glm::dvec2(oViewState.viewportWidth, oViewState.viewportHeight),
        oViewState.horizontalFov,
        oViewState.horizontalFov * oViewState.viewportHeight / oViewState.viewportWidth,
        ellipsoid
    );
    
    Cesium3DTilesSelection::Tile* tile = reinterpret_cast<Cesium3DTilesSelection::Tile*>(oTile);
    return viewState.computeDistanceSquaredToBoundingVolume(tile->getBoundingVolume());
}

double CesiumTile_squaredDistanceToBoundingVolume(CesiumTile* oTile, double3 point) {
    Cesium3DTilesSelection::Tile* tile = reinterpret_cast<Cesium3DTilesSelection::Tile*>(oTile);
    glm::dvec3 gpoint { point.x, point.y, point.z };
    auto bv = tile->getBoundingVolume();
     if (std::holds_alternative<CesiumGeometry::BoundingSphere>(bv)) {
        return std::get<CesiumGeometry::BoundingSphere>(bv).computeDistanceSquaredToPosition(gpoint);
    }
    else if (std::holds_alternative<CesiumGeometry::OrientedBoundingBox>(bv)) {
        return std::get<CesiumGeometry::OrientedBoundingBox>(bv).computeDistanceSquaredToPosition(gpoint);
    }
    else if (std::holds_alternative<CesiumGeospatial::BoundingRegion>(bv)) {
        return std::get<CesiumGeospatial::BoundingRegion>(bv).computeDistanceSquaredToPosition(gpoint);
    }
    else {
        return -1.0;
    }
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

int CesiumTileset_getLastFrameNumber(CesiumTileset* tileset) {
    return tileset->lastUpdateResult.frameNumber;
}

CesiumTileSelectionState CesiumTile_getTileSelectionState(CesiumTile* tile, int frameNumber) {
    Cesium3DTilesSelection::Tile* cesiumTile = reinterpret_cast<Cesium3DTilesSelection::Tile*>(tile);
    const auto& state = cesiumTile->getLastSelectionState();
    switch(state.getResult(frameNumber)) {
        case TileSelectionState::Result::None:
            return CT_SS_NONE;
        case TileSelectionState::Result::Culled:
            return CT_SS_CULLED;
        case TileSelectionState::Result::Rendered:
            return CT_SS_RENDERED;
        case TileSelectionState::Result::Refined:
            return CT_SS_REFINED;
        case TileSelectionState::Result::RenderedAndKicked:
            return CT_SS_RENDERED_AND_KICKED;
        case TileSelectionState::Result::RefinedAndKicked:
            return CT_SS_REFINED_AND_KICKED;
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

double4x4 CesiumGltfModel_applyRtcCenter(CesiumGltfModel* model, double4x4 transform) {
    
    auto cesiumModel = reinterpret_cast<CesiumGltf::Model*>(model);
    glm::dmat4x4 glmTransform {
        transform.col1[0],
        transform.col1[1],
        transform.col1[2],
        transform.col1[3],
        transform.col2[0],
        transform.col2[1],
        transform.col2[2],
        transform.col2[3],
        transform.col3[0],
        transform.col3[1],
        transform.col3[2],
        transform.col3[3],
        transform.col4[0],
        transform.col4[1],
        transform.col4[2],
        transform.col4[3],
    };
     
    auto rtcTransformed = CesiumGltfContent::GltfUtilities::applyRtcCenter(*cesiumModel, glmTransform);
    
    return double4x4 {
        rtcTransformed[0][0],
        rtcTransformed[0][1],
        rtcTransformed[0][2],
        rtcTransformed[0][3],
        rtcTransformed[1][0],
        rtcTransformed[1][1],
        rtcTransformed[1][2],
        rtcTransformed[1][3],
        rtcTransformed[2][0],
        rtcTransformed[2][1],
        rtcTransformed[2][2],
        rtcTransformed[2][3],
        rtcTransformed[3][0],
        rtcTransformed[3][1],
        rtcTransformed[3][2],
        rtcTransformed[3][3],
    };
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

void CesiumGltfModel_serializeAsync(CesiumGltfModel* opaqueModel, void(*callback)(SerializedCesiumGltfModel)) {
    auto fut = asyncSystem.runInWorkerThread([=]() { 
        auto serialized = CesiumGltfModel_serialize(opaqueModel);
        callback(serialized);
    }); 
}

SerializedCesiumGltfModel CesiumGltfModel_serialize(CesiumGltfModel* opaqueModel) {
    CesiumGltfWriter::GltfWriter writer;
    auto model = reinterpret_cast<CesiumGltf::Model*>(opaqueModel);
    
    // The glb format only permits a single BIN chunk.
    // We therefore need to concatenate all buffer data and update the bufferView so that:
    // - the buffer index always points to zero
    // - the offset is now relative to the start of this buffer
    // - each buffer is aligned on 4-byte boundaries
    std::vector<int64_t> offsets;
    int64_t offset = 0;
    std::vector<std::byte> bufferData;
    int64_t totalByteLength = 0;

    for (CesiumGltf::Buffer& buffer : model->buffers) {
        if(buffer.uri) {
            spdlog::default_logger()->error(buffer.uri.value());
            spdlog::default_logger()->flush();
            exit(-1);
        }

        // Calculate padding needed for 4-byte alignment
        int64_t padding = (4 - (offset % 4)) % 4;
        offset += padding;
        
        // Add padding bytes if needed
        while (padding-- > 0) {
            bufferData.push_back(std::byte{0});
            totalByteLength++;
        }

        offsets.push_back(offset);
        offset += buffer.byteLength;
        
        // Insert the actual buffer data
        bufferData.insert(bufferData.end(), buffer.cesium.data.begin(), buffer.cesium.data.end());
        totalByteLength += buffer.byteLength;
    }
    
    // Ensure final size is also 4-byte aligned
    int64_t finalPadding = (4 - (totalByteLength % 4)) % 4;
    while (finalPadding-- > 0) {
        bufferData.push_back(std::byte{0});
        totalByteLength++;
    }
    
    model->buffers.resize(1);
    model->buffers[0].byteLength = totalByteLength;
    model->buffers[0].cesium.data = bufferData;

    for (CesiumGltf::BufferView& bufferView : model->bufferViews) {
        int offset = offsets[bufferView.buffer];
        bufferView.byteOffset += offset;
        bufferView.buffer = 0;        
    }
  
    CesiumGltfWriter::GltfWriterOptions options;
    options.binaryChunkByteAlignment = 4;  
    options.prettyPrint = false;
    
    auto result = writer.writeGlb(*model, gsl::span<const std::byte>(bufferData), options);

    for(auto& err : result.errors) { 
        spdlog::default_logger()->error(err);
    }

    for(auto& msg : result.warnings) { 
        spdlog::default_logger()->warn(msg);
    }

    SerializedCesiumGltfModel serialized;
    serialized.data = (uint8_t*) malloc(result.gltfBytes.size());

    memcpy(serialized.data, result.gltfBytes.data(), result.gltfBytes.size());

    serialized.length = result.gltfBytes.size();

    return serialized;
    
}

void CesiumGltfModel_free_serialized(SerializedCesiumGltfModel model) {
    free(model.data);
}

}
}