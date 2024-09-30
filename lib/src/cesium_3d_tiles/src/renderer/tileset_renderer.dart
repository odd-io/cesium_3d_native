import 'dart:async';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/cesium_3d_tileset.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/renderer/markers.dart';
import 'package:vector_math/vector_math_64.dart';

///
/// A [TilesetRenderer] connects instances of
/// [Cesium3DTileset] to an actual scene/viewport/camera.
///
/// Implementations must regularly call [updateCameraAndViewport] (with the
/// current camera matrices) on all instances of [Cesium3DTileset] added
/// via [addLayer].
///
/// If any [Cesium3DTileset] has renderable content, implementations must
/// add that to the current scene (note that currently this will always be glTF).
///
///
abstract class TilesetRenderer {

  /// Adds a [Cesium3DTileset] to be rendered by this renderer.
  ///
  /// @param layer The layer to be added.
  void addLayer(Cesium3DTileset layer);

  /// Adds a marker to the rendered scene.
  ///
  /// @param marker The marker to be added.
  Future addMarker(RenderableMarker marker);

  /// Sets the visibility of a specific layer.
  ///
  /// @param renderLayer The index of the render layer to modify.
  /// @param visible Whether the render layer should be visible or not.
  /// @return A Future that completes when the visibility change is applied.
  Future setLayerVisibility(RenderLayer renderLayer, bool visible);

  /// Gets the current viewport dimensions.
  ///
  /// @return A tuple containing the width and height of the viewport.
  (double, double) get viewportDimensions;

  /// Gets the current camera projection matrix.
  ///
  /// @return A Future that resolves to the camera projection matrix.
  Future<Matrix4> get cameraProjectionMatrix;

  /// Gets the current camera model matrix.
  ///
  /// @return A Future that resolves to the camera model matrix.
  Future<Matrix4> get cameraModelMatrix;

  /// Sets the camera model matrix.
  ///
  /// @param modelMatrix The new camera model matrix.
  /// @return A Future that completes when the matrix is set.
  Future setCameraModelMatrix(Matrix4 modelMatrix);

  /// Removes a layer and all its associated entities from the renderer.
  ///
  /// @param layer The layer to be removed.
  /// @return A Future that completes when the layer and its entities are removed.
  Future remove(Cesium3DTileset layer);

  /// Animates the camera from its current position to [target].
  ///
  /// @param [target] The position (in glTF coordinates) to zoom to.
  /// @param duration The duration of the zoom animation.
  /// @return A Future that completes when the zoom animation is finished.
  Future zoomTo(Vector3 target,
      {Duration duration = const Duration(seconds: 1)});

  ///
  /// Disposes of the renderer and frees any resources it was using.
  /// Implementations must ensure that all renderable layer content and markers
  /// are removed from the scene.
  ///
  Future dispose();

  /// Resets the camera orientation to the "root" position.
  ///
  /// The camera is always looking at the origin. Its position is determined by
  /// taking the center of the root tile of the first layer loaded, then
  /// translating along the forward vector by the ratio between the distance
  /// from the origin and the Z extent of the bounding volume.
  ///
  /// @param tileset The tileset to use for determining the root position.
  /// @param offset Whether to apply an offset to the camera position.
  /// @return A Future that completes when the camera position is set.
  Future<void> setCameraToRootPosition(Cesium3DTileset tileset,
      {bool offset = false});

  /// Gets the distance from the camera to the surface of the first layer.
  ///
  /// @return The distance to the surface, or null if there are no layers.
  double? getDistanceToSurface();

  Future<Vector3> getTileCameraPosition(Cesium3DTileset layer);
}
