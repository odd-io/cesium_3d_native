import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:cesium_3d_tiles/src/cesium_native/cartographic_position.dart';
import 'package:cesium_3d_tiles/src/cesium_native/cesium_3d_native.g.dart' as g;
import 'package:cesium_3d_tiles/src/cesium_native/cesium_bounding_volume.dart';
import 'package:cesium_3d_tiles/src/cesium_native/cesium_view.dart';
import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math_64.dart';

class CesiumTileset {
  final Pointer<g.CesiumTileset> _ptr;
  DateTime? _lastUpdate;
  CesiumTileset(this._ptr);
}

typedef CesiumTile = Pointer<g.CesiumTile>;
typedef CesiumGltfModel = Pointer<g.CesiumGltfModel>;

final class SerializedCesiumGltfModel {
  final Pointer<Uint8> _ptr;
  final int _length;

  Uint8List get data => _ptr.asTypedList(_length);

  SerializedCesiumGltfModel(this._ptr, this._length);

  void free() {
    g.CesiumGltfModel_free_serialized(_ptr);
  }
}

enum CesiumTileContentType {
  Empty,
  Render,
  External,
  Unknown,
  Error,
}

enum CesiumTileLoadState {
  Unloading,
  FailedTemporarily,
  Unloaded,
  Loading,
  ContentLoaded,
  Done,
  Failed
}

enum CesiumTileSelectionState {
  None,
  Culled,
  Rendered,
  Refined,
  RenderedAndKicked,
  RefinedAndKicked
}

class Cesium3D {
  // preallocate memory

  // error message
  static late Pointer<Char> _errorMessage;

  // int used for lengths
  static late Pointer<Uint32> _length;

  // render content
  static const int _maxRenderContent = 1024;

  static Cesium3D? _instance;
  static Cesium3D get instance {
    _instance ??= Cesium3D._();
    return _instance!;
  }

  Cesium3D._() {
    g.CesiumTileset_initialize();
    _errorMessage = calloc<Char>(256);
    _length = calloc<Uint32>(1);
  }

  ///
  /// Load a CesiumTileset from a CesiumIonAsset with the specified token.
  ///
  Future<CesiumTileset> loadFromCesiumIon(
      int assetId, String accessToken) async {
    final ptr = accessToken.toNativeUtf8(allocator: calloc);
    final completer = Completer<void>();
    late NativeCallable<Void Function()> rootTileAvailable;
    rootTileAvailable = NativeCallable<Void Function()>.listener(() {
      completer.complete();
      rootTileAvailable.close();
    });

    final tilesetPtr = g.CesiumTileset_createFromIonAsset(
        assetId, ptr.cast<Char>(), rootTileAvailable.nativeFunction);
    calloc.free(ptr);

    int iters = 0;

    while (!completer.isCompleted) {
      await Future.delayed(Duration(milliseconds: 100));
      g.CesiumTileset_pumpAsyncQueue();
      iters++;
      if (iters > 100) {
        throw Exception(
            "Failed to load tileset within 10 seconds. This suggests an error");
      }
    }

    if (g.CesiumTileset_hasLoadError(tilesetPtr) == 1) {
      g.CesiumTileset_getErrorMessage(tilesetPtr, _errorMessage);
      throw Exception(_errorMessage.cast<Utf8>().toDartString());
    }

    if (tilesetPtr == nullptr) {
      throw Exception("Failed to fetch tileset for Cesium Ion asset $assetId");
    }

    return CesiumTileset(tilesetPtr);
  }

  ///
  /// Load a CesiumTileset from a url.
  ///
  Future<CesiumTileset> loadFromUrl(String url) async {
    final ptr = url.toNativeUtf8(allocator: calloc);
    final completer = Completer<void>();
    late NativeCallable<Void Function()> rootTileAvailable;
    rootTileAvailable = NativeCallable<Void Function()>.listener(() {
      completer.complete();
      rootTileAvailable.close();
    });
    final tilesetPtr = g.CesiumTileset_create(
        ptr.cast<Char>(), rootTileAvailable.nativeFunction);
    calloc.free(ptr);
    while (!completer.isCompleted) {
      await Future.delayed(Duration(milliseconds: 100));
      g.CesiumTileset_pumpAsyncQueue();
    }

    if (g.CesiumTileset_hasLoadError(tilesetPtr) == 1) {
      g.CesiumTileset_getErrorMessage(tilesetPtr, _errorMessage);
      throw Exception(_errorMessage.cast<Utf8>().toDartString());
    }
    if (tilesetPtr == nullptr) {
      throw Exception("Failed to fetch tileset from url $url");
    }

    return CesiumTileset(tilesetPtr);
  }

  g.CesiumViewState _toStruct(CesiumView view) {
    var struct = Struct.create<g.CesiumViewState>();
    struct.viewportHeight = view.viewportHeight;
    struct.viewportWidth = view.viewportWidth;
    struct.position[0] = view.position[0];
    struct.position[1] = view.position[1];
    struct.position[2] = view.position[2];
    struct.horizontalFov = view.horizontalFov;
    struct.direction[0] = view.direction[0];
    struct.direction[1] = view.direction[1];
    struct.direction[2] = view.direction[2];
    struct.up[0] = view.up[0];
    struct.up[1] = view.up[1];
    struct.up[2] = view.up[2];
    return struct;
  }

  ///
  ///
  ///
  int getLastFrameNumber(CesiumTileset tileset) {
    return g.CesiumTileset_getLastFrameNumber(tileset._ptr);
  }

  ///
  /// Update the tileset with the current view. Returns the number of tiles to render.
  ///
  int updateTilesetView(CesiumTileset tileset, CesiumView view) {
    var now = DateTime.now();
    var delta = tileset._lastUpdate == null
        ? 0.0
        : now.difference(tileset._lastUpdate!).inMilliseconds / 1000.0;
    final viewStruct = _toStruct(view);

    int numTiles = g.CesiumTileset_updateView(tileset._ptr, viewStruct, delta);
    if (numTiles == -1) {
      throw Exception("Unknown error updating tileset view");
    }
    tileset._lastUpdate = now;
    return numTiles;
  }

  ///
  ///
  ///
  CartographicPosition getCartographicPosition(CesiumView cesiumView) {
    final pos = g.CesiumTileset_getPositionCartographic(_toStruct(cesiumView));
    return CartographicPosition(pos.latitude, pos.longitude, pos.height);
  }

  ///
  ///
  ///
  int getNumTilesKicked(CesiumTileset tileset) {
    return g.CesiumTileset_getTilesKicked(tileset._ptr);
  }

  ///
  ///
  ///
  int getNumTilesLoaded(CesiumTileset tileset) {
    return g.CesiumTileset_getNumTilesLoaded(tileset._ptr);
  }

  ///
  /// Fetches the root CesiumTile for the tileset.
  /// If the tileset is not yet loaded, the return value will be null.
  ///
  CesiumTile? getRootTile(CesiumTileset tileset) {
    return g.CesiumTileset_getRootTile(tileset._ptr);
  }

  ///
  /// Gets the content type for the given type.
  ///
  CesiumTileContentType getTileContentType(CesiumTile tile) {
    final contentType = g.CesiumTileset_getTileContentType(tile);
    return CesiumTileContentType.values[contentType];
  }

  ///
  /// Gets the load progress for the given tileset.
  ///
  double computeLoadProgess(CesiumTileset tileset) {
    return g.CesiumTileset_computeLoadProgress(tileset._ptr);
  }

  ///
  /// Traverses this tile and its children to fetch all render content.
  ///
  List<CesiumTile> getRenderableTiles(CesiumTile tile) {
    final result = g.CesiumTileset_getRenderableTiles(tile);

    final renderableTiles =
        List<CesiumTile>.generate(result.numTiles, (i) => result.tiles[i]);
    return renderableTiles;
  }

  // Gets the CesiumTile to render at this frame at the given index.
  // [index] must be less than the result of the last [updateTilesetView]
  // (and will only be valid until the next call to [updateTilesetView]).
  CesiumTile getTileToRenderThisFrame(CesiumTileset tileset, int index) {
    return g.CesiumTileset_getTileToRenderThisFrame(tileset._ptr, index);
  }

  ///
  /// Gets the load state for a given tile.
  ///
  CesiumTileLoadState getLoadState(CesiumTile tile) {
    var state = g.CesiumTileset_getTileLoadState(tile);
    return CesiumTileLoadState.values[state + 2];
  }

  Matrix4 getTransform(CesiumTile tile) {
    var result = g.CesiumTile_getTransform(tile);
    return Matrix4(
      result.col1[0],
      result.col1[1],
      result.col1[2],
      result.col1[3],
      result.col2[0],
      result.col2[1],
      result.col2[2],
      result.col2[3],
      result.col3[0],
      result.col3[1],
      result.col3[2],
      result.col3[3],
      result.col4[0],
      result.col4[1],
      result.col4[2],
      result.col4[3],
    );
  }

  ///
  /// Returns the bounding volume of [tile] as:
  /// - CesiumBoundingVolumeOrientedBox
  /// - CesiumBoundingVolumeSphere
  /// - CesiumBoundingVolumeRegion [0]
  ///
  /// [0] when [convertRegionToOrientedBox] is true, all volumes of type [CesiumBoundingVolumeRegion] will be converted to [CesiumBoundingVolumeOrientedBox]
  ///
  CesiumBoundingVolume getBoundingVolume(CesiumTile tile,
      {bool convertRegionToOrientedBox = false}) {
    final volume = g.CesiumTile_getBoundingVolume(
        tile, convertRegionToOrientedBox ? 1 : 0);

    switch (volume.type) {
      case g.CesiumBoundingVolumeType.CT_BV_ORIENTED_BOX:
        return CesiumBoundingVolumeOrientedBox(
            Matrix3.fromList([
              volume.volume.orientedBox.halfAxes[0],
              volume.volume.orientedBox.halfAxes[1],
              volume.volume.orientedBox.halfAxes[2],
              volume.volume.orientedBox.halfAxes[3],
              volume.volume.orientedBox.halfAxes[4],
              volume.volume.orientedBox.halfAxes[5],
              volume.volume.orientedBox.halfAxes[6],
              volume.volume.orientedBox.halfAxes[7],
              volume.volume.orientedBox.halfAxes[8]
            ]),
            Vector3(
                volume.volume.orientedBox.center[0],
                volume.volume.orientedBox.center[1],
                volume.volume.orientedBox.center[2]));
      case g.CesiumBoundingVolumeType.CT_BV_REGION:
        return CesiumBoundingVolumeRegion(
            east: volume.volume.region.east,
            west: volume.volume.region.west,
            north: volume.volume.region.north,
            south: volume.volume.region.south,
            maxHeight: volume.volume.region.maximumHeight,
            minHeight: volume.volume.region.minimumHeight);
      case g.CesiumBoundingVolumeType.CT_BV_SPHERE:
        return CesiumBoundingVolumeSphere(
            Vector3(volume.volume.sphere.center[0],
                volume.volume.sphere.center[1], volume.volume.sphere.center[2]),
            volume.volume.sphere.radius);
      default:
        throw Exception("Unknown bounding volume type : ${volume.type}");
    }
  }

  ///
  ///
  ///
  double squaredDistanceToBoundingVolume(
      CesiumView viewState, CesiumTile tile) {
    return g.CesiumTile_squaredDistanceToBoundingVolume(
        tile, _toStruct(viewState));
  }

  ///
  ///
  ///
  CesiumGltfModel getModel(CesiumTile tile) {
    var model = g.CesiumTile_getModel(tile);
    if (model == nullptr) {
      throw Exception(
          "Failed to retrieve model. Check that this tile actually has render content.");
    }
    return model;
  }

  Matrix4 getGltfTransform(CesiumGltfModel model) {
    var result = g.CesiumGltfModel_getTransform(model);
    return Matrix4(
      result.col1[0],
      result.col1[1],
      result.col1[2],
      result.col1[3],
      result.col2[0],
      result.col2[1],
      result.col2[2],
      result.col2[3],
      result.col3[0],
      result.col3[1],
      result.col3[2],
      result.col3[3],
      result.col4[0],
      result.col4[1],
      result.col4[2],
      result.col4[3],
    );
  }

  SerializedCesiumGltfModel serializeGltfData(CesiumGltfModel model) {
    var data = g.CesiumGltfModel_serialize(model, _length);

    return SerializedCesiumGltfModel(data, _length.value);
  }

  CesiumTileSelectionState getSelectionState(
      CesiumTileset tileset, CesiumTile tile) {
    var state =
        g.CesiumTile_getTileSelectionState(tile, getLastFrameNumber(tileset));
    return CesiumTileSelectionState.values[state];
  }

  Future destroy(CesiumTileset tileset) async {
    final completer = Completer<void>();
    late NativeCallable<Void Function()> onDestroy;
    onDestroy = NativeCallable<Void Function()>.listener(() {
      completer.complete();
      onDestroy.close();
    });

    g.CesiumTileset_destroy(tileset._ptr, onDestroy.nativeFunction);

    int iters = 0;

    while (!completer.isCompleted) {
      await Future.delayed(Duration(milliseconds: 100));
      g.CesiumTileset_pumpAsyncQueue();
      iters++;
      if (iters > 100) {
        throw Exception(
            "Failed to destroy tile within 10 seconds. This suggests an error");
      }
    }
  }
}