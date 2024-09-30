import 'dart:io';

import 'package:cesium_3d_tiles/src/cesium_native/cesium_native.dart';
import 'package:vector_math/vector_math_64.dart';


void main(List<String> args) async {
  if (args.length != 1) {
    print(
        "Usage: dart --enable-experiment=native-assets cesium_3d_native_test.dart <CESIUM_TILESET_URL>");
    exit(-1);
  }
  final url = args[0];

  print("Loading from URL $url");
  var tileset = await CesiumNative.instance.loadFromUrl(url);

  var view = CesiumView(
      Vector3(0, 0, 1000), Vector3(0, 0, -1), Vector3(0, 1, 0), 500, 500, 45);

  var numToRender = CesiumNative.instance.updateTilesetView(tileset, view);

  print("numToRender $numToRender");


}
