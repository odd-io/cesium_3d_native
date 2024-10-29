import 'package:vector_math/vector_math_64.dart';
import 'dart:math';

final yUpToZUp = Matrix4(
    1,
    0,
    0,
    0, 
    0,
    0,
    1,
    0, 
    0,
    -1,
    0,
    0, 
    0,
    0,
    0,
    1 
    );

final zUpToYUp = yUpToZUp.clone()..transpose();

final gltfToEcef = ecefToGltf.clone()..transpose();
final ecefToGltf =
    Matrix4.rotationZ(-pi / 2) * Matrix4.rotationY(-pi / 2);

final yUpToglTf = Matrix4.rotationZ(pi / 2) * ecefToGltf;
