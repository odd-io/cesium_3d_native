import 'dart:async';
import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/tileset_options.dart';
import 'package:cesium_3d_tiles/src/cesium_native/cesium_native.dart';
import 'package:logging/logging.dart';
import 'cesium_3d_tile.dart';
import 'transforms.dart';
import 'package:vector_math/vector_math_64.dart';

///
/// A Tileset can be assigned a numeric layer from 0 to 6 (inclusive).
///
/// This is used to group tilesets together if you want to toggle visibility.
///
/// This is also used to determine rendering priority. Higher values are
/// rendered after lower values (meaning if depth testing is disabled, higher
/// render layers will always appear "on top" of lower render layers)
///
/// The renderer should always enable depth testing at render layer 0 and
/// disable depth testing for all higher layers.
///
/// Markers are always at render layer 6.
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
  final _logger = Logger("Cesium3DTileset");

  ///
  /// A name used for debugging.
  ///
  final String? debugName;

  ///
  /// A handle to the native CesiumTileset managed by this instance.
  final CesiumTileset _tileset;

  /// Markers are always at render layer 0, this should be between 1 and 6 (inclusive).
  final RenderLayer renderLayer;

  ///
  bool disableDepthWrite = false;

  CesiumView _view = CesiumView(Vector3.zero(), Vector3(0, 0, -1),
      Vector3(0, 1, 0), 100, 100, pi / 4, pi / 4);

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
  Cesium3DTileset._(this._tileset, this.renderLayer, {this.debugName}) {
    CesiumNative.instance.updateTilesetView(_tileset, _view);
  }

  static Future<Cesium3DTileset> fromUrl(String url,
      {TilesetOptions tilesetOptions = const TilesetOptions(),
      RenderLayer renderLayer = RenderLayer.layer0}) async {
    var tileset = await CesiumNative.instance.loadFromUrl(url, tilesetOptions);
    return Cesium3DTileset._(tileset, renderLayer);
  }

  ///
  ///
  ///
  static Future<Cesium3DTileset> fromCesiumIon(int assetId, String accessToken,
      {TilesetOptions tilesetOptions = const TilesetOptions(),
      RenderLayer renderLayer = RenderLayer.layer0}) async {
    var tileset = await CesiumNative.instance
        .loadFromCesiumIon(assetId, accessToken, tilesetOptions);
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
  /// Returns the distance from [point] to the nearest point on the WGS84
  /// ellipsoid.
  ///
  double? getDistanceToSurface({Vector3? point}) {
    if (point != null) {
      final cartographicPosition = CesiumNative.instance
          .getCartographicPositionForPoint((gltfToEcef * point));
      return cartographicPosition.height;
    }
    if (rootTile == null) {
      return null;
    }
    final cartographicPosition =
        CesiumNative.instance.getCartographicPosition(_view);
    return cartographicPosition.height;
  }

  ///
  /// Returns the distance from the camera to the nearest point on the bounding
  /// volume of the WGS84 ellipsoid.
  ///
  double? getDistanceToBoundingVolume() {
    if (rootTile == null) {
      return null;
    }
    return sqrt(CesiumNative.instance
        .squaredDistanceToBoundingVolume(_view, rootTile!));
  }

  ///
  /// Returns the position (in Cartesian glTF coordinates) of the given
  /// cartographic position.
  ///
  static Vector3 cartographicToCartesian(
      double latitudeInRadians, double longitudeInRadians,
      {double height = 0}) {
    final cartesian = CesiumNative.instance.getCartesianPositionForCartographic(
        latitudeInRadians, longitudeInRadians,
        height: height);
    return ecefToGltf * cartesian;
  }

  ///
  ///
  ///
  Matrix4 getTransform(CesiumTile tile) {
    var transform = CesiumNative.instance.getTransform(tile);
    return transform;
  }

  ///
  ///
  ///
  Vector3? getTileCenter(CesiumTile tile) {
    var volume = CesiumNative.instance
        .getBoundingVolume(tile, convertRegionToOrientedBox: true);
    if (volume is CesiumBoundingVolumeOrientedBox) {
      return (ecefToGltf *
              Vector4(volume.center.x, volume.center.y, volume.center.z, 1.0))
          .xyz;
    } else if (volume is CesiumBoundingVolumeRegion) {
      // should never happen
      throw UnimplementedError();
    } else if (volume is CesiumBoundingVolumeSphere) {
      return (ecefToGltf *
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
  Future<List<Cesium3DTile>> updateCameraAndViewport(
      Vector3 cameraPosition,
      Vector3 upVector,
      Vector3 forwardVector,
      double horizontalFovInRadians,
      double verticalFovInRadians,
      double viewportWidth,
      double viewportHeight) async {
    var start = DateTime.now();

    cameraPosition = gltfToEcef * cameraPosition;
    upVector = gltfToEcef * upVector;
    forwardVector = gltfToEcef * forwardVector;

    _view = CesiumView(
        cameraPosition,
        forwardVector.normalized(),
        upVector.normalized(),
        viewportWidth,
        viewportHeight,
        horizontalFovInRadians,
        verticalFovInRadians);
    start = DateTime.now();

    var renderableTileCount =
        await CesiumNative.instance.updateTilesetView(_tileset, _view);
    var elapsed =
        DateTime.now().millisecondsSinceEpoch - start.millisecondsSinceEpoch;
    start = DateTime.now();
    var tiles = <Cesium3DTile>[];
    if (_rootTile != null && renderableTileCount > 0) {
      final renderableTiles =
          CesiumNative.instance.getRenderableTiles(_rootTile!);
      for (final tile in renderableTiles) {
        var tileSelectionState =
            CesiumNative.instance.getSelectionState(_tileset, tile);
        tiles.add(Cesium3DTile(tile, tileSelectionState, this));
      }
    }
    return tiles;
  }

  final _models = <CesiumTile, SerializedCesiumGltfModel>{};

  Future<Matrix4> applyRtcCenter(CesiumTile tile, Matrix4 transform) async {
    var model = CesiumNative.instance.getModel(tile);
    return CesiumNative.instance.applyRtcCenter(model!, transform);
  }

  Future<Uint8List?> loadGltf(CesiumTile tile) async {
    if (!_models.containsKey(tile)) {
      var model = CesiumNative.instance.getModel(tile);
      if (model == null) {
        _logger.severe("Failed to load");
        return null;
      }
      var serialized = await CesiumNative.instance.serializeGltfData(model);

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
}
