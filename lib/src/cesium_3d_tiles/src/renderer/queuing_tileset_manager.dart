import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/transforms.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/cesium_3d_tileset.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/renderer/markers.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/renderer/tileset_manager.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/renderer/tileset_renderer.dart';
import 'package:cesium_3d_tiles/src/cesium_native/src/cesium_native.dart';
import 'package:vector_math/vector_math_64.dart';

import '../cesium_3d_tile.dart';

///
/// A partial implementation of [TilesetRenderer] that periodically updates
/// tileset(s) with the current camera matrix and uses a queue to load/remove
/// gltf content as necessary.
///
/// This will update the tileset with the current view once per second, or
/// whenever [markDirty] is called, whichever comes first. The intention is that
/// end consumers call [markDirty] whenever the viewport changes (e.g. the
/// window is resized) or the camera changes (programatically or due to a
/// gesture).
///
/// This class only handles the tileset updates and determines which tiles to
/// render; actually rendering the gltf content is the responsibility of a
/// [TilesetRenderer]. You will need to implement these yourself
/// using your own chosen rendering framework.
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
  final _layersToRemove = <Cesium3DTileset>{};
  final _entities = <Cesium3DTile, T>{};

  final TilesetRenderer<T> renderer;

  /// Creates a new instance of BaseTilesetRenderer.
  ///
  /// This constructor initializes a periodic timer that updates the renderer
  /// and processes the load queue every 16 milliseconds.
  QueueingTilesetManager(this.renderer) {
    _timer = Timer.periodic(const Duration(milliseconds: 8), _tick);
  }

  Future _tick(_) async {
    // skip all updates if we haven't finished the last iteration
    if (_handlingQueue) {
      return;
    }

    _handlingQueue = true;

    for (final layer in _layersToRemove) {
      for (final tile in _renderable[layer]!) {
        final entity = _entities[tile];
        if (entity != null) {
          await renderer.removeEntity(entity);
        }
      }

      _layers.remove(layer);
      await layer.dispose();
      _renderable.remove(layer);
    }
    _layersToRemove.clear();

    var dimensions = await renderer.viewportDimensions;
    var now = DateTime.now();
    var msSinceLastTileUpdate = _lastTileUpdate == null
        ? 9999
        : now.millisecondsSinceEpoch - _lastTileUpdate!.millisecondsSinceEpoch;
    if (dimensions.width > 0 &&
        dimensions.height > 0 &&
        (_cameraDirty || msSinceLastTileUpdate > 16)) {
      await _update();
      _lastTileUpdate = DateTime.now();
      _cameraDirty = false;
    }

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
  }

  Future _remove(Cesium3DTile tile) async {
    if (_loaded.contains(tile)) {
      final entity = _entities[tile];
      if (entity != null) {
        await renderer.removeEntity(entity);
      }

      _entities.remove(tile);

      _loaded.remove(tile);
      // tile.freeGltf();
    }
  }

  @override
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
    
    var afterRtc =
          ecefToGltf * await tile.applyRtcCenter(transform) *
         yUpToZUp;

    var entity = await renderer.loadGlb(data, afterRtc, tile.tileset);
    _entities[tile] = entity;

    _loaded.add(tile);

    await _reveal(tile);

    _loading.remove(tile);
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
    _renderable[layer] = <Cesium3DTile>{};
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
    _layersToRemove.add(layer);
  }

  /// Gets the distance from the camera to the surface of the first layer.
  ///
  /// @return The distance to the surface, or null if there are no layers.
  @override
  Future<double?> getDistanceToSurface({Vector3? point}) async {
    if (_layers.isEmpty) {
      return null;
    }
    return _layers.keys.first.getDistanceToSurface(point: point);
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
    _renderable.clear();
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

  final _renderable = <Cesium3DTileset, Set<Cesium3DTile>>{};

  bool _updating = false;

  Future _update() async {
    if (_updating) {
      return;
    }
    _updating = true;
    var viewport = await renderer.viewportDimensions;
    final layers = _layers.keys.toList();
    final modelMatrix = await renderer.cameraModelMatrix;
    final cameraPosition = modelMatrix.getTranslation();
    final forward = -modelMatrix.forward;
    final up = modelMatrix.up;
    for (final layer in layers) {
      var renderable = (await layer.updateCameraAndViewport(
              cameraPosition,
              up,
              forward,
              (await renderer.horizontalFovInRadians),
              (await renderer.verticalFovInRadians),
              viewport.width.toDouble(),
              viewport.height.toDouble()))
          .toSet();

      // if any tiles are no longer renderable, we can remove them straight away
      var disjunction = renderable.difference(_renderable[layer]!);
      for (var tile in disjunction) {
        _cullQueue.add(tile);
      }

      _renderable[layer]!.clear();
      _renderable[layer]!.addAll(renderable);

      for (var tile in _renderable[layer]!) {
        switch (tile.state) {
          case CesiumTileSelectionState.Rendered:
            if (!_loaded.contains(tile)) {
              _loadQueue.add(tile);
            }
            await _reveal(tile);
          case CesiumTileSelectionState.Refined:
            _loadQueue.remove(tile);
            if (_loaded.contains(tile)) {
              _cullQueue.add(tile);
            }
          case CesiumTileSelectionState.Culled:
            _loadQueue.remove(tile);
            if (_loaded.contains(tile)) {
              _cullQueue.add(tile);
            }
          case CesiumTileSelectionState.None:
            _loadQueue.remove(tile);
            if (_loaded.contains(tile)) {
              _cullQueue.add(tile);
            }
          case CesiumTileSelectionState.RenderedAndKicked:
            _loadQueue.remove(tile);
          case CesiumTileSelectionState.RefinedAndKicked:
            _loadQueue.remove(tile);
        }
      }
    }
    for (final marker in _markers.entries) {
      bool isVisible = (cameraPosition - marker.value.position).length <
          marker.value.visibilityDistance;
      await renderer.setEntityVisibility(marker.key, isVisible);
    }
    _updating = false;
  }
}
