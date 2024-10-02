import 'dart:async';
import 'dart:isolate';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:mirrors';

import 'package:cesium_3d_tiles/src/cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/renderer/base_tileset_renderer_isolate.dart';
import 'package:vector_math/vector_math_64.dart';

class Foo extends BaseTilesetRenderer {
  @override
  // TODO: implement cameraModelMatrix
  Future<Matrix4> get cameraModelMatrix => throw UnimplementedError();

  @override
  // TODO: implement horizontalFovInRadians
  Future<double> get horizontalFovInRadians => throw UnimplementedError();

  @override
  Future loadGlb(Uint8List glb, Matrix4 transform, Cesium3DTileset layer) {
    // TODO: implement loadGlb
    throw UnimplementedError();
  }

  @override
  Future loadMarker(RenderableMarker marker) {
    // TODO: implement loadMarker
    throw UnimplementedError();
  }

  @override
  Future removeEntity(entity) {
    // TODO: implement removeEntity
    throw UnimplementedError();
  }

  @override
  Future setCameraModelMatrix(Matrix4 modelMatrix) {
    // TODO: implement setCameraModelMatrix
    throw UnimplementedError();
  }

  @override
  Future setEntityVisibility(entity, bool visible) {
    // TODO: implement setEntityVisibility
    throw UnimplementedError();
  }

  @override
  Future setLayerVisibility(RenderLayer renderLayer, bool visible) {
    // TODO: implement setLayerVisibility
    throw UnimplementedError();
  }

  @override
  // TODO: implement verticalFovInRadians
  Future<double> get verticalFovInRadians => throw UnimplementedError();

  @override
  // TODO: implement viewportDimensions
  Future<({int height, int width})> get viewportDimensions =>
      throw UnimplementedError();
}

// void isolateFunction(SendPort sendPort) {
//   // This is the entry point for the new isolate
//   final receivePort = ReceivePort();

//   // Send the new isolate's SendPort back to the main isolate
//   sendPort.send(receivePort.sendPort);

//   receivePort.listen((message) {
//     if (message is String) {
//       print('Isolate received: $message');
//       sendPort.send('Hello from isolate!');
//     } else if (message == 'exit') {
//       print('Isolate is shutting down');
//       receivePort.close();
//     } else {
//       ClassMirror classMirror = reflectClass(message);
//       InstanceMirror instanceMirror =
//           classMirror.newInstance(Symbol(''), []);

//       // Get the actual instance from the InstanceMirror
//       Foo foo = instanceMirror.reflectee;

//       print(foo);
//     }
//   });
// }

void main() async {
  final foo = await IsolateBaseTilesetRenderer.spawn<Foo>();
  await Future.delayed(Duration(seconds: 1));
  // // Create a ReceivePort for the main isolate
  // final receivePort = ReceivePort();
  // // Set up a listener for messages from the new isolate
  // final isolateSendPort = Completer<SendPort>();
  // receivePort.listen((message) {
  //   if (message is SendPort) {
  //     isolateSendPort.complete(message);
  //   } else {
  //     print('Main received: $message');
  //   }
  // });

  // // Spawn a new isolate
  // final isolate = await Isolate.spawn(isolateFunction, receivePort.sendPort);

  // (await isolateSendPort.future).send(Foo);

  // // Wait for a moment to allow for message processing
  // await Future.delayed(Duration(seconds: 1));

  // // Tell the isolate to exit
  // (await isolateSendPort.future).send('exit');

  // // Close the receive port and kill the isolate
  // receivePort.close();
  // isolate.kill();
}
