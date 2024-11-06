import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/cesium_3d_tileset.dart';
import 'package:vector_math/vector_math_64.dart';

import 'markers.dart';

///
/// A [TilesetRenderer] is intended for use by a [TilesetManager] to actually
/// render tiles to a scene/viewport.
///
/// If any [Cesium3DTileset] has renderable content, implementations must
/// add that to the current scene (note that currently this will always be glTF).
///
/// The generic parameter [T] is the type of the entity handle returned by the
/// actual rendering library.
abstract class TilesetRenderer<T> {
  /// Sets the visibility of a specific layer.
  ///
  /// @param renderLayer The index of the render layer to modify.
  /// @param visible Whether the render layer should be visible or not.
  /// @return A Future that completes when the visibility change is applied.
  Future setLayerVisibility(RenderLayer renderLayer, bool visible);

  /// Gets the current viewport dimensions.
  ///
  /// @return A tuple containing the width and height of the viewport.
  Future<({int width, int height})> get viewportDimensions;

  /// Gets the current horizontal field of view from the active camera.
  ///
  /// @return A Future that resolves to the camera horizontal field of view.
  Future<double> get horizontalFovInRadians;

  /// Gets the current vertical field of view from the active camera.
  ///
  /// @return A Future that resolves to the camera horizontal field of view.
  Future<double> get verticalFovInRadians;

  /// Gets the current camera model matrix.
  ///
  /// @return A Future that resolves to the camera model matrix.
  Future<Matrix4> get cameraModelMatrix;

  /// Sets the camera model matrix.
  ///
  /// @param modelMatrix The new camera model matrix.
  /// @return A Future that completes when the matrix is set.
  Future setCameraModelMatrix(Matrix4 modelMatrix);

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
  Future<T> loadGlb(Uint8List glb, Matrix4 transform, Cesium3DTile tile);

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

  ///
  /// Loads a marker into the scene and ensures that its [onClick] method
  /// is called whenever the marker is tapped in the viewport.
  ///
  /// @param marker The marker to load and insert into the scene.
  /// @return A Future that resolves to the loaded entity.
  Future<T> loadMarker(RenderableMarker marker);

  ///
  ///
  ///
  Future<Matrix4> getEntityTransform(T entity);

  ///
  ///
  ///
  Future setEntityTransform(T entity, Matrix4 transform);

  /// Animates the camera from its current orientation to the model matrix
  /// specified by [newModelMatrix]
  ///
  /// @param newModelMatrix The model matrix for the camera
  /// at the end of the animation
  ///
  /// @param duration The duration of the zoom animation.
  ///
  /// @return A Future that completes when the zoom animation is finished.
  Future<void> zoomTo(Matrix4 newModelMatrix,
      {Duration duration = const Duration(seconds: 1)}) async {
    final startMatrix = await cameraModelMatrix;
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final endTime = startTime + duration.inMilliseconds;

    final startRotation = Quaternion.fromRotation(startMatrix.getRotation());
    final endRotation = Quaternion.fromRotation(newModelMatrix.getRotation());

    final startTranslation = startMatrix.getTranslation();
    final endTranslation = newModelMatrix.getTranslation();

    final completer = Completer<void>();

    void animate() {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= endTime) {
        setCameraModelMatrix(newModelMatrix);
        completer.complete();
        return;
      }

      final t = (now - startTime) / duration.inMilliseconds;
      final easedT = _easeInOutCubic(t);

      // Interpolate rotation using slerp
      final interpolatedRotation = slerp(startRotation, endRotation, easedT);

      // Interpolate position
      final interpolatedTranslation = Vector3(
        lerp(startTranslation.x, endTranslation.x, easedT),
        lerp(startTranslation.y, endTranslation.y, easedT),
        lerp(startTranslation.z, endTranslation.z, easedT),
      );

      // Construct interpolated matrix
      final interpolatedMatrix = Matrix4.compose(
          interpolatedTranslation, interpolatedRotation, Vector3.all(1.0));

      setCameraModelMatrix(interpolatedMatrix);
      Future.delayed(const Duration(milliseconds: 16), animate);
    }

    animate();
    return completer.future;
  }

// Linear interpolation function
  double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

// Quaternion spherical linear interpolation (slerp)
  Quaternion slerp(Quaternion a, Quaternion b, double t) {
    // Compute the cosine of the angle between the two vectors
    double dot = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;

    // If the dot product is negative, slerp won't take the shorter path.
    // Fix by reversing one quaternion.
    if (dot < 0.0) {
      b = Quaternion(-b.x, -b.y, -b.z, -b.w);
      dot = -dot;
    }

    // If the inputs are too close for comfort, linearly interpolate
    if (dot > 0.9995) {
      return Quaternion(
        lerp(a.x, b.x, t),
        lerp(a.y, b.y, t),
        lerp(a.z, b.z, t),
        lerp(a.w, b.w, t),
      ).normalized();
    }

    // Calculate the angle between the quaternions
    double theta0 = acos(dot);
    double theta = theta0 * t;

    double sinTheta = sin(theta);
    double sinTheta0 = sin(theta0);

    double s0 = cos(theta) - dot * sinTheta / sinTheta0;
    double s1 = sinTheta / sinTheta0;

    return Quaternion(
      a.x * s0 + b.x * s1,
      a.y * s0 + b.y * s1,
      a.z * s0 + b.z * s1,
      a.w * s0 + b.w * s1,
    );
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

  Future setDistanceToSurface(double? distance);
}
