import 'dart:ffi';
import 'dart:typed_data';

import 'package:cesium_3d_native/src/cesium_3d_native.g.dart' as g;
import 'package:cesium_3d_native/src/cesium_bounding_volume.dart';
import 'package:cesium_3d_native/src/cesium_view.dart';
import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math_64.dart';

typedef CesiumTileset = Pointer<g.CesiumTileset>;
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

class Cesium3D {
  // preallocate memory

  // error message
  static late Pointer<Char> _errorMessage;

  // int used for lengths
  static late Pointer<Uint32> _length;

  // render content
  static const int _maxRenderContent = 1024;
  static late Pointer<g.CesiumTilesetRenderableTiles> _traversalResult;

  static Cesium3D? _instance;
  static Cesium3D get instance {
    _instance ??= Cesium3D._();
    return _instance!;
  }

  Cesium3D._() {
    g.CesiumTileset_initialize();
    _errorMessage = calloc<Char>(256);
    _length = calloc<Uint32>(1);
    _traversalResult = calloc<g.CesiumTilesetRenderableTiles>(1);
    _traversalResult.ref.maxSize = _maxRenderContent;
    _traversalResult.ref.tiles =
        calloc<Pointer<g.CesiumTile>>(_maxRenderContent);
  }

  ///
  /// Load a CesiumTileset from a CesiumIonAsset with the specified token.
  ///
  CesiumTileset loadFromCesiumIon(int assetId, String accessToken) {
    final ptr = accessToken.toNativeUtf8(allocator: calloc);
    final tileset =
        g.CesiumTileset_createFromIonAsset(assetId, ptr.cast<Char>());
    calloc.free(ptr);
    if (tileset == nullptr) {
      throw Exception("Failed to fetch tileset for Cesium Ion asset $assetId");
    }
    _checkLoadError(tileset);
    return tileset;
  }

  ///
  /// Load a CesiumTileset from a url.
  ///
  CesiumTileset loadFromUrl(String url) {
    final ptr = url.toNativeUtf8(allocator: calloc);
    final tileset = g.CesiumTileset_create(ptr.cast<Char>());
    calloc.free(ptr);
    if (tileset == nullptr) {
      throw Exception("Failed to fetch tileset from url $url");
    }
    _checkLoadError(tileset);
    return tileset;
  }

  g.CesiumViewState _toStruct(CesiumView view) {
    return g.CesiumTileset_createViewState(
        view.position.x,
        view.position.y,
        view.position.z,
        view.direction.x,
        view.direction.y,
        view.direction.z,
        view.up.x,
        view.up.y,
        view.up.z,
        view.viewportWidth,
        view.viewportHeight,
        view.horizontalFov);
  }

  DateTime? _lastUpdate;

  ///
  /// Update the tileset with the current view. Returns the number of tiles to render.
  ///
  int updateTilesetView(CesiumTileset tileset, CesiumView view) {
    var now = DateTime.now();
    var delta = _lastUpdate == null
        ? 0.0
        : now.difference(_lastUpdate!).inMilliseconds / 1000.0;
    int numTiles = g.CesiumTileset_updateView(tileset, _toStruct(view), delta);
    if (numTiles == -1) {
      throw Exception("Unknown error updating tileset view");
    }
    _lastUpdate = now;
    return numTiles;
  }

  int getNumTilesKicked(CesiumTileset tileset) {
    return g.CesiumTileset_getTilesKicked(tileset);
  }

  ///
  ///
  ///
  int getNumTilesLoaded(CesiumTileset tileset) {
    return g.CesiumTileset_getNumTilesLoaded(tileset);
  }

  ///
  /// Throws an exception if the tileset encountered an error while loading.
  /// If no exception is thrown, this does not guarantee that the tileset has
  /// loaded successfully; it may still be pending.
  ///
  /// TODO - how to check successful load?
  ///
  void _checkLoadError(CesiumTileset tileset) {
    if (g.CesiumTileset_hasLoadError(tileset) == 1) {
      g.CesiumTileset_getErrorMessage(tileset, _errorMessage);
      throw Exception(_errorMessage.cast<Utf8>().toDartString());
    }
  }

  ///
  /// Fetches the root CesiumTile for the tileset.
  ///
  CesiumTile getRootTile(CesiumTileset tileset) {
    final root = g.CesiumTileset_getRootTile(tileset);
    if (root == nullptr) {
      throw Exception("No root tile");
    }
    return root;
  }

  CesiumTileContentType getTileContentType(CesiumTile tile) {
    final contentType = g.CesiumTileset_getTileContentType(tile);
    return CesiumTileContentType.values[contentType];
  }

  ///
  /// Traverses this tile and its children to fetch all render content.
  ///
  List<CesiumTile> getRenderableTiles(CesiumTile tile) {
    g.CesiumTileset_getRenderableTiles(tile, _traversalResult);

    final renderableTiles = List<CesiumTile>.generate(
        _traversalResult.ref.numTiles, (i) => _traversalResult.ref.tiles[i]);
    return renderableTiles;
  }

  // Gets the CesiumTile to render at this frame at the given index.
  // [index] must be less than the result of the last [updateTilesetView]
  // (and will only be valid until the next call to [updateTilesetView]).
  CesiumTile getTileToRenderThisFrame(CesiumTileset tileset, int index) {
    return g.CesiumTileset_getTileToRenderThisFrame(tileset, index);
  }

  ///
  /// Gets the load state for a given tile.
  ///
  CesiumTileLoadState getLoadState(CesiumTile tile) {
    var state = g.CesiumTileset_getTileLoadState(tile);
    return CesiumTileLoadState.values[state + 2];
  }

  void traverseChildren(CesiumTile tile) {
    g.CesiumTile_traverse(tile);
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
  ///
  ///
  CesiumBoundingVolume getBoundingVolume(CesiumTile tile) {
    final volume = g.CesiumTile_getBoundingVolume(tile);

    switch (volume.type) {
      case g.CesiumBoundingVolumeType.CT_BV_ORIENTED_BOX:
        return OrientedBox(
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
       
        final center = g.CesiumTile_getBoundingVolumeCenter(tile);

      case g.CesiumBoundingVolumeType.CT_BV_SPHERE:
        
      default:
        throw Exception("Unknown bounding volume type : ${volume.type}");
    }
    throw Exception("Unknown bounding volume type : ${volume.type}");
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

  SerializedCesiumGltfModel serializeGltfData(CesiumGltfModel model) {
    var data = g.CesiumGltfModel_serialize(model, _length);

    return SerializedCesiumGltfModel(data, _length.value);
  }
}
