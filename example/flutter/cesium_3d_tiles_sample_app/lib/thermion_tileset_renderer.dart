import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:vector_math/vector_math_64.dart';

///
/// An implementation of [BaseTilesetRenderer] using the Thermion rendering
/// toolkit.
///
/// Use this as a reference if you wish to create a [BaseTilesetRenderer]
/// implementation using an alternative renderer (e.g. flutter_scene).
///
class ThermionTilesetRenderer extends TilesetRenderer<ThermionAsset> {
  static const int _MARKER_VISIBILITY_LAYER = 5;

  final ThermionViewer _viewer;

  final _markers = <ThermionAsset, RenderableMarker>{};

  ///
  ///
  ///
  ThermionTilesetRenderer(this._viewer) {
    // _viewer.pickResult.listen((result) async {
    //   _markers[result.entity]?.onClick();
    // });

    // enable visibility for all layers by default
    for (final layer in RenderLayer.values) {
      _viewer.setLayerVisibility(VisibilityLayers.values[layer.index], true);
    }

    updateCameraProjectionMatrix();
  }

  ///
  ///
  ///
  Future updateCameraProjectionMatrix() async {
    final cam = await _viewer.getActiveCamera();

    var dims = await viewportDimensions;

    if (dims.width == 0 || dims.height == 0) {
      return;
    }

    double aspectRatio = dims.width / dims.height;

    var distToSurface = _distanceToSurface ?? 100000000000;

    distToSurface = max(1, distToSurface);

    final near = 0.1;
    final far = distToSurface * 100.0;

    var projMat = makePerspectiveMatrix(
        await verticalFovInRadians, aspectRatio, near, far);

    await cam.setProjectionMatrixWithCulling(projMat, near, far);

    await _viewer.setViewFrustumCulling(false);
  }

  ///
  ///
  ///
  @override
  Future<ThermionAsset> loadGlb(
      Uint8List glb, Matrix4 transform, Cesium3DTile tile) async {
    if (glb.isEmpty) {
      throw Exception();
    }
    var start = DateTime.now();
    var asset = await _viewer.loadGltfFromBuffer(glb,
        priority: tile.tileset.renderLayer.index,
        layer: tile.tileset.renderLayer.index,
        loadResourcesAsync: true
      );

    await asset.setTransform(transform);

    final visibilityLayer = VisibilityLayers.values[tile.tileset.renderLayer.index];
    await asset.setVisibilityLayer(asset.entity, visibilityLayer);
    for (final child in await asset.getChildEntities()) {
      await asset.setVisibilityLayer(child, visibilityLayer);
    }
    
    return asset;
  }

  ///
  ///
  ///
  @override
  Future setLayerVisibility(RenderLayer renderLayer, bool visible) async {
    final visibilityLayer = VisibilityLayers.values[renderLayer.index];
    await _viewer.setLayerVisibility(visibilityLayer, visible);
  }

  ///
  ///
  ///
  @override
  Future<double> get horizontalFovInRadians async {
    final camera = await _viewer.getActiveCamera();
    var fovInDegrees = await camera.getHorizontalFieldOfView();
    return fovInDegrees * degrees2Radians;
  }

  ///
  ///
  ///
  @override
  Future<double> get verticalFovInRadians async {
    final camera = await _viewer.getActiveCamera();
    var fovInDegrees = await camera.getVerticalFieldOfView();
    return fovInDegrees * degrees2Radians;
  }

  ///
  ///
  ///
  @override
  Future<Matrix4> get cameraModelMatrix async {
    final camera = await _viewer.getActiveCamera();
     return camera.getModelMatrix();
  }

  ///
  ///
  ///
  @override
  Future setCameraModelMatrix(Matrix4 modelMatrix) async {
    final camera = await _viewer.getActiveCamera();
    camera.setModelMatrix(modelMatrix);
  }

  ///
  ///
  ///
  @override
  Future<({int width, int height})> get viewportDimensions async {
    var view = await _viewer.view;
    var viewport = await view.getViewport();
    return (width: viewport.width, height: viewport.height);
  }

  ///
  ///
  ///
  @override
  Future removeEntity(ThermionAsset entity) async {
    await _viewer.removeFromScene(entity);
  }

  ///
  ///
  ///
  @override
  Future<ThermionAsset> loadMarker(RenderableMarker marker) async {
    late ThermionAsset entity;
    switch (marker.type) {
      case RenderableMarkerType.gltf:
        final glbPath = (marker as GltfRenderableMarker).uri;
        entity = await _viewer.loadGltf(glbPath.path, loadAsync: true);
        break;
      case RenderableMarkerType.geometry:
        final geometryMarker = (marker as GeometryRenderableMarker);
        final geometry = switch (geometryMarker.geometryType) {
          GeometryType.sphere => GeometryHelper.sphere(),
          GeometryType.cube => GeometryHelper.cube()
        };
        late MaterialInstance mi = "foo" as MaterialInstance;
        // mi =
        //     await _viewer.createUnlitFixedSizeMaterialInstance();
        await mi.setParameterFloat("scale", 10.0);
        entity = await _viewer.createGeometry(geometry,
            materialInstances: [mi]);
        await mi.setParameterInt('baseColorIndex', 0);
        await mi.setParameterFloat4('baseColorFactor', 
            marker.r, marker.g, marker.b, marker.a);
        await mi.setDepthCullingEnabled(true);
        await mi.setDepthWriteEnabled(true);
        break;
    }
    final markerVisibilityLayer = VisibilityLayers.values[_MARKER_VISIBILITY_LAYER];
    await entity.setVisibilityLayer(entity.entity, markerVisibilityLayer);

    await entity.setTransform(Matrix4.translation(Vector3(marker.position.x, marker.position.y, marker.position.z)));
    await _viewer.setPriority(entity.entity, 7);
    await _viewer.setLayerVisibility(markerVisibilityLayer, true);
    _markers[entity] = marker;
    return entity;
  }

  @override
  Future setEntityVisibility(ThermionAsset asset, bool visible) {
    if (visible) {
      return _viewer.addToScene(asset);
    } else {
      return _viewer.removeFromScene(asset);
    }
  }

  double? _distanceToSurface;

  @override
  Future setDistanceToSurface(double? distance) async {
    _distanceToSurface = distance;
  }

  @override
  Future setEntityTransform(ThermionAsset entity, Matrix4 transform) async {
    await entity.setTransform(transform);
  }

  @override
  Future<Matrix4> getEntityTransform(ThermionAsset entity) {
    return entity.getWorldTransform();
  }
}
