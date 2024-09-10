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

  var tileset = Cesium3D.loadFromCesiumIon(12345, "random");
  var view = CesiumView(
      Vector3.zero(), Vector3(0, 0, -1), Vector3(0, 1, 0), 500, 500, 45, 45);
  Cesium3D.updateTilesetView(tileset, view);
  bool thrown = false;
  try {
    Cesium3D.checkLoadError(tileset);
  } catch (err) {
    thrown = true;
  }

  if (!thrown) {
    print(
        "Tileset load was expected to fail and throw an Exception, but none was encountered");
  }

  // now let's actually try the specified asset
  tileset = Cesium3D.loadFromCesiumIon(assetId, accessToken);

  view = CesiumView(
      Vector3.zero(), Vector3(0, 0, -1), Vector3(0, 1, 0), 500, 500, 45, 45);
  Cesium3D.updateTilesetView(tileset, view);
  await Future.delayed(Duration(seconds: 1));

  Cesium3D.checkLoadError(tileset);

  // bool failed = false;
  // try {
  //   tileset = Cesium3D.loadFromCesiumIon(696969, "some_access_token");
  //   final rootTile = Cesium3D.getRootTile(tileset);
  //   final state = Cesium3D.getLoadState(rootTile);
  //   print("Root tile load state : $state");
  // } catch (err) {
  //   failed = true;
  // }

  // if (!failed) {
  //   throw Exception("Expected nullptr");
  // }

  // print("Tileset with incorrect access token correctly throws exception");

  // final assetId = int.fromEnvironment("CESIUM_ION_TEST_ID");
  // final accessToken = String.fromEnvironment(name)
  // var tileset = Cesium3D.loadFromCesiumIon(asset, accessToken)
}
