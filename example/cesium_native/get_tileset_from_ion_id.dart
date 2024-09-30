import 'dart:io';
import 'dart:math';

import 'package:cesium_3d_tiles/src/cesium_native/cesium_native.dart';
import 'package:vector_math/vector_math_64.dart';

///
/// This example shows how to use the low-level Cesium Native bindings
/// to load a tileset from Cesium Ion, update the view, and list renderable tiles.
///
void main(List<String> args) async {
  if (args.length != 2) {
    print(
        "Usage: dart --enable-experiment=native-assets get_tileset_from_ion_id.dart <CESIUM_ION_ASSET_ID> <ACCESS_TOKEN>");
    exit(-1);
  }

  // get the Cesium Ion asset ID and access token from the command line arguments
  final assetId = int.parse(args[0]);
  final accessToken = args[1];

  // load the tileset from the Cesium Ion asset ID
  var tileset =
      await CesiumNative.instance.loadFromCesiumIon(assetId, accessToken);

  // create a random camera view for testing purposes
  var view = CesiumView(Vector3(0, 0, 1000), Vector3(0, 0, -1),
      Vector3(0, 1, 0), 500, 500, pi / 4);

  // update
  CesiumNative.instance.updateTilesetView(tileset, view);

  CesiumNative.instance.getCartographicPosition(view);

  var rootTile = CesiumNative.instance.getRootTile(tileset);

  var rootTransform = CesiumNative.instance.getTransform(rootTile!);

  var bv = CesiumNative.instance.getBoundingVolume(rootTile)
      as CesiumBoundingVolumeOrientedBox;

  var rootPosition = rootTransform.getTranslation();

  var cameraPosition = bv.center + (bv.halfAxes * Vector3(2, 2, 2));

  var up = Vector3(0, 0, 1);

  final forward = -(cameraPosition - rootPosition).normalized();

  view = CesiumView(cameraPosition, forward.xyz, up, 500, 500, pi / 4);
  for (int i = 0; i < 10; i++) {
    await Future.delayed(Duration(milliseconds: 500));
    var toRender = CesiumNative.instance.updateTilesetView(tileset, view);
    final renderable = CesiumNative.instance.getRenderableTiles(rootTile);
    for (final tile in renderable) {
      var model = CesiumNative.instance.getModel(tile);
      print(CesiumNative.instance.getTransform(tile));
      var gltf = CesiumNative.instance.serializeGltfData(model);
      gltf.free();
    }
    if (renderable.length > 0) break;
  }

  
}
