import 'dart:io';
import 'dart:math';

import 'package:cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:vector_math/vector_math_64.dart';

///
/// This example shows how to use the low-level Cesium Native bindings
/// to load a tileset from Cesium Ion, update the view, and list renderable tiles.
///
void main(List<String> args) async {
  if (args.length != 2) {
    print(
        "Usage: dart --enable-experiment=native-assets example/cesium_3d_tiles/tileset_from_ion_id.dart <CESIUM_ION_ASSET_ID> <ACCESS_TOKEN>");
    exit(-1);
  }

  // get the Cesium Ion asset ID and access token from the command line arguments
  final assetId = int.parse(args[0]);
  final accessToken = args[1];

  // create a Cesium3DTileset instance from a Cesium Ion asset ID
  var tileset = await Cesium3DTileset.fromCesiumIon(assetId, accessToken);

  final cameraModelMatrix = Matrix4.identity();
  final fov = (45 / 360) * (2 * pi);

  final viewport = (width: 1920.0, height: 1080.0);

  var renderableTiles = await tileset.updateCameraAndViewport(
      cameraModelMatrix, fov, fov, viewport.width, viewport.height);

  print("${renderableTiles.length} renderable tiles");

  for (var tile in renderableTiles) {
    print("Tile state: ${tile.state}");
    switch (tile.state) {
      // if this tile needs to be rendered
      case CesiumTileSelectionState.Rendered:
        var gltfContent = tile.loadGltf();
        // implement your own logic to insert into the scene
        await tile.freeGltf();
      case CesiumTileSelectionState.None:
      // when a tile has not yet been loaded
      case CesiumTileSelectionState.Culled:
      // remove tile from scene
      case CesiumTileSelectionState.Refined:
      // remove tile from scene
      case CesiumTileSelectionState.RenderedAndKicked:
      // remove tile from scene
      case CesiumTileSelectionState.RefinedAndKicked:
      // remove tile from scene
    }
  }
}
