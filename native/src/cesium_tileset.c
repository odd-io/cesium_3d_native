#include "cesium_tileset.h"
#include <Cesium3DTilesSelection/Tileset.h>
#include <Cesium3DTilesSelection/TilesetExternals.h>
#include <CesiumAsync/IAssetAccessor.h>
#include <CesiumAsync/AsyncSystem.h>
#include <memory>
#include <vector>
#include "CurlAssetAccessor.hpp"
#include "PrepareRenderer.hpp"

using namespace Cesium3DTilesSelection;

class SimpleTaskProcessor : public CesiumAsync::ITaskProcessor {
public:
  virtual void startTask(std::function<void()> f) override { f(); }
};

struct CesiumTileset {
    std::unique_ptr<Cesium3DTilesSelection::Tileset> tileset;
    Cesium3DTilesSelection::ViewUpdateResult lastUpdateResult;
};

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

    auto pTileset = new CesiumTileset();
    pTileset->tileset = std::make_unique<Cesium3DTilesSelection::Tileset>(
        externals,
        assetId,
        accessToken
    );
    return pTileset;
}

void CesiumTileset_destroy(CesiumTileset* tileset) {
    delete tileset;
}

int CesiumTileset_updateView(CesiumTileset* tileset, const CesiumViewState* viewState) {
    if (!tileset || !viewState) return 0;
    Cesium3DTilesSelection::ViewState cesiumViewState = Cesium3DTilesSelection::ViewState::create(
        glm::dvec3(viewState->position[0], viewState->position[1], viewState->position[2]),
        glm::dvec3(viewState->direction[0], viewState->direction[1], viewState->direction[2]),
        glm::dvec3(viewState->up[0], viewState->up[1], viewState->up[2]),
        glm::dvec2(viewState->viewportWidth, viewState->viewportHeight),
        viewState->horizontalFov,
        viewState->horizontalFov * viewState->viewportHeight / viewState->viewportWidth,
        CesiumGeospatial::Ellipsoid::WGS84
    );

    tileset->lastUpdateResult = tileset->tileset->updateView({cesiumViewState});
    return static_cast<int>(tileset->lastUpdateResult.tilesToRenderThisFrame.size());
}

int CesiumTileset_getTileCount(const CesiumTileset* tileset) {
    if (!tileset) return 0;
    return static_cast<int>(tileset->lastUpdateResult.tilesToRenderThisFrame.size());
}

void CesiumTileset_getTileRenderData(const CesiumTileset* tileset, int index, void** renderData) {
    if (!tileset || index < 0 || index >= tileset->lastUpdateResult.tilesToRenderThisFrame.size()) {
        *renderData = nullptr;
        return;
    }

    auto tile = tileset->lastUpdateResult.tilesToRenderThisFrame[index];
    *renderData = tile->getContent().getRenderContent()->getRenderResources();
}