import 'dart:io';

import 'package:cesium_3d_tiles/cesium_ion/cesium_ion.dart';
import 'package:http/http.dart' as http;

///
/// Cesium Native has its own implementation for retrieving Cesium Ion assets.
/// However, we did create a small Dart interface for listing/retrieving Cesium
/// Ion assets to help with testing and debugging; this is totally separate from 
/// Cesium Native, and you probably don't want or need to use these classes.
///
void main(List<String> args) async {
  if (args.length != 1) {
    print("Usage: dart get_ion_assets_without_native.dart <ACCESS_TOKEN>");
    exit(-1);
  }
  final accessToken = args[0];
  final api = CesiumIonClient(accessToken);

  // List assets
  final assets = await api.listAssets();
  print('Assets: $assets');

  for (final asset in assets) {
    print("\n\nAsset ${asset.id}");

    try {
      // Fetch a specific asset
      final assetData = await api.getAsset(asset.id);
      print('Fetched asset: $asset');

      final endpoint = await api.getEndpoint(asset);
      print("Endpoint : $endpoint");

      if (endpoint.uri != null) {
        final endpointResponse = await http.get(endpoint.uri!,
            headers: {"Authorization": "Bearer ${endpoint.accessToken}"});
        print(endpointResponse.body);
      } else {
        print("NO ENDPOINT");
      }
    } catch (err) {
      print("Failed to fetch ${asset.id}");
    }
  }
}
