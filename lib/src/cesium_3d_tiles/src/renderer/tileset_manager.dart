import 'dart:async';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/cesium_3d_tileset.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/renderer/markers.dart';
import 'package:vector_math/vector_math_64.dart';

///
/// A [TilesetManager] is an interface for loading [Cesium3DTileset] layers
/// and determining when/how to insert tiles into a scene.
///
/// Implementations must regularly call [updateCameraAndViewport] (with the
/// current camera matrices) on all instances of [Cesium3DTileset] added
/// via [addLayer].
///
/// If any [Cesium3DTileset] has renderable content, implementations must
/// add that to the current scene (note that currently this will always be glTF).
///
abstract class TilesetManager {
  /// Adds a [Cesium3DTileset] to be rendered by this renderer.
  ///
  /// @param layer The layer to be added.
  void addLayer(Cesium3DTileset layer);

  /// Adds a marker to the rendered scene.
  ///
  /// @param marker The marker to be added.
  Future addMarker(RenderableMarker marker);

  /// Removes a layer and all its associated entities from the renderer.
  ///
  /// @param layer The layer to be removed.
  /// @return A Future that completes when the layer and its entities are removed.
  Future remove(Cesium3DTileset layer);

  ///
  /// Disposes of the renderer and frees any resources it was using.
  /// Implementations must ensure that all renderable layer content and markers
  /// are removed from the scene.
  ///
  Future dispose();

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


  /// Gets the distance from the camera to the surface of the first layer.
  ///
  /// @return The distance to the surface, or null if there are no layers.
  Future<double?> getDistanceToSurface();

  ///
  /// Marks the camera as dirty, indicating that the Cesium Tileset view should 
  /// be updated with the most recent camera matrix.
  /// 
  void markDirty();
}
