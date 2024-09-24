import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:cesium_3d_tiles/cesium_3d_tiles.dart';
import 'transforms.dart';
import 'package:vector_math/vector_math_64.dart';

enum RenderLayer {
  layer0, layer1, layer2, layer3, layer4, 
}

///
/// A high-level interface for a Cesium 3D Tiles tileset.
/// [Cesium3DTilesetLayer] does not render anything to a screen;
/// [updateCameraAndViewport]
///
class Cesium3DTilesetLayer {
  ///
  /// A name used for debugging.
  ///
  final String? debugName;

  final CesiumTileset _tileset;

  ///
  /// The render layer that will determine both the visibility and the render
  /// priority for this tileset.
  ///
  /// Markers are always at render layer 0, this should be between 1 and 6 (inclusive).
  ///
  final RenderLayer renderLayer;

  late CesiumView _view =
      CesiumView(Vector3.zero(), Vector3.zero(), Vector3.zero(), 0, 0, 0);

  CesiumTile? _rootTile;

  CesiumTile? get rootTile {
    _rootTile ??= Cesium3D.instance.getRootTile(_tileset);
    return _rootTile;
  }

  Future dispose() async {
    Cesium3D.instance.destroy(_tileset);
  }

  ///
  ///
  ///
  Cesium3DTilesetLayer._(this._tileset, this.renderLayer, {this.debugName});

  static Future<Cesium3DTilesetLayer> fromUrl(String url,
      {RenderLayer renderLayer = RenderLayer.layer0}) async {
    var tileset = await Cesium3D.instance.loadFromUrl(url);
    return Cesium3DTilesetLayer._(tileset, renderLayer);
  }

  static Future<Cesium3DTilesetLayer> fromCesiumIon(
      int assetId, String accessToken,
      {RenderLayer renderLayer = RenderLayer.layer0}) async {
    var tileset =
        await Cesium3D.instance.loadFromCesiumIon(assetId, accessToken);
    return Cesium3DTilesetLayer._(tileset, renderLayer,
        debugName: "ion:$assetId");
  }

  bool isRootTileLoaded() {
    if (rootTile == null) {
      return false;
    }
    return Cesium3D.instance.getLoadState(rootTile!) ==
        CesiumTileLoadState.Done;
  }

  double? getDistanceToSurface() {
    if (rootTile == null) {
      return null;
    }
    final cartographicPosition =
        Cesium3D.instance.getCartographicPosition(_view);
    return cartographicPosition.height;
  }

  double? getDistanceToBoundingVolume() {
    if (rootTile == null) {
      return null;
    }
    return sqrt(
        Cesium3D.instance.squaredDistanceToBoundingVolume(_view, rootTile!));
  }

  Matrix4 getTransform(CesiumTile tile) {
    var transform = Cesium3D.instance.getTransform(tile);
    return ecefToGltf * transform * gltfToEcef;
  }

  Vector3? getTileCenter(CesiumTile tile) {
    var volume = Cesium3D.instance
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

  double getLoadProgress() {
    return Cesium3D.instance.computeLoadProgess(_tileset);
  }

  Iterable<({CesiumTile tile, CesiumTileSelectionState state})>
      updateCameraAndViewport(Matrix4 modelMatrix, Matrix4 projectionMatrix,
          double viewportWidth, double viewportHeight) sync* {
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
    Cesium3D.instance.updateTilesetView(_tileset, _view);

    if (_rootTile != null) {
      final renderableTiles = Cesium3D.instance.getRenderableTiles(_rootTile!);
      for (final tile in renderableTiles) {
        var tileSelectionState =
            Cesium3D.instance.getSelectionState(_tileset, tile);
        yield (tile: tile, state: tileSelectionState);
      }
    }
  }

  final _models = <CesiumTile, SerializedCesiumGltfModel>{};

  Uint8List load(CesiumTile tile) {
    if (!_models.containsKey(tile)) {
      var model = Cesium3D.instance.getModel(tile);
      var serialized = Cesium3D.instance.serializeGltfData(model);
      _models[tile] = serialized;
    }
    return _models[tile]!.data;
  }

  void free(CesiumTile tile) {
    _models[tile]?.free();
    _models.remove(tile);
  }

  Vector3 getExtent(CesiumTile tile) {
    Vector3? extent;
    var volume = Cesium3D.instance
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
    var volume = Cesium3D.instance.getBoundingVolume(tile,
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
    final renderableTiles = Cesium3D.instance.getRenderableTiles(rootTile!);
    print(Cesium3D.instance.getSelectionState(_tileset, rootTile!));
    for (final tile in renderableTiles) {
      print(Cesium3D.instance.getSelectionState(_tileset, tile));
      var model = Cesium3D.instance.getModel(tile);
      print(Cesium3D.instance.getGltfTransform(model));
    }
  }
}
