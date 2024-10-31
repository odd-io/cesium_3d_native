import 'dart:math';

final _RAD_TO_DEG = 180 / pi;

class CartographicPosition {
  final double latitudeInRadians;
  double get latitudeInDegrees => _RAD_TO_DEG * latitudeInRadians;
  final double longitudeInRadians;
  double get longitudeInDegrees => _RAD_TO_DEG * longitudeInRadians;
  final double height;

  CartographicPosition(
      this.latitudeInRadians, this.longitudeInRadians, this.height);
}
