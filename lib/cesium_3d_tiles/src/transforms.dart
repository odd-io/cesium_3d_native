import 'package:vector_math/vector_math_64.dart';

final gltfToEcef = Matrix4(
      1,
      0,
      0,
      0, // First column
      0,
      0,
      1,
      0, // Second column
      0,
      -1,
      0,
      0, // Third column
      0,
      0,
      0,
      1 // Fourth column (identity for no translation)
      );

  final ecefToGltf = Matrix4(
      1,
      0,
      0,
      0, // First column
      0,
      0,
      -1,
      0, // Second column
      0,
      1,
      0,
      0, // Third column
      0,
      0,
      0,
      1 // Fourth column (identity for no translation)
      );