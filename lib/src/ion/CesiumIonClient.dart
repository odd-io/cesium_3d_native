import 'dart:convert';
import 'package:cesium_3d_native/src/ion/CesiumIonAsset.dart';
import 'package:http/http.dart' as http;

class CesiumIonClient {
  final String accessToken;
  final String baseUrl = 'https://api.cesium.com/v1';

  CesiumIonClient(this.accessToken);

  Future<List<CesiumIonAsset>> listAssets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/assets'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return (data['items'] as List)
          .map((item) => CesiumIonAsset.fromJson(item))
          .toList();
    } else {
      throw Exception('Failed to load assets: ${response.statusCode}');
    }
  }

  Future<CesiumIonAsset> getAsset(int assetId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/assets/$assetId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return CesiumIonAsset.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch asset: ${response.statusCode}');
    }
  }

  Future<CesiumIonAsset> createAsset(Map<String, dynamic> assetData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assets'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(assetData),
    );

    if (response.statusCode == 200) {
      return CesiumIonAsset.fromJson(json.decode(response.body)['assetMetadata']);
    } else {
      throw Exception('Failed to create asset: ${response.statusCode}');
    }
  }

  Future<void> waitUntilReady(int assetId) async {
    while (true) {
      final asset = await getAsset(assetId);
      if (asset.status == 'COMPLETE') {
        print('Asset tiled successfully');
        print('View in ion: https://ion.cesium.com/assets/${asset.id}');
        break;
      } else if (asset.status == 'DATA_ERROR') {
        throw Exception('ion detected a problem with the uploaded data.');
      } else if (asset.status == 'ERROR') {
        throw Exception('An unknown tiling error occurred, please contact support@cesium.com.');
      } else {
        if (asset.status == 'NOT_STARTED') {
          print('Tiling pipeline initializing.');
        } else { // IN_PROGRESS
          print('Asset is ${asset.percentComplete}% complete.');
        }
        await Future.delayed(Duration(seconds: 10));
      }
    }
  }
}