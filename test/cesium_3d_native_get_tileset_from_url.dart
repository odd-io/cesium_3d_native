import 'dart:io';

import 'package:cesium_3d_native/cesium_3d_native.dart';
import 'package:test/test.dart';

void main(List<String> args) async {
  if (args.length != 1) {
    print(
        "Usage: dart --enable-experiment=native-assets cesium_3d_native_test.dart <CESIUM_TILESET_URL>");
    exit(-1);
  }
  final url = args[0];

  print("Loading from URL $url");
  var tileset = Cesium3D.instance.loadFromUrl(url);

}
