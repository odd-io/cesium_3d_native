class CesiumIonAsset {
  final int id;
  final String type;
  final String name;
  final String description;
  final int bytes;
  final String attribution;
  final DateTime dateAdded;
  final bool exportable;
  final String status;
  final int percentComplete;
  final bool archivable;

  CesiumIonAsset({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.bytes,
    required this.attribution,
    required this.dateAdded,
    required this.exportable,
    required this.status,
    required this.percentComplete,
    required this.archivable,
  });

  factory CesiumIonAsset.fromJson(Map<String, dynamic> json) {
    return CesiumIonAsset(
      id: json['id'],
      type: json['type'],
      name: json['name'],
      description: json['description'],
      bytes: json['bytes'],
      attribution: json['attribution'],
      dateAdded: DateTime.parse(json['dateAdded']),
      exportable: json['exportable'],
      status: json['status'],
      percentComplete: json['percentComplete'],
      archivable: json['archivable'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'description': description,
      'bytes': bytes,
      'attribution': attribution,
      'dateAdded': dateAdded.toIso8601String(),
      'exportable': exportable,
      'status': status,
      'percentComplete': percentComplete,
      'archivable': archivable,
    };
  }

  @override
  String toString() {
    return 'CesiumIonAsset(id: $id, type: $type, name: $name, status: $status, percentComplete: $percentComplete)';
  }
}
