// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
// ignore_for_file: type=lint
@ffi.DefaultAsset('package:cesium_3d_tiles/cesium_native/cesium_native.dart')
library;

import 'dart:ffi' as ffi;

@ffi.Native<ffi.Void Function(ffi.Uint32)>()
external void CesiumTileset_initialize(
  int numThreads,
);

@ffi.Native<ffi.Void Function()>()
external void CesiumTileset_pumpAsyncQueue();

@ffi.Native<
    ffi.Pointer<CesiumTileset> Function(
        ffi.Pointer<ffi.Char>,
        CesiumTilesetOptions,
        ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>>)>()
external ffi.Pointer<CesiumTileset> CesiumTileset_create(
  ffi.Pointer<ffi.Char> url,
  CesiumTilesetOptions cesiumTilesetOptions,
  ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>> onRootTileAvailableEvent,
);

@ffi.Native<
    ffi.Pointer<CesiumTileset> Function(
        ffi.Int64,
        ffi.Pointer<ffi.Char>,
        CesiumTilesetOptions,
        ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>>)>()
external ffi.Pointer<CesiumTileset> CesiumTileset_createFromIonAsset(
  int assetId,
  ffi.Pointer<ffi.Char> accessToken,
  CesiumTilesetOptions cesiumTilesetOptions,
  ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>> onRootTileAvailableEvent,
);

@ffi.Native<ffi.Float Function(ffi.Pointer<CesiumTileset>)>()
external double CesiumTileset_computeLoadProgress(
  ffi.Pointer<CesiumTileset> tileset,
);

@ffi.Native<ffi.Int Function(ffi.Pointer<CesiumTileset>)>()
external int CesiumTileset_getLastFrameNumber(
  ffi.Pointer<CesiumTileset> tileset,
);

@ffi.Native<ffi.Int Function(ffi.Pointer<CesiumTileset>)>()
external int CesiumTileset_getNumTilesLoaded(
  ffi.Pointer<CesiumTileset> tileset,
);

@ffi.Native<ffi.Int Function(ffi.Pointer<CesiumTileset>)>()
external int CesiumTileset_hasLoadError(
  ffi.Pointer<CesiumTileset> tileset,
);

@ffi.Native<
    ffi.Void Function(ffi.Pointer<CesiumTileset>, ffi.Pointer<ffi.Char>)>()
external void CesiumTileset_getErrorMessage(
  ffi.Pointer<CesiumTileset> tileset,
  ffi.Pointer<ffi.Char> out,
);

@ffi.Native<
    ffi.Void Function(ffi.Pointer<CesiumTileset>,
        ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>>)>()
external void CesiumTileset_destroy(
  ffi.Pointer<CesiumTileset> tileset,
  ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>> onTileDestroyEvent,
);

@ffi.Native<
    ffi.Int Function(ffi.Pointer<CesiumTileset>, CesiumViewState, ffi.Float)>()
external int CesiumTileset_updateView(
  ffi.Pointer<CesiumTileset> tileset,
  CesiumViewState viewState,
  double deltaTime,
);

@ffi.Native<
    ffi.Void Function(ffi.Pointer<CesiumTileset>, CesiumViewState, ffi.Float,
        ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Int)>>)>()
external void CesiumTileset_updateViewAsync(
  ffi.Pointer<CesiumTileset> tileset,
  CesiumViewState viewState,
  double deltaTime,
  ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Int)>> callback,
);

@ffi.Native<CesiumCartographic Function(CesiumViewState)>()
external CesiumCartographic CesiumTileset_getPositionCartographic(
  CesiumViewState viewState,
);

@ffi.Native<CesiumCartographic Function(ffi.Double, ffi.Double, ffi.Double)>()
external CesiumCartographic CesiumTileset_cartesianToCartographic(
  double x,
  double y,
  double z,
);

@ffi.Native<double3 Function(ffi.Double, ffi.Double, ffi.Double)>()
external double3 CesiumTileset_cartographicToCartesian(
  double latitude,
  double longitude,
  double height,
);

@ffi.Native<ffi.Int32 Function(ffi.Pointer<CesiumTileset>)>()
external int CesiumTileset_getTilesKicked(
  ffi.Pointer<CesiumTileset> tileset,
);

@ffi.Native<
    ffi.Pointer<CesiumTile> Function(ffi.Pointer<CesiumTileset>, ffi.Int)>()
external ffi.Pointer<CesiumTile> CesiumTileset_getTileToRenderThisFrame(
  ffi.Pointer<CesiumTileset> tileset,
  int index,
);

@ffi.Native<
    ffi.Void Function(ffi.Pointer<CesiumTileset>, ffi.Int,
        ffi.Pointer<ffi.Pointer<ffi.Void>>)>()
external void CesiumTileset_getTileRenderData(
  ffi.Pointer<CesiumTileset> tileset,
  int index,
  ffi.Pointer<ffi.Pointer<ffi.Void>> renderData,
);

@ffi.Native<ffi.Int32 Function(ffi.Pointer<CesiumTile>)>()
external int CesiumTileset_getTileLoadState(
  ffi.Pointer<CesiumTile> tile,
);

@ffi.Native<ffi.Int32 Function(ffi.Pointer<CesiumTile>)>()
external int CesiumTileset_getTileContentType(
  ffi.Pointer<CesiumTile> tile,
);

@ffi.Native<CesiumTilesetRenderableTiles Function(ffi.Pointer<CesiumTile>)>()
external CesiumTilesetRenderableTiles CesiumTileset_getRenderableTiles(
  ffi.Pointer<CesiumTile> cesiumTile,
);

@ffi.Native<ffi.Int32 Function(ffi.Pointer<CesiumTileset>)>()
external int CesiumTileset_getNumberOfTilesLoaded(
  ffi.Pointer<CesiumTileset> tileset,
);

@ffi.Native<ffi.Pointer<CesiumTile> Function(ffi.Pointer<CesiumTileset>)>()
external ffi.Pointer<CesiumTile> CesiumTileset_getRootTile(
  ffi.Pointer<CesiumTileset> tileset,
);

@ffi.Native<CesiumBoundingVolume Function(ffi.Pointer<CesiumTile>, ffi.Bool)>()
external CesiumBoundingVolume CesiumTile_getBoundingVolume(
  ffi.Pointer<CesiumTile> tile,
  bool convertToOrientedBox,
);

@ffi.Native<ffi.Double Function(ffi.Pointer<CesiumTile>, CesiumViewState)>()
external double CesiumTile_squaredDistanceToBoundingVolume(
  ffi.Pointer<CesiumTile> oTile,
  CesiumViewState oViewState,
);

@ffi.Native<double3 Function(ffi.Pointer<CesiumTile>)>()
external double3 CesiumTile_getBoundingVolumeCenter(
  ffi.Pointer<CesiumTile> tile,
);

@ffi.Native<double4x4 Function(ffi.Pointer<CesiumTile>)>()
external double4x4 CesiumTile_getTransform(
  ffi.Pointer<CesiumTile> tile,
);

@ffi.Native<ffi.Pointer<CesiumGltfModel> Function(ffi.Pointer<CesiumTile>)>()
external ffi.Pointer<CesiumGltfModel> CesiumTile_getModel(
  ffi.Pointer<CesiumTile> tile,
);

@ffi.Native<double4x4 Function(ffi.Pointer<CesiumGltfModel>, double4x4)>(
    isLeaf: true)
external double4x4 CesiumGltfModel_applyRtcCenter(
  ffi.Pointer<CesiumGltfModel> model,
  double4x4 transform,
);

@ffi.Native<ffi.Int Function(ffi.Pointer<CesiumTile>)>()
external int CesiumTile_hasModel(
  ffi.Pointer<CesiumTile> tile,
);

@ffi.Native<ffi.Int32 Function(ffi.Pointer<CesiumTile>, ffi.Int)>()
external int CesiumTile_getTileSelectionState(
  ffi.Pointer<CesiumTile> tile,
  int frameNumber,
);

@ffi.Native<ffi.Int32 Function(ffi.Pointer<CesiumGltfModel>)>()
external int CesiumGltfModel_getMeshCount(
  ffi.Pointer<CesiumGltfModel> model,
);

@ffi.Native<ffi.Int32 Function(ffi.Pointer<CesiumGltfModel>)>()
external int CesiumGltfModel_getMaterialCount(
  ffi.Pointer<CesiumGltfModel> model,
);

@ffi.Native<ffi.Int32 Function(ffi.Pointer<CesiumGltfModel>)>()
external int CesiumGltfModel_getTextureCount(
  ffi.Pointer<CesiumGltfModel> model,
);

@ffi.Native<SerializedCesiumGltfModel Function(ffi.Pointer<CesiumGltfModel>)>()
external SerializedCesiumGltfModel CesiumGltfModel_serialize(
  ffi.Pointer<CesiumGltfModel> opaqueModel,
);

@ffi.Native<
    ffi.Void Function(
        ffi.Pointer<CesiumGltfModel>,
        ffi.Pointer<
            ffi
            .NativeFunction<ffi.Void Function(SerializedCesiumGltfModel)>>)>()
external void CesiumGltfModel_serializeAsync(
  ffi.Pointer<CesiumGltfModel> opaqueModel,
  ffi.Pointer<ffi.NativeFunction<ffi.Void Function(SerializedCesiumGltfModel)>>
      callback,
);

@ffi.Native<ffi.Void Function(SerializedCesiumGltfModel)>()
external void CesiumGltfModel_free_serialized(
  SerializedCesiumGltfModel serialized,
);

final class CesiumTileset extends ffi.Opaque {}

final class CesiumTile extends ffi.Opaque {}

final class CesiumGltfModel extends ffi.Opaque {}

final class CesiumTilesetOptions extends ffi.Struct {
  @ffi.Bool()
  external bool forbidHoles;

  @ffi.Bool()
  external bool enableLodTransitionPeriod;

  @ffi.Float()
  external double lodTransitionLength;

  @ffi.Bool()
  external bool enableOcclusionCulling;

  @ffi.Bool()
  external bool enableFogCulling;

  @ffi.Bool()
  external bool enableFrustumCulling;

  @ffi.Bool()
  external bool enforceCulledScreenSpaceError;

  @ffi.Double()
  external double culledScreenSpaceError;

  @ffi.Double()
  external double maximumScreenSpaceError;

  @ffi.Uint32()
  external int maximumSimultaneousTileLoads;

  @ffi.Uint32()
  external int maximumSimultaneousSubtreeLoads;

  @ffi.Uint32()
  external int loadingDescendantLimit;
}

final class CesiumTilesetRenderableTiles extends ffi.Struct {
  @ffi.Array.multi([4096])
  external ffi.Array<ffi.Pointer<CesiumTile>> tiles;

  @ffi.Size()
  external int numTiles;
}

abstract class CesiumTileLoadState {
  static const int CT_LS_UNLOADING = -2;
  static const int CT_LS_FAILED_TEMPORARILY = -1;
  static const int CT_LS_UNLOADED = 0;
  static const int CT_LS_CONTENT_LOADING = 1;
  static const int CT_LS_CONTENT_LOADED = 2;
  static const int CT_LS_DONE = 3;
  static const int CT_LS_FAILED = 4;
}

abstract class CesiumTileContentType {
  static const int CT_TC_EMPTY = 0;
  static const int CT_TC_RENDER = 1;
  static const int CT_TC_EXTERNAL = 2;
  static const int CT_TC_UNKNOWN = 3;
  static const int CT_TC_ERROR = 4;
}

final class double3 extends ffi.Struct {
  @ffi.Double()
  external double x;

  @ffi.Double()
  external double y;

  @ffi.Double()
  external double z;
}

final class double4x4 extends ffi.Struct {
  @ffi.Array.multi([4])
  external ffi.Array<ffi.Double> col1;

  @ffi.Array.multi([4])
  external ffi.Array<ffi.Double> col2;

  @ffi.Array.multi([4])
  external ffi.Array<ffi.Double> col3;

  @ffi.Array.multi([4])
  external ffi.Array<ffi.Double> col4;
}

final class CesiumViewState extends ffi.Struct {
  @ffi.Array.multi([3])
  external ffi.Array<ffi.Double> position;

  @ffi.Array.multi([3])
  external ffi.Array<ffi.Double> direction;

  @ffi.Array.multi([3])
  external ffi.Array<ffi.Double> up;

  @ffi.Double()
  external double viewportWidth;

  @ffi.Double()
  external double viewportHeight;

  @ffi.Double()
  external double horizontalFov;

  @ffi.Double()
  external double verticalFov;
}

final class CesiumBoundingSphere extends ffi.Struct {
  @ffi.Array.multi([3])
  external ffi.Array<ffi.Double> center;

  @ffi.Double()
  external double radius;
}

final class CesiumOrientedBoundingBox extends ffi.Struct {
  @ffi.Array.multi([3])
  external ffi.Array<ffi.Double> center;

  @ffi.Array.multi([9])
  external ffi.Array<ffi.Double> halfAxes;
}

final class CesiumBoundingRegion extends ffi.Struct {
  @ffi.Double()
  external double west;

  @ffi.Double()
  external double south;

  @ffi.Double()
  external double east;

  @ffi.Double()
  external double north;

  @ffi.Double()
  external double minimumHeight;

  @ffi.Double()
  external double maximumHeight;
}

abstract class CesiumBoundingVolumeType {
  static const int CT_BV_SPHERE = 0;
  static const int CT_BV_ORIENTED_BOX = 1;
  static const int CT_BV_REGION = 2;
}

final class CesiumBoundingVolume extends ffi.Struct {
  @ffi.Int32()
  external int type;

  external UnnamedUnion1 volume;
}

final class UnnamedUnion1 extends ffi.Union {
  external CesiumBoundingSphere sphere;

  external CesiumOrientedBoundingBox orientedBox;

  external CesiumBoundingRegion region;
}

final class CesiumCartographic extends ffi.Struct {
  @ffi.Double()
  external double longitude;

  @ffi.Double()
  external double latitude;

  @ffi.Double()
  external double height;
}

abstract class CesiumTileSelectionState {
  static const int CT_SS_NONE = 0;
  static const int CT_SS_CULLED = 1;
  static const int CT_SS_RENDERED = 2;
  static const int CT_SS_REFINED = 3;
  static const int CT_SS_RENDERED_AND_KICKED = 4;
  static const int CT_SS_REFINED_AND_KICKED = 5;
}

final class SerializedCesiumGltfModel extends ffi.Struct {
  external ffi.Pointer<ffi.Uint8> data;

  @ffi.Size()
  external int length;
}
