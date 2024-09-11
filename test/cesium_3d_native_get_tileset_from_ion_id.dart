import 'dart:io';
import 'dart:math';

import 'package:cesium_3d_native/cesium_3d_native.dart';
import 'package:cesium_3d_native/src/cesium_view.dart';
import 'package:vector_math/vector_math.dart';

void main(List<String> args) async {
  if (args.length != 2) {
    print(
        "Usage: dart --enable-experiment=native-assets cesium_3d_native_get_tileset_from_ion_id.dart <CESIUM_ION_ASSET_ID> <ACCESS_TOKEN>");
    exit(-1);
  }
  final assetId = int.parse(args[0]);
  final accessToken = args[1];

  // first, verify that loading a non-existent tileset successfully throws an error
  var tileset = Cesium3D.instance.loadFromCesiumIon(12345, "random");
  bool thrown = false;
  try {
    Cesium3D.instance.checkLoadError(tileset);
  } catch (err) {
    thrown = true;
  }
  if (!thrown) {
    throw Exception(
        "Tileset load was expected to fail and throw an Exception, but none was encountered");
  }

  // next, attempt to load the tileset from the Cesium Ion asset ID provided on the command line
  tileset = Cesium3D.instance.loadFromCesiumIon(assetId, accessToken);

  Cesium3D.instance.checkLoadError(tileset);

  var numTilesLoaded = Cesium3D.instance.getNumTilesLoaded(tileset);

  print("numTilesLoaded $numTilesLoaded");
  var view = CesiumView(Vector3(0, 0, 1000), Vector3(0, 0, -1),
      Vector3(0, 1, 0), 500, 500, pi / 4);

  var numToRender = Cesium3D.instance.updateTilesetView(tileset, view);

  var rootTile = Cesium3D.instance.getRootTile(tileset);

  numToRender = Cesium3D.instance.updateTilesetView(tileset, view);

  numTilesLoaded = Cesium3D.instance.getNumTilesLoaded(tileset);
  print("numTilesLoaded $numTilesLoaded numToRender $numToRender");

  numToRender = Cesium3D.instance.updateTilesetView(tileset, view);

  numTilesLoaded = Cesium3D.instance.getNumTilesLoaded(tileset);

  Cesium3D.instance.traverseChildren(rootTile);

  final renderable = Cesium3D.instance.getRenderableTiles(rootTile);

  int i = 0;
  var scriptDir = File(Platform.script.path).parent.path;
  var outputDirectory = Directory("$scriptDir/output");

  if (outputDirectory.existsSync()) {
    outputDirectory.deleteSync(recursive: true);
  }

  outputDirectory.createSync();

  for (final tile in renderable) {
    print(Cesium3D.instance.getLoadState(tile));
    var model = Cesium3D.instance.getModel(tile);
    var serialized = Cesium3D.instance.serializeGltfData(model);
    File("${outputDirectory.path}/${i}.glb").writeAsBytesSync(serialized.data);
    serialized.free();
    i++;
    break;
  }
}
