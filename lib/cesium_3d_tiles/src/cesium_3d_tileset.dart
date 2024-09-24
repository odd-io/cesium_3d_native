import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:cesium_3d_tiles/cesium_native/cesium_native.dart';
import 'cesium_3d_tile.dart';
import 'transforms.dart';
import 'package:vector_math/vector_math_64.dart';

///
/// When working with multiple tileset can be assigned a render layer, to determine that will determine both the visibility and the render
/// priority for this tileset.
///
/// Markers are always at render layer 0, this should be between 1 and 6 (inclusive).
///
enum RenderLayer {
  layer0,
  layer1,
  layer2,
  layer3,
  layer4,
}

///
/// A high-level interface for a Cesium 3D Tiles tileset.
///
class Cesium3DTileset {
  ///
  /// A name used for debugging.
  ///
  final String? debugName;

  ///
  /// A handle to the native CesiumTileset managed by this instance.
  final CesiumTileset _tileset;

  /// Markers are always at render layer 0, this should be between 1 and 6 (inclusive).
  final RenderLayer renderLayer;

  late CesiumView _view =
      CesiumView(Vector3.zero(), Vector3.zero(), Vector3.zero(), 0, 0, 0);

  CesiumTile? _rootTile;

  CesiumTile? get rootTile {
    _rootTile ??= CesiumNative.instance.getRootTile(_tileset);
    return _rootTile;
  }

  Future dispose() async {
    CesiumNative.instance.destroy(_tileset);
  }

  ///
  ///
  ///
  Cesium3DTileset._(this._tileset, this.renderLayer, {this.debugName});

  static Future<Cesium3DTileset> fromUrl(String url,
      {RenderLayer renderLayer = RenderLayer.layer0}) async {
    var tileset = await CesiumNative.instance.loadFromUrl(url);
    return Cesium3DTileset._(tileset, renderLayer);
  }

  ///
  ///
  ///
  static Future<Cesium3DTileset> fromCesiumIon(int assetId, String accessToken,
      {RenderLayer renderLayer = RenderLayer.layer0}) async {
    var tileset =
        await CesiumNative.instance.loadFromCesiumIon(assetId, accessToken);
    return Cesium3DTileset._(tileset, renderLayer, debugName: "ion:$assetId");
  }

  ///
  ///
  ///
  bool isRootTileLoaded() {
    if (rootTile == null) {
      return false;
    }
    return CesiumNative.instance.getLoadState(rootTile!) ==
        CesiumTileLoadState.Done;
  }

  ///
  ///
  ///
  double? getDistanceToSurface() {
    if (rootTile == null) {
      return null;
    }
    final cartographicPosition =
        CesiumNative.instance.getCartographicPosition(_view);
    return cartographicPosition.height;
  }

  ///
  ///
  ///
  double? getDistanceToBoundingVolume() {
    if (rootTile == null) {
      return null;
    }
    return sqrt(CesiumNative.instance
        .squaredDistanceToBoundingVolume(_view, rootTile!));
  }

  ///
  ///
  ///
  Matrix4 getTransform(CesiumTile tile) {
    var transform = CesiumNative.instance.getTransform(tile);
    return ecefToGltf * transform * gltfToEcef;
  }

  ///
  ///
  ///
  Vector3? getTileCenter(CesiumTile tile) {
    var volume = CesiumNative.instance
        .getBoundingVolume(tile, convertRegionToOrientedBox: true);
    var transform = ecefToGltf;
    if (volume is CesiumBoundingVolumeOrientedBox) {
      return (transform *
              Vector4(volume.center.x, volume.center.y, volume.center.z, 1.0))
          .xyz;
    } else if (volume is CesiumBoundingVolumeRegion) {
      // should never happen
      throw UnimplementedError();
    } else if (volume is CesiumBoundingVolumeSphere) {
      return (transform *
              Vector4(volume.center.x, volume.center.y, volume.center.z, 1.0))
          .xyz;
    } else {
      throw Exception("TODO");
    }
  }

  ///
  ///
  ///
  double getLoadProgress() {
    return CesiumNative.instance.computeLoadProgess(_tileset);
  }

  ///
  ///
  ///
  Iterable<Cesium3DTile> updateCameraAndViewport(
      Matrix4 modelMatrix,
      Matrix4 projectionMatrix,
      double viewportWidth,
      double viewportHeight) sync* {
    // Extract the position from the matrix
    var gltfPosition = modelMatrix.getTranslation();

    var transform = gltfToEcef;
    Vector3 position = transform * gltfPosition;
    Vector3 up = transform * Vector3(0, 1, 0);
    Vector3 forward = transform *
        (gltfPosition.length == 0 ? Vector3(0, 0, -1) : -gltfPosition);
    forward.normalize();

    double horizontalFov =
        _getHorizontalFovFromProjectionMatrix(projectionMatrix);
    _view = CesiumView(
        position, forward, up, viewportWidth, viewportHeight, horizontalFov);
    CesiumNative.instance.updateTilesetView(_tileset, _view);

    if (_rootTile != null) {
      final renderableTiles =
          CesiumNative.instance.getRenderableTiles(_rootTile!);
      for (final tile in renderableTiles) {
        var tileSelectionState =
            CesiumNative.instance.getSelectionState(_tileset, tile);
        yield Cesium3DTile(tile, tileSelectionState, this);
      }
    }
  }

  final _models = <CesiumTile, SerializedCesiumGltfModel>{};

  Uint8List loadGltf(CesiumTile tile) {
    if (!_models.containsKey(tile)) {
      var model = CesiumNative.instance.getModel(tile);
      var serialized = CesiumNative.instance.serializeGltfData(model);
      _models[tile] = serialized;
    }
    return _models[tile]!.data;
  }

  void freeGltf(CesiumTile tile) {
    _models[tile]?.free();
    _models.remove(tile);
  }

  Vector3 getExtent(CesiumTile tile) {
    Vector3? extent;
    var volume = CesiumNative.instance
        .getBoundingVolume(tile, convertRegionToOrientedBox: true);

    if (volume is CesiumBoundingVolumeOrientedBox) {
      extent = volume.halfAxes * Vector3(2, 2, 2);
    } else if (volume is CesiumBoundingVolumeSphere) {
      extent = Vector3.all(volume.radius);
    }

    if (extent == null) {
      throw Exception("TODO");
    }

    return (ecefToGltf * Vector4(extent.x, extent.y, extent.z, 1.0)).xyz;
  }

  bool isOutsideBoundingVolume(CesiumTile tile, Vector3 position) {
    var volume = CesiumNative.instance.getBoundingVolume(tile,
        convertRegionToOrientedBox: true) as CesiumBoundingVolumeOrientedBox;

    // Calculate the vector from the box center to the position
    Vector3 offset = position - volume.center;

    // Transform the offset into the local coordinate system of the box
    Matrix3 inverseHalfAxes = volume.halfAxes.clone()..invert();
    Vector3 localOffset = inverseHalfAxes * offset;

    // Check if the local offset is outside the unit cube
    return localOffset.x.abs() > 1.0 ||
        localOffset.y.abs() > 1.0 ||
        localOffset.z.abs() > 1.0;
  }

  /// Extracts the horizontal field of view from a projection matrix
  static double _getHorizontalFovFromProjectionMatrix(
      Matrix4 projectionMatrix) {
    // Get the first element of the projection matrix
    double m00 = projectionMatrix.entry(0, 0);

    // Calculate the horizontal FOV
    double horizontalFov = 2 * atan(1 / m00);

    return horizontalFov;
  }

  void getRootTileSelectionState() {
    final renderableTiles = CesiumNative.instance.getRenderableTiles(rootTile!);
    print(CesiumNative.instance.getSelectionState(_tileset, rootTile!));
    for (final tile in renderableTiles) {
      print(CesiumNative.instance.getSelectionState(_tileset, tile));
      var model = CesiumNative.instance.getModel(tile);
      print(CesiumNative.instance.getGltfTransform(model));
    }
  }
}
