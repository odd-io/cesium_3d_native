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
 
  var numTilesLoaded = Cesium3D.instance.getNumTilesLoaded(tileset);

  print("numTilesLoaded $numTilesLoaded");

  // view = CesiumView(
  //     Vector3(0, 0, 1000), Vector3(0, 0, -1), Vector3(0, 1, 0), 500, 500, 45);

  var numToRender = Cesium3D.instance.updateTilesetView(tileset, view);
  numToRender = Cesium3D.instance.updateTilesetView(tileset, view);

  numTilesLoaded = Cesium3D.instance.getNumTilesLoaded(tileset);

  print("numTilesLoaded $numTilesLoaded");

  print("numToRender $numToRender");

  Cesium3D.instance.checkLoadError(tileset);

  var tileToRender = Cesium3D.instance.getTileToRenderThisFrame(tileset, 0);

  var contentType = Cesium3D.instance.getTileContentType(tileToRender);

  var loadState = Cesium3D.instance.getLoadState(tileToRender);

  var rootTile = Cesium3D.instance.getRootTile(tileset);

  // Cesium3D.instance.traverseChildren(rootTile);

  for (int i = 0; i < 10; i++) {
    await Future.delayed(Duration(milliseconds: 100));
    numTilesLoaded = Cesium3D.instance.getNumTilesLoaded(tileset);
    print("numTilesLoaded $numTilesLoaded");
    numToRender = Cesium3D.instance.updateTilesetView(tileset, view);
  }
  print("Done");

  // Cesium3D.instance.traverseChildren(rootTile);

  // Cesium3D.instance.getAllRenderContent(tileToRender);
  // Cesium3D.instance.foo(tileToRender);
  // print();
}
