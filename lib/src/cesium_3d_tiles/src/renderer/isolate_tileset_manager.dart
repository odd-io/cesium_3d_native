import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/cesium_3d_tileset.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/renderer/markers.dart';
import 'package:cesium_3d_tiles/src/cesium_3d_tiles/src/renderer/queuing_tileset_manager.dart';
import 'package:vector_math/vector_math_64.dart';

import 'tileset_manager.dart';
import 'tileset_renderer.dart';

///
/// Below is an example implementation of a TilesetManager that runs on a
/// background isolate.
///
/// However, we currently cannot pin isolates to threads, meaning that
/// any cesium_native functions may be called on different threads at any
/// given time. This is not permitted by the cesium_native library.
///
/// This implementation therefore won't be usable until isolate-pinning is
/// available in Dart/Flutter.
///
/// https://github.com/dart-lang/sdk/issues/46943
///
///

void _isolateEntryPoint(List<dynamic> message) {
  SendPort mainSendPort = message[0] as SendPort;

  final renderer = _IsolateRenderer(mainSendPort);

  final manager = QueueingTilesetManager(renderer);

  final receivePort = ReceivePort();

  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((message) async {
    if (message is _IsolateManagerRequest) {
      dynamic result;
      switch (message.method) {
        case 'addLayer':
          manager.addLayer(message.args[0] as Cesium3DTileset);
        case 'addMarker':
          result = await manager.addMarker(message.args[0] as RenderableMarker);
        case 'dispose':
          result = await manager.dispose();
        case 'getDistanceToSurface':
          result = await manager.getDistanceToSurface();
        case 'getTileCameraPosition':
          result = await manager
              .getCameraPositionForTileset(message.args[0] as Cesium3DTileset);
        case 'remove':
          result = await manager.remove(message.args[0] as Cesium3DTileset);
        case 'markDirty':
          manager.markDirty();
        default:
          throw UnimplementedError('Method ${message.method} not implemented');
      }
      mainSendPort.send(_IsolateManagerResponse(message.id, result));
    } else if (message is _IsolateRenderResponse) {
      renderer.handleResponse(message);
    }
  });
}

class IsolateTilesetManager extends TilesetManager {
  final Isolate _isolate;
  late final SendPort _sendPort;
  final ReceivePort _receivePort;
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  int _nextRequestId = 0;

  static IsolateTilesetManager? _instance;
  final TilesetRenderer renderer;

  IsolateTilesetManager._(this.renderer, this._isolate, this._receivePort) {
    _receivePort.listen(_handleMessage);
  }

  static Future<IsolateTilesetManager> spawn(TilesetRenderer renderer) async {
    if (_instance != null) return _instance!;

    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _isolateEntryPoint,
      [receivePort.sendPort],
    );

    _instance = IsolateTilesetManager._(renderer, isolate, receivePort);
    return _instance!;
  }

  void _handleMessage(dynamic message) {
    if (message is SendPort) {
      _sendPort = message;
    } else if (message is _IsolateManagerResponse) {
      final completer = _pendingRequests.remove(message.id);
      completer!.complete(message.result);
    } else if (message is _IsolateRenderRequest) {
      _handleRenderRequest(message);
    }
  }

  Future<void> _handleRenderRequest(_IsolateRenderRequest request) async {
    try {
      dynamic result;
      switch (request.method) {
        case 'loadGlb':
          result = await renderer.loadGlb(
              request.args[0], request.args[1], request.args[2]);
        case 'removeEntity':
          result = await renderer.removeEntity(request.args[0]);
        case 'setEntityVisibility':
          result = await renderer.setEntityVisibility(
              request.args[0], request.args[1]);
        case 'loadMarker':
          result = await renderer.loadMarker(request.args[0]);
        case 'setLayerVisibility':
          result = await renderer.setLayerVisibility(
              request.args[0], request.args[1]);
        case 'getViewportDimensions':
          result = await renderer.viewportDimensions;
        case 'getHorizontalFovInRadians':
          result = await renderer.horizontalFovInRadians;
        case 'getVerticalFovInRadians':
          result = await renderer.verticalFovInRadians;
        case 'getCameraModelMatrix':
          result = await renderer.cameraModelMatrix;
        case 'setCameraModelMatrix':
          result = await renderer.setCameraModelMatrix(request.args[0]);
        case 'zoomTo':
          renderer.zoomTo(request.args[0], duration: request.args[1]);
        case 'setDistanceToSurface':
          result = await renderer.setDistanceToSurface(request.args[0]);
        default:
          throw UnimplementedError(
              'Method ${request.method} not implemented in renderer');
      }
      _sendPort.send(_IsolateRenderResponse(request.id, result));
    } catch (e) {
      _sendPort.send(_IsolateRenderResponse(request.id, e));
    }
  }

  Future<T> _sendMessage<T>(String method, [List<dynamic>? args]) async {
    final id = _nextRequestId++;
    final completer = Completer<T>();
    _pendingRequests[id] = completer;
    _sendPort.send(_IsolateManagerRequest(id, method, args ?? []));
    return completer.future;
  }

  @override
  void addLayer(Cesium3DTileset layer) {
    _sendMessage('addLayer', [layer]);
  }

  @override
  Future dispose() async {
    await _sendMessage('dispose');
    _isolate.kill();
    _instance = null;
  }

  @override
  Future<double?> getDistanceToSurface({Vector3? point}) {
    if (point != null) {
      throw UnimplementedError("TODO");
    }
    return _sendMessage<double?>('getDistanceToSurface');
  }

  @override
  Future remove(Cesium3DTileset layer) => _sendMessage('remove', [layer]);

  @override
  Future addMarker(RenderableMarker marker) {
    return _sendMessage('addMark', [marker]);
  }

  @override
  Future<Matrix4> getCameraPositionForTileset(Cesium3DTileset tileset,
      {bool offset = false}) {
    return _sendMessage('getCameraPositionForTileset', [tileset, offset]);
  }

  @override
  void markDirty() {
    _sendMessage("markDirty");
  }
  
  @override
  Future updateMarkers() {
    // TODO: implement updateMarkers
    throw UnimplementedError();
  }
}

class _IsolateManagerRequest {
  final int id;
  final String method;
  final List<dynamic> args;

  _IsolateManagerRequest(this.id, this.method, this.args);
}

class _IsolateManagerResponse {
  final int id;
  final dynamic result;

  _IsolateManagerResponse(this.id, this.result);
}

class _IsolateRenderRequest {
  final int id;
  final String method;
  final List<dynamic> args;

  _IsolateRenderRequest(this.id, this.method, this.args);
}

class _IsolateRenderResponse {
  final int id;
  final dynamic result;

  _IsolateRenderResponse(this.id, this.result);
}

class _IsolateRenderer extends TilesetRenderer {
  final SendPort _sendPort;
  int _nextRequestId = 0;
  final Map<int, Completer<dynamic>> _pendingRequests = {};

  _IsolateRenderer(this._sendPort);

  Future<T> _sendMessage<T>(String method, [List<dynamic>? args]) async {
    final id = _nextRequestId++;
    final completer = Completer<T>();
    _pendingRequests[id] = completer;
    _sendPort.send(_IsolateRenderRequest(id, method, args ?? []));
    return completer.future;
  }

  void handleResponse(_IsolateRenderResponse response) {
    final completer = _pendingRequests.remove(response.id);
    if (completer != null) {
      completer.complete(response.result);
      if (response.result is Exception) {
        print("SEVERE: ${response.result}");
      }
    }
  }

  @override
  Future loadGlb(Uint8List glb, Matrix4 transform, Cesium3DTileset layer) {
    return _sendMessage('loadGlb', [glb, transform, layer]);
  }

  @override
  Future removeEntity(dynamic entity) {
    return _sendMessage('removeEntity', [entity]);
  }

  @override
  Future setEntityVisibility(entity, bool visible) {
    return _sendMessage('setEntityVisibility', [entity, visible]);
  }

  @override
  Future loadMarker(RenderableMarker marker) {
    return _sendMessage('loadMarker', [marker]);
  }

  @override
  Future setLayerVisibility(RenderLayer renderLayer, bool visible) {
    return _sendMessage('setLayerVisibility', [renderLayer, visible]);
  }

  @override
  Future<({int width, int height})> get viewportDimensions {
    return _sendMessage('getViewportDimensions');
  }

  @override
  Future<double> get horizontalFovInRadians {
    return _sendMessage<double>('getHorizontalFovInRadians');
  }

  @override
  Future<double> get verticalFovInRadians {
    return _sendMessage('getVerticalFovInRadians');
  }

  @override
  Future<Matrix4> get cameraModelMatrix {
    return _sendMessage('getCameraModelMatrix');
  }

  @override
  Future setCameraModelMatrix(Matrix4 modelMatrix) {
    return _sendMessage('setCameraModelMatrix', [modelMatrix]);
  }

  @override
  Future<void> zoomTo(Matrix4 newModelMatrix,
      {Duration duration = const Duration(seconds: 1)}) {
    return _sendMessage('zoomTo', [newModelMatrix, duration]);
  }

  @override
  Future setDistanceToSurface(double? distance) {
    return _sendMessage('setDistanceToSurface', [distance]);
  }

  
  @override
  Future<Matrix4> getEntityTransform(entity) {
    // TODO: implement getEntityTransform
    throw UnimplementedError();
  }
  
  @override
  Future setEntityTransform(entity, Matrix4 transform) {
    // TODO: implement setEntityTransform
    throw UnimplementedError();
  }
}
