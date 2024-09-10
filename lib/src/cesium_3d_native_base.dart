import 'dart:ffi';

import 'package:cesium_3d_native/src/cesium_3d_native.g.dart' as g;
import 'package:cesium_3d_native/src/cesium_view.dart';
import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math.dart';

typedef CesiumTileset = Pointer<g.CesiumTileset>;
typedef CesiumTile = Pointer<g.CesiumTile>;

class Cesium3D {
  static late Pointer<Char> _errorMessage;

  static Cesium3D? _instance;
  static Cesium3D get instance {
    _instance ??= Cesium3D._();
    return _instance!;
  }


  Cesium3D._() {
    g.CesiumTileset_initialize();
    _errorMessage = calloc<Char>(256);
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

  ///
  /// Update the tileset with the current view. Returns the number of tiles to render.
  ///
  int updateTilesetView(CesiumTileset tileset, CesiumView view) {
    int numTiles = g.CesiumTileset_updateView(tileset, _toStruct(view));
    return numTiles;
  }

  ///
  /// Throws an exception if the tileset encountered an error while loading.
  /// If no exception is thrown, this does not guarantee that the tileset has
  /// loaded successfully; it may still be pending.
  ///
  /// TODO - how to check successful load?
  ///
  void checkLoadError(CesiumTileset tileset) {
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

  ///
  /// Gets the renderable content for the tileset.
  ///
  CesiumTile getRenderContent(CesiumTileset tileset) {
    throw Exception("TODO");
  }

  // Gets the CesiumTile to render at this frame at the given index.
  // [index] must be less than the result of the last [updateTilesetView]
  // (and will only be valid until the next call to [updateTilesetView]).
  CesiumTile getTileToRenderThisFrame(CesiumTileset tileset, int index) {
    throw Exception("TODO");
  }

  ///
  /// Gets the load state for a given tile.
  ///
  int getLoadState(CesiumTile tile) {
    
    return g.CesiumTileset_getTileLoadState(tile);
  }
}
