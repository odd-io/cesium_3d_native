import 'dart:io';
import 'dart:math';

import 'package:cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:cesium_3d_tiles/src/cesium_native/cesium_view.dart';
import 'package:vector_math/vector_math_64.dart';

void main(List<String> args) async {
  if (args.length != 2) {
    print(
        "Usage: dart --enable-experiment=native-assets cesium_3d_native_get_tileset_from_ion_id.dart <CESIUM_ION_ASSET_ID> <ACCESS_TOKEN>");
    exit(-1);
  }
  var scriptDir = File(Platform.script.path).parent.path;
  var outputDirectory = Directory("$scriptDir/output");
  final assetId = int.parse(args[0]);
  final accessToken = args[1];

  // first, verify that loading a non-existent tileset successfully throws an error
  bool thrown = false;
  try {
    var tileset = await Cesium3D.instance.loadFromCesiumIon(12345, "random");
  } catch (err) {
    thrown = true;
  }
  if (!thrown) {
    throw Exception(
        "Tileset load was expected to fail and throw an Exception, but none was encountered");
  }

  // next, attempt to load the tileset from the Cesium Ion asset ID provided on the command line
  var tileset = await Cesium3D.instance.loadFromCesiumIon(assetId, accessToken);

  print(Cesium3D.instance.getLastFrameNumber(tileset));

  var view = CesiumView(Vector3(0, 0, 1000), Vector3(0, 0, -1),
      Vector3(0, 1, 0), 500, 500, pi / 4);
  Cesium3D.instance.updateTilesetView(tileset, view);

  Cesium3D.instance.getCartographicPosition(view);

  var rootTile = Cesium3D.instance.getRootTile(tileset);

  var rootTransform = Cesium3D.instance.getTransform(rootTile!);

  var bv = Cesium3D.instance.getBoundingVolume(rootTile)
      as CesiumBoundingVolumeOrientedBox;

  var rootPosition = rootTransform.getTranslation();

  var cameraPosition = bv.center + (bv.halfAxes * Vector3(2, 2, 2));

  var up = Vector3(0, 0, 1);

  final forward = -(cameraPosition - rootPosition).normalized();

  view = CesiumView(cameraPosition, forward.xyz, up, 500, 500, pi / 4);
  print(Cesium3D.instance.getTransform(rootTile));
  for (int i = 0; i < 10; i++) {
    await Future.delayed(Duration(milliseconds: 500));
    var toRender = Cesium3D.instance.updateTilesetView(tileset, view);
    final renderable = Cesium3D.instance.getRenderableTiles(rootTile);
    print(
        "Frame : ${Cesium3D.instance.getLastFrameNumber(tileset)} : toRender $toRender renderable  ${renderable.length}");
    for (final tile in renderable) {
      print(Cesium3D.instance.getLoadState(tile));
      var model = Cesium3D.instance.getModel(tile);
      // print(Cesium3D.instance.getGltfTransform(model));
      print(Cesium3D.instance.getTransform(tile));
      // var serialized = Cesium3D.instance.serializeGltfData(model);
      // print(Cesium3D.instance.getTransform(tile));
      // File("${outputDirectory.path}/melb.glb")
      //     .writeAsBytesSync(serialized.data);
    }
    if (renderable.length > 0) break;
  }

  // int i = 0;

  // if (outputDirectory.existsSync()) {
  //   outputDirectory.deleteSync(recursive: true);
  // }

  // outputDirectory.createSync();

  // var rootTransform = Cesium3D.instance.getTransform(rootTile);

  // print("rootTransform $rootTransform");

  // view = CesiumView(Vector3(0, 0, 7945941), Vector3(0, 0, -1), Vector3(0, 1, 0),
  //     500, 500, pi / 4);

  // var distanceToBoundingVolume =
  //     sqrt(Cesium3D.instance.squaredDistanceToBoundingVolume(view, rootTile));
  // print("distanceToBoundingVolume $distanceToBoundingVolume");

  // print(Cesium3D.instance.getBoundingVolume(rootTile));
  // print(Cesium3D.instance
  //     .getBoundingVolume(rootTile, convertRegionToOrientedBox: true));
  // var volume = Cesium3D.instance.getBoundingVolume(rootTile,
  //     convertRegionToOrientedBox: true) as CesiumBoundingVolumeOrientedBox;
  // print("volume.halfAxes ${volume.halfAxes}");

  // for (final tile in renderable) {
  //   print(Cesium3D.instance.getLoadState(tile));
  //   var model = Cesium3D.instance.getModel(tile);
  //   var serialized = Cesium3D.instance.serializeGltfData(model);
  //   print(Cesium3D.instance.getTransform(tile));

  //   File("${outputDirectory.path}/${i}.glb").writeAsBytesSync(serialized.data);
  //   serialized.free();
  //   i++;
  // }
  // await Cesium3D.instance.destroy(tileset);
  // print("DESTROYED");

  // tileset = await Cesium3D.instance.loadFromCesiumIon(assetId, accessToken);
  // numToRender = Cesium3D.instance.updateTilesetView(tileset, view);

  // print("LOADED SECOND : $numToRender");
}