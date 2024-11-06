import 'package:vector_math/vector_math_64.dart';

enum RenderableMarkerType { gltf, geometry }

enum GeometryType { cube, sphere }

///
/// A [RenderableMarker] is a non-tileset 3D entity that can be added to
/// a scene.
///
/// @param position The position of the marker in glTF coordinates.
/// @param onClick A callback to be invoked if the marker is clicked in the viewport.
/// @param visibilityDistance If the marker is more than this distance away from the camera, the marker will be hidden.
///
abstract class RenderableMarker {
  final Vector3 position;
  final void Function() onClick;
  final double visibilityDistance;
  final double heightAboveTerrain;

  RenderableMarkerType get type;

  RenderableMarker(
      {required this.position,
      required this.onClick,
      this.visibilityDistance = 100.0,
      this.heightAboveTerrain = 1.0});
}

class GltfRenderableMarker extends RenderableMarker {
  final Uri uri;

  GltfRenderableMarker(
      {required this.uri, required super.position, required super.onClick});

  @override
  RenderableMarkerType get type => RenderableMarkerType.gltf;
}

class GeometryRenderableMarker extends RenderableMarker {
  final double r;
  final double g;
  final double b;
  final double a;

  @override
  RenderableMarkerType get type => RenderableMarkerType.geometry;

  final GeometryType geometryType;

  GeometryRenderableMarker(
      {required super.position,
      required super.onClick,
      super.visibilityDistance = 100.0,
      super.heightAboveTerrain = 10.0,
      this.geometryType = GeometryType.sphere,
      this.r = 1.0,
      this.g = 1.0,
      this.b = 1.0,
      this.a = 1.0});
}
