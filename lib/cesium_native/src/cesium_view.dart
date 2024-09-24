import 'package:vector_math/vector_math_64.dart';

// Represents the current view (i.e. camera orientation)
class CesiumView {
  final Vector3 position;
  final Vector3 direction;
  final Vector3 up;
  final double viewportWidth;
  final double viewportHeight;

  /// The horizontal field of view of the camera (in radians)
  final double horizontalFov;

  CesiumView(this.position, this.direction, this.up, this.viewportWidth,
      this.viewportHeight, this.horizontalFov);
}
