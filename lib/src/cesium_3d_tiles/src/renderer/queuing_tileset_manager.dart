import 'dart:async';

import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/cesium_3d_tileset.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/renderer/markers.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/renderer/tileset_manager.dart';

import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/renderer/tileset_renderer.dart';
import 'package:cesium_3d_tiles/src/cesium_native/src/cesium_native.dart';
import 'package:vector_math/vector_math_64.dart';

import '../cesium_3d_tile.dart';

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
class QueueingTilesetManager<T> extends TilesetManager {
  
  final _loaded = <Cesium3DTile>{};
  final _loadQueue = <Cesium3DTile>{};
  final _cullQueue = <Cesium3DTile>{};

  bool _handlingQueue = false;
  bool _cameraDirty = false;

  Timer? _timer;
  DateTime? _lastTileUpdate;

  final _layers = <Cesium3DTileset, List<CesiumTile>>{};
  final _entities = <Cesium3DTile, T>{};

  DateTime _loadBookmark = DateTime.now();
  int _numLoaded = 0;

  final TilesetRenderer<T> renderer;

  /// Creates a new instance of BaseTilesetRenderer.
  ///
  /// This constructor initializes a periodic timer that updates the renderer
  /// and processes the load queue every 16 milliseconds.
  QueueingTilesetManager(this.renderer) {
    _timer = Timer.periodic(const Duration(milliseconds: 4), (_) async {
      // skip all updates if we haven't finished the last iteration
      if (_handlingQueue) {
        return;
      }

      var dimensions = await renderer.viewportDimensions;
      var now = DateTime.now();
      var msSinceLastTileUpdate = _lastTileUpdate == null
          ? 9999
          : now.millisecondsSinceEpoch -
              _lastTileUpdate!.millisecondsSinceEpoch;
      if (dimensions.width > 0 &&
          dimensions.height > 0 &&
          _cameraDirty &&
          msSinceLastTileUpdate > 16) {
        await _update();
        _lastTileUpdate = DateTime.now();
        _cameraDirty = false;
        if (_lastTileUpdate!.millisecondsSinceEpoch -
                _loadBookmark.millisecondsSinceEpoch >
            1000) {
          print("_numLoaded $_numLoaded (${_loadQueue.length} left in queue)");
          _loadBookmark = _lastTileUpdate!;
          _numLoaded = 0;
        }
      }

      _handlingQueue = true;

      while (_loadQueue.isNotEmpty) {
        var item = _loadQueue.first;
        await _load(item);
        _loadQueue.remove(item);
      }

      while (_cullQueue.isNotEmpty) {
        var tile = _cullQueue.first;
        await _remove(tile);
        _cullQueue.remove(tile);
      }
      _handlingQueue = false;
    });
  }

  Future _remove(Cesium3DTile tile) async {
    if (_loaded.contains(tile)) {
      final entity = _entities[tile];
      if (entity != null) {
        await renderer.removeEntity(entity);
      }

      _entities.remove(tile);

      _loaded.remove(tile);
      tile.freeGltf();
    }
  }

  void markDirty() {
    _cameraDirty = true;
  }

  final _loading = <Cesium3DTile>{};

  Future _load(Cesium3DTile tile) async {
    
    if (_loaded.contains(tile) || _loading.contains(tile)) {
      return;
    }
    if (_entities.containsKey(tile)) {
      throw Exception("FATAL");
    }
    _loading.add(tile);

    final data = await tile.loadGltf();

    if (data == null) {
      return;
    }

    var transform = tile.getTransform();

    renderer.loadGlb(data, transform, tile.tileset).then((entity) async {
      _entities[tile] = entity;

      _loaded.add(tile);

      await _reveal(tile);
      _numLoaded++;
      _loading.remove(tile);
    });
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
    renderer.setLayerVisibility(layer.renderLayer, true);
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
    var entity = await renderer.loadMarker(marker);
    _markers[entity] = marker;
  }


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
        await renderer.removeEntity(entity);
      }
    }

    _layers.remove(layer);
    await layer.dispose();
    _layers.remove(layer);
  }

  

  /// Gets the distance from the camera to the surface of the first layer.
  ///
  /// @return The distance to the surface, or null if there are no layers.
  @override
  Future<double?> getDistanceToSurface() async {
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


  /// Resets the camera orientation such that it is looking at the root tile.
  ///
  /// In this implementation, the camera always looks at the origin.
  /// This method sets its position is determined by taking the center of
  /// the root tile of the first layer loaded,
  /// then translating along the forward vector by the ratio between the
  /// distance from the origin and the Z extent of the bounding volume.
  ///
  /// This achieves a reasonable starting position for the camera, so that
  /// the entirety of the root tile of the first layer is visible on load.
  ///
  /// @param tileset The tileset to use for determining the root position.
  /// @param offset Whether to apply an offset to the camera position.
  /// @return A Future that completes when the camera position is set.
  @override
  Future<Matrix4> getCameraPositionForTileset(Cesium3DTileset tileset,
      {bool offset = false}) async {
    if (tileset.rootTile == null || tileset.isRootTileLoaded() == false) {
      throw Exception("Root tile not set or not yet loaded");
    }

    return _getCameraTransformForTile(tileset, offset: offset);

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
    }

    Vector3 forward =
        position.length == 0 ? Vector3(0, 0, -1) : (-position).normalized();

    var up = Vector3(0, 1, 0);
    final right = up.cross(forward)..normalize();
    up = forward.cross(right);

    // Create the model matrix
    Matrix4 viewMatrix = makeViewMatrix(position, Vector3.zero(), up);
    viewMatrix.invert();

    return viewMatrix;
  }

  Future _hide(Cesium3DTile tile) async {
    var entity = _entities[tile];
    // we may call this method before the tile content is actually loaded
    // this is fine, just ignore it if not
    if (entity != null) {
      await renderer.setEntityVisibility(entity, false);
    }
  }

  Future _reveal(Cesium3DTile tile) async {
    // we may call this method before the tile content is actually loaded
    // this is fine, just ignore it if not
    var entity = _entities[tile];

    if (entity != null) {
      await renderer.setEntityVisibility(entity, true);
    }
  }

  final _renderable = <Cesium3DTile>{};

  bool _updating = false;

  Future _update() async {
    if (_updating) {
      return;
    }
    _updating = true;
    var viewport = await renderer.viewportDimensions;
    for (final layer in _layers.keys) {
      var renderable = layer
          .updateCameraAndViewport(
              await renderer.cameraModelMatrix,
              await renderer.horizontalFovInRadians,
              await renderer.verticalFovInRadians,
              viewport.width.toDouble(),
              viewport.height.toDouble())
          .toSet();

      // if any tiles are no longer renderable, we can remove them straight away
      var disjunction = renderable.difference(_renderable);
      for (var tile in disjunction) {
        await _remove(tile);
      }

      _renderable.clear();
      _renderable.addAll(renderable);

      for (var tile in _renderable) {
        switch (tile.state) {
          case CesiumTileSelectionState.Rendered:
            if (!_loaded.contains(tile)) {
              _loadQueue.add(tile);
            }
            await _reveal(tile);

          case CesiumTileSelectionState.Refined:
          //noop
          // await _hide(tile);
          // _loadQueue.remove(tile);
          // await _hide(tile);
          // if (_loaded.contains(tile)) {
          //   await _remove(tile);
          // }

          case CesiumTileSelectionState.Culled:
            await _hide(tile);

          // _loadQueue.remove(tile);
          // if (_loaded.contains(tile)) {
          //   _cullQueue.add(tile);
          // }
          // _hide(tile);
          case CesiumTileSelectionState.None:
          // await _hide(tile);
          // _loadQueue.remove(tile);
          // if (_loaded.contains(tile)) {
          //   _cullQueue.add(tile);
          // }
          // _hide(tile);

          //noop
          case CesiumTileSelectionState.RenderedAndKicked:
          // _loadQueue.remove(tile);
          // _hide(tile);
          // if (_loaded.contains(tile)) {
          //   _cullQueue.add(tile);
          // }
          case CesiumTileSelectionState.RefinedAndKicked:
          // _loadQueue.remove(tile);
          // _hide(tile);
          // if (_loaded.contains(tile)) {
          //   _cullQueue.add(tile);
          // }
        }
      }
    }
    final cameraPosition = (await renderer.cameraModelMatrix).getTranslation();
    for (final marker in _markers.entries) {
      bool isVisible = (cameraPosition - marker.value.position).length <
          marker.value.visibilityDistance;
      await renderer.setEntityVisibility(marker.key, isVisible);
    }
    _updating = false;
  }
  

}
