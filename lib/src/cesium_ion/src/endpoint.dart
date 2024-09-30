class CesiumIonAssetEndpoint {
  final Uri? uri;
  final String? accessToken;

  CesiumIonAssetEndpoint({
    required this.uri,
    required this.accessToken,
  });

  factory CesiumIonAssetEndpoint.fromJson(Map<String, dynamic> json) {
    return CesiumIonAssetEndpoint(
      uri: json["url"] == null ? null : Uri.parse(json["url"]),
      accessToken: json["accessToken"]
    );
  }

  @override
  String toString() {
    return 'CesiumIonAssetEndpoint(uri: $uri, accessToken: <HIDDEN>)';
  }
}
