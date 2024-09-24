import 'dart:typed_data';

import 'package:cesium_3d_tiles/cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../cesium_native/src/cesium_native.dart';
export '../../cesium_native/src/cesium_tile_selection_state.dart';

class Cesium3DTile {
  final CesiumTile _tile;
  final Cesium3DTileset tileset;
  final CesiumTileSelectionState state;

  Cesium3DTile(this._tile, this.state, this.tileset);

  Uint8List loadGltf() {
    return tileset.loadGltf(_tile);
  }

  Future freeGltf() async { 
    tileset.freeGltf(_tile);
  }

  Matrix4 getTransform() {
    return tileset.getTransform(_tile);
  }
}
