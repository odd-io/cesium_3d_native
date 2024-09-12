import 'dart:math';

import 'package:vector_math/vector_math_64.dart';

abstract class CesiumBoundingVolume {}

class CesiumBoundingVolumeOrientedBox extends CesiumBoundingVolume {
  final Matrix3 halfAxes;
  final Vector3 center;

  CesiumBoundingVolumeOrientedBox(this.halfAxes, this.center);
  @override
  String toString() => "OrientedBox($halfAxes, $center)";
}

class CesiumBoundingVolumeRegion extends CesiumBoundingVolume {
  final double west;
  final double south;
  final double east;
  final double north;
  final double minHeight;
  final double maxHeight;

  CesiumBoundingVolumeRegion(
      {required this.west,
      required this.south,
      required this.east,
      required this.north,
      required this.minHeight,
      required this.maxHeight});
  String toString() =>
      "Region($west, $south, $east, $north, $minHeight, $maxHeight)";
}

class CesiumBoundingVolumeSphere extends CesiumBoundingVolume {
  final Vector3 center;
  final double radius;

  CesiumBoundingVolumeSphere(this.center, this.radius);
}
