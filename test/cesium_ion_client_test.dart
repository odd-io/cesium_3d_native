import 'package:cesium_3d_native/src/ion/CesiumIonClient.dart';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  final accessToken = args[0];
  final api = CesiumIonClient(accessToken);

  try {
    // List assets
    final assets = await api.listAssets();
    print('Assets: $assets');

    // Fetch a specific asset
    final asset = await api.getAsset(assets.first.id);
    print('Fetched asset: $asset');

    final endpoint = await api.getEndpoint(asset);
    print("Endpoint : $endpoint");

    final endpointResponse = await http.get(endpoint.uri,
        headers: {"Authorization": "Bearer ${endpoint.accessToken}"});
    print(endpointResponse.body);
  } catch (e) {
    print('Error: $e');
  }
}
