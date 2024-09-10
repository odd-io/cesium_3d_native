import 'dart:io';

import 'package:cesium_3d_native/cesium_3d_native.dart';
import 'package:cesium_3d_native/src/cesium_view.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main(List<String> args) async {
  if (args.length != 2) {
    print(
        "Usage: dart --enable-experiment=native-assets cesium_3d_native_get_tileset_from_ion_id.dart <CESIUM_ION_ASSET_ID> <ACCESS_TOKEN>");
    exit(-1);
  }
  final assetId = int.parse(args[0]);
  final accessToken = args[1] as String;

  // first, let's verify that we can successfully check a failed tileset

  var tileset = Cesium3D.instance.loadFromCesiumIon(12345, "random");
  var view = CesiumView(
      Vector3.zero(), Vector3(0, 0, -1), Vector3(0, 1, 0), 500, 500, 45);
  Cesium3D.instance.updateTilesetView(tileset, view);
  bool thrown = false;
  try {
    Cesium3D.instance.checkLoadError(tileset);
  } catch (err) {
    thrown = true;
  }

  if (!thrown) {
    print(
        "Tileset load was expected to fail and throw an Exception, but none was encountered");
  }

  // now let's actually try the specified asset
  tileset = Cesium3D.instance.loadFromCesiumIon(assetId, accessToken);

  view = CesiumView(
      Vector3.zero(), Vector3(0, 0, -1), Vector3(0, 1, 0), 500, 500, 45);
  var numToRender = Cesium3D.instance.updateTilesetView(tileset, view);

  Cesium3D.instance.checkLoadError(tileset);

  print("numToRender $numToRender");

}
