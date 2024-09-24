import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cesium_3d_tiles/cesium_3d_tiles/src/cesium_3d_tileset.dart';
import 'package:cesium_3d_tiles/cesium_3d_tiles/src/renderer/markers.dart';
import 'package:cesium_3d_tiles/cesium_3d_tiles/src/renderer/tileset_renderer.dart';
import 'package:cesium_3d_tiles/cesium_native/src/cesium_native.dart';
import 'package:vector_math/vector_math_64.dart';

///
/// A partial implementation of [TilesetRenderer].
///
/// This uses a Timer to periodically update tileset(s) with the current camera
/// matrix and load/remove gltf content as necessary.
///
/// This class only describes the methods needed to load gltf models and insert
/// into the current rendering scene; you will need to implement these yourself
/// using your own chosen rendering framework.
///
/// The generic parameter [T] is the type of the entity handle returned by the
/// actual rendering library.
///
abstract class BaseTilesetRenderer<T> extends TilesetRenderer {
  final _loaded = <CesiumTile>{};
  final _loadQueue = <(Cesium3DTileset, CesiumTile)>[];
  final _cullQueue = <(Cesium3DTileset, CesiumTile)>[];

  bool _handlingQueue = false;
  bool _updateCamera = true;

  Timer? _timer;

  final _layers = <Cesium3DTileset, List<CesiumTile>>{};
  final _entities = <CesiumTile, T>{};

  /// Creates a new instance of BaseTilesetRenderer.
  ///
  /// This constructor initializes a periodic timer that updates the renderer
  /// and processes the load queue every 16 milliseconds.
  BaseTilesetRenderer() {
    _timer = Timer.periodic(const Duration(milliseconds: 8), (_) async {
      if (_handlingQueue) {
        return;
      }

      if (viewportDimensions.$1 > 0 && _updateCamera) {
        await _update();
      }

      _handlingQueue = true;

      if (_loadQueue.isNotEmpty) {
        var item = _loadQueue.removeLast();
        var tileset = item.$1;
        var tile = item.$2;
        await _load(tile, tileset);
      }

      if (_cullQueue.isNotEmpty) {
        var item = _cullQueue.removeLast();
        var tile = item.$2;
        await _remove(tile, item.$1);
      }
      _handlingQueue = false;
    });
  }

  Future _remove(CesiumTile tile, Cesium3DTileset tileset) async {
    if (_loaded.contains(tile)) {
      final entity = _entities[tile];
      if (entity != null) {
        await removeEntity(entity);
      }

      _entities.remove(tile);

      _loaded.remove(tile);
      tileset.free(tile);
    }
  }

  Future _load(CesiumTile tile, Cesium3DTileset tileset) async {
    late T entity;
    if (!_loaded.contains(tile)) {
      if (_entities.containsKey(tile)) {
        throw Exception("FATAL");
      }

      final data = tileset.load(tile);

      var transform = tileset.getTransform(tile);

      entity = await loadGlb(data, transform, tileset);

      _entities[tile] = entity;

      _loaded.add(tile);
    }

    await _reveal(tile, tileset);
  }

  /// Adds a new [Cesium3DTileset] to the renderer.
  ///
  /// This method adds the layer to the internal list of layers and sets its visibility to true.
  ///
  /// @param layer The layer to be added.
  @override
  void addLayer(Cesium3DTileset layer) async {
    if (_layers.containsKey(layer)) {
      throw Exception("Layer has already been added");
    }
    _layers[layer] = <CesiumTile>[];
    setLayerVisibility(layer.renderLayer, true);
  }

  ///
  ///
  ///
  final Map<T, RenderableMarker> _markers = {};

  ///
  ///
  ///
  RenderableMarker? getMarkerForEntity(T entity) {
    return _markers[entity];
  }

  ///
  /// Adds a new [RenderableMarker] to the scene.
  ///
  /// @param marker The marker to be added.
  @override
  Future addMarker(RenderableMarker marker) async {
    var entity = await loadMarker(marker);
    _markers[entity] = marker;
  }

  ///
  /// This method loads/inserts renderable tile content (as a glTF) into the
  /// scene.
  /// Implementations of this method must:
  /// - load the glTF content
  /// - insert into the scene and retrieve an entity handle of type [T]
  /// - set the global transform for the entity to [transform]
  /// - set the rendering priority for the entity to the layer's [renderLayer]
  /// (where 0 is the highest priority, and 7 is the lowest)
  /// - set the visibility group for the entity to the layer's [renderLayer]
  ///
  /// [priority] is used to determine the order in which entities are drawn;
  /// layers that should appear above other layers should be assigned a higher
  /// priority.
  ///
  /// @param glb The tile's binary glTF data
  /// @param transform The tile's global transform
  /// @param priority The rendering priority of the model.
  /// @return A Future that resolves to the loaded entity.
  Future<T> loadGlb(Uint8List glb, Matrix4 transform, Cesium3DTileset layer);

  ///
  /// Loads a marker into the scene and ensures that its [onClick] method
  /// is called whenever the marker is tapped in the viewport.
  ///
  /// @param marker The marker to load and insert into the scene.
  /// @return A Future that resolves to the loaded entity.
  Future<T> loadMarker(RenderableMarker marker);

  /// Removes a previously loaded GLB model from the scene.
  ///
  /// @param entity The entity to be removed.
  /// @return A Future that completes when the entity is removed.
  Future removeEntity(T entity);

  ///
  /// Sets the visibility of a renderable entity.
  ///
  /// This is only intended for use with markers; layer/tile visibility is managed by calling [setLayerVisibility]
  ///
  Future setEntityVisibility(T entity, bool visible);

  /// Removes a [Cesium3DTileset] and all its associated entities from the renderer.
  ///
  /// This method removes all entities associated with the layer, removes the layer
  /// from the internal list, disposes of the layer, and removes it from the entities map.
  ///
  /// @param layer The layer to be removed.
  /// @return A Future that completes when the layer and its entities are removed.
  @override
  Future remove(Cesium3DTileset layer) async {
    if (!_layers.containsKey(layer)) {
      throw Exception("Layer does not exist in this renderer");
    }
    for (final tile in _layers[layer]!) {
      final entity = _entities[tile];
      if (entity != null) {
        await removeEntity(entity);
      }
    }

    _layers.remove(layer);
    await layer.dispose();
    _layers.remove(layer);
  }

  /// Zooms the camera to focus on a specific layer.
  ///
  /// This method animates the camera from its current position to a position
  /// that focuses on the specified layer.
  ///
  /// @param layer The layer to zoom to.
  /// @param duration The duration of the zoom animation.
  /// @param offset Whether to apply an offset when zooming.
  /// @return A Future that completes when the zoom animation is finished.
  @override
  Future zoomTo(Vector3 target,
      {Duration duration = const Duration(seconds: 1)}) async {
    final startPosition = (await cameraModelMatrix).getTranslation();

    final startTime = DateTime.now().millisecondsSinceEpoch;
    final endTime = startTime + duration.inMilliseconds;

    final completer = Completer();

    _updateCamera = false;

    void animate() {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= endTime) {
        final interpolatedViewMatrix = _createLookAtMatrix(target);
        interpolatedViewMatrix.invert();
        setCameraModelMatrix(interpolatedViewMatrix);
        completer.complete();
        _updateCamera = true;
        return;
      }

      final t = (now - startTime) / duration.inMilliseconds;
      final easedT = _easeInOutCubic(t);

      final interpolatedPosition = Vector3(
        _lerp(startPosition.x, target.x, easedT),
        _lerp(startPosition.y, target.y, easedT),
        _lerp(startPosition.z, target.z, easedT),
      );

      final interpolatedViewMatrix = _createLookAtMatrix(interpolatedPosition);
      interpolatedViewMatrix.invert();

      setCameraModelMatrix(interpolatedViewMatrix);
      Timer(const Duration(milliseconds: 16), animate);
    }

    animate();
    return completer.future;
  }

  ///
  ///
  ///
  Matrix4 _createLookAtMatrix(Vector3 eyePosition) {
    final target = Vector3.zero();
    final up = Vector3(0, 1, 0); // Assuming Y is up
    return makeViewMatrix(eyePosition, target, up);
  }

  ///
  ///
  ///
  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
  }

  ///
  ///
  ///
  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  /// Gets the distance from the camera to the surface of the first layer.
  ///
  /// @return The distance to the surface, or null if there are no layers.
  @override
  double? getDistanceToSurface() {
    if (_layers.isEmpty) {
      return null;
    }
    return _layers.keys.first.getDistanceToSurface();
  }

  /// Disposes of the renderer and frees any resources it was using.
  ///
  /// This method cancels the update timer, removes all entities from all layers,
  /// and clears the internal lists of entities and layers.
  ///
  /// @return A Future that completes when all resources have been disposed.
  @override
  Future dispose() async {
    _timer?.cancel();
    for (final layer in _layers.keys) {
      await remove(layer);
    }
    _entities.clear();
    _layers.clear();
  }

  ///
  ///
  ///
  @override
  Future<Vector3> getTileCameraPosition(Cesium3DTileset layer) async {
    return (await _getCameraTransformForTile(layer)).getTranslation();
  }

  /// Resets the camera orientation to the "root" position.
  ///
  /// The camera is always looking at the origin. Its position is determined by
  /// taking the center of the root tile of the first layer loaded, then
  /// translating along the forward vector by the ratio between the distance
  /// from the origin and the Z extent of the bounding volume.
  ///
  /// This achieves a reasonable starting position for the camera, so that
  /// the entirety of the root tile of the first layer is visible on load.
  ///
  /// @param tileset The tileset to use for determining the root position.
  /// @param offset Whether to apply an offset to the camera position.
  /// @return A Future that completes when the camera position is set.
  @override
  Future<void> setCameraToRootPosition(Cesium3DTileset tileset,
      {bool offset = false}) async {
    if (tileset.rootTile == null || tileset.isRootTileLoaded() == false) {
      return;
    }

    var modelMatrix = await _getCameraTransformForTile(tileset, offset: offset);

    // Set the camera model matrix
    await setCameraModelMatrix(modelMatrix);
  }

  Future<Matrix4> _getCameraTransformForTile(Cesium3DTileset tileset,
      {bool offset = true}) async {
    var position = tileset.getTileCenter(tileset.rootTile!);
    if (position == null) {
      throw Exception(
          "Could not fetch root camera position; has the root tile been loaded?");
    }

    if (offset) {
      var extent = tileset.getExtent(tileset.rootTile!);
      if (position.length == 0) {
        position = extent;
      }
      // Calculate the direction vector from the center to the position
      Vector3 direction = position.normalized();

      // Scale the direction vector by the extent
      Vector3 offsetVector = direction * extent.length;

      // Apply the offset to the position
      position += offsetVector;
      // position *= 1.001;
    }

    Vector3 forward = (-position).normalized();

    var up = Vector3(0, 1, 0);
    final right = up.cross(forward)..normalize();
    up = forward.cross(right);

    // Create the model matrix
    Matrix4 viewMatrix = makeViewMatrix(position, Vector3.zero(), up);
    viewMatrix.invert();

    return viewMatrix;
  }

  Future _hide(CesiumTile tile, Cesium3DTileset layer) async {
    var entity = _entities[tile];
    if (entity != null) {
      await setEntityVisibility(entity, false);
    } else {
      print("Warning : no entity found for tile");
    }
  }

  Future _reveal(CesiumTile tile, Cesium3DTileset layer) async {
    var entity = _entities[tile];
    if (entity != null) {
      await setEntityVisibility(entity, true);
    } else {
      print("Warning : no entity found for tile");
    }
  }

  Future _update() async {
    for (final layer in _layers.keys) {
      var renderable = layer
          .updateCameraAndViewport(
              await cameraModelMatrix,
              await cameraProjectionMatrix,
              viewportDimensions.$1,
              viewportDimensions.$2)
          .toList();
      for (var tile in renderable) {
        switch (tile.state) {
          case CesiumTileSelectionState.Rendered:
            if (!_loaded.contains(tile.tile)) {
              _loadQueue.add((layer, tile.tile));
            }
          case CesiumTileSelectionState.Refined:
            if (_loaded.contains(tile.tile)) {
              await _remove(tile.tile, layer);
            }
          case CesiumTileSelectionState.Culled:
            if (_loaded.contains(tile.tile)) {
              _cullQueue.add((layer, tile.tile));
            }
          case CesiumTileSelectionState.None:
            if (_loaded.contains(tile.tile)) {
              _cullQueue.add((layer, tile.tile));
            }
          case CesiumTileSelectionState.RenderedAndKicked:
            await _hide(tile.tile, layer);
          case CesiumTileSelectionState.RefinedAndKicked:
            await _hide(tile.tile, layer);
        }
      }
    }
    final cameraPosition = (await cameraModelMatrix).getTranslation();
    for (final marker in _markers.entries) {
      bool isVisible = (cameraPosition - marker.value.position).length <
          marker.value.visibilityDistance;
      await setEntityVisibility(marker.key, isVisible);
    }
  }
}
