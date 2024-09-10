import 'dart:io';

import 'package:cesium_3d_native/src/ion/CesiumIonClient.dart';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  if (args.length != 1) {
    print("Usage: dart cesium_ion_client_test.dart <ACCESS_TOKEN>");
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
