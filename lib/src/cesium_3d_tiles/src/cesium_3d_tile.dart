import 'dart:typed_data';
import 'dart:math';
import 'package:cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../cesium_native/src/cesium_native.dart';
export '../../cesium_native/src/cesium_tile_selection_state.dart';

class Cesium3DTile {
  final CesiumTile _tile;
  final Cesium3DTileset tileset;
  final CesiumTileSelectionState state;

  Cesium3DTile(this._tile, this.state, this.tileset);

  Future<Uint8List?> loadGltf() {
    return tileset.loadGltf(_tile);
  }

  Future<Matrix4> applyRtcCenter(Matrix4 transform) {
    return tileset.applyRtcCenter(_tile, transform);
  }

  Future freeGltf() async {
    tileset.freeGltf(_tile);
  }

  Matrix4 getTransform() {
    return tileset.getTransform(_tile);
  }

  Vector3? getBoundingVolumeCenter() {
    return tileset.getBoundingVolumeCenter(_tile);
  }

  Vector3 getExtent() {
    return tileset.getExtent(_tile);
  }

  ///
  /// Returns the squared distance from [point] to the bounding volume for this 
  /// tile.
  /// 
  double distanceToBoundingVolume(Vector3 point) {
    return tileset.getDistanceToBoundingVolume(point, _tile);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cesium3DTile &&
          runtimeType == other.runtimeType &&
          _tile == other._tile;

  @override
  int get hashCode => _tile.hashCode;
}
