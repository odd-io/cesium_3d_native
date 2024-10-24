import 'dart:io';
import 'package:cesium_3d_tiles/cesium_3d_tiles.dart';

///
/// This example shows how to use the low-level Cesium Native bindings
/// to load a tileset from Cesium Ion, update the view, and list renderable tiles.
///
void main(List<String> args) async {
  double lat, long, height;
  try {
    lat = double.parse(args[0]);
    long = double.parse(args[1]);
    height = double.parse(args[1]);
  } catch (err) {
    print(
        "Usage: dart --enable-experiment=native-assets get_cartesian_coordinates.dart <lat> <long> <height>");
    exit(-1);
  }

  final position =
      Cesium3DTileset.cartographicToCartesian(lat, long, height: height);

  print("Cartesian Coordinates : $position");
}
