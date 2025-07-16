import 'dart:async';
import 'package:cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:flutter/material.dart'
    hide View; // Using hide View to avoid conflict
import 'package:thermion_flutter/thermion_flutter.dart' as tf;
import 'package:thermion_dart/thermion_dart.dart' hide View, Camera, PickResult;
import 'package:vector_math/vector_math_64.dart';

class CesiumInputHandlerConfiguration {
  final double panSpeed = 0.0000000006;
  final double rotationSpeed = 0.0025;
  final double zoomSpeed = 0.1;
  final double rollSpeed = 1.0;

  final bool flipPanHorizontal = false;
  final bool flipPanVertical = false;
  final bool flipRotateHorizontal = false;
  final bool flipRotateVertical = false;
  final bool flipRoll = false;

  const CesiumInputHandlerConfiguration();
}

class CesiumInputHandler implements tf.InputHandler {
  final tf.ThermionViewer viewer;
  final TilesetManager manager;

  double? get distanceToSurface => _distanceToSurface;
  double? _distanceToSurface;

  Stream get cameraUpdated => _cameraUpdatedController.stream;
  final _cameraUpdatedController = StreamController.broadcast();

  final CesiumInputHandlerConfiguration config;
  final bool useViewportCenterForRotation;

  late final tf.View view;
  late final tf.Camera camera;

  final _initialized = Completer<bool>();
  bool _processing = false;

  Vector3? _focalPoint;
  Vector3? _cameraCenter;
  Vector3? get cameraCenter => _cameraCenter;

  // State for multi-touch gesture detection
  Scale2Type? _scale2type;
  double? _lastScale;
  double? _lastRotation;
  double? _startRotation;
  double? _startScale;
  Timer? _scaleTimer;

  final _cameraPositionController =
      StreamController<({double lat, double lng, double zoom})>.broadcast();
  Stream<({double lat, double lng, double zoom})> get cameraPositionUpdated =>
      _cameraPositionController.stream;

  CesiumInputHandler({
    required this.viewer,
    required this.manager,
    this.config = const CesiumInputHandlerConfiguration(),
    this.useViewportCenterForRotation = false,
  }) {
    initialize();
  }

  Future<void> initialize() async {
    if (_initialized.isCompleted) {
      throw Exception("InputHandler should only be initialized once");
    }
    view = viewer.view;
    camera = await viewer.getActiveCamera();
    _initialized.complete(true);
  }

  @override
  Future<void> dispose() async {
    _cameraUpdatedController.close();
    _cameraPositionController.close();
    _scaleTimer?.cancel();
  }

  @override
  void handle(InputEvent event) async {
    if (_processing) {
      return;
    }

    // Wait for initialization to complete before handling any events.
    await _initialized.future;

    _processing = true;

    try {
      switch (event) {
        case MouseEvent():
          await _handleMouseEvent(event);
          break;
        case ScrollEvent():
          await _handleScrollEvent(event);
          break;
        case ScaleStartEvent():
        case ScaleUpdateEvent():
        case tf.ScaleEndEvent():
          await _handleScaleEvent(event);
          break;
        case tf.TouchEvent():
        case tf.KeyEvent():
          throw UnimplementedError();
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _handleMouseEvent(MouseEvent event) async {
    final type = event.type;
    final button = event.button;
    final localPosition = event.localPosition;
    final delta = event.delta;

    switch (type) {
      case MouseEventType.move:
        Matrix4 modelMatrix;
        if (event.button == MouseButton.middle) {
          // MMB drag rotates around the focal point.
          modelMatrix = await camera.getModelMatrix();
          await _applyRotation(modelMatrix, event.delta);
        } else if (event.button == MouseButton.left) {
          // LMB drag pans the camera.
          modelMatrix = await camera.getModelMatrix();
          var distance = await manager.getDistanceToSurface() ?? 0.1;
          await _applyPan(modelMatrix, event.delta, distance);
          await _pickViewportCenter();
        } else {
          // Not a drag event we handle, break early.
          return;
        }
        await _updateCameraPosition();
        _cameraUpdatedController.add(true);
        break;
      case MouseEventType.buttonUp:
        // Reset focal point when panning is done.
        if (event.button == MouseButton.left) {
          _focalPoint = null;
        }
        break;
      case MouseEventType.buttonDown:
        // On MMB down, pick a focal point for rotation.
        if (event.button == MouseButton.middle) {
          if (useViewportCenterForRotation) {
            await _pickViewportCenter();
          } else {
            await viewer.view.pick(
              event.localPosition.x.floor(),
              event.localPosition.y.floor(),
              _onPickResult,
            );
          }
        }
      case tf.MouseEventType.hover:
        break;
    }
  }

  Future<void> _handleScrollEvent(ScrollEvent event) async {
    // Zoom in/out at the current cursor position.
    await _pickViewportCenter();
    final modelMatrix = await camera.getModelMatrix();
    final distance = await manager.getDistanceToSurface() ?? 0.1;
    await _applyZoom(modelMatrix, event.delta, distance);
    await _updateCameraPosition();
    _cameraUpdatedController.add(true);
  }

  Future<void> _handleScaleEvent(InputEvent event) async {
    // switch(event) {
    //   case ScaleStartEvent(numPointers: final numPointers, localFocalPoint: final  localFocalPoint):
    //     if (numPointers < 2) return;
    // switch (event.type) {
    //   case ScaleEventType.start:
    //     _scaleTimer?.cancel();
    //     _startRotation = event.rotation;
    //     _startScale = event.scale;
    //     _lastRotation = event.rotation;
    //     _lastScale = event.scale;
    //     _scale2type = null; // Reset gesture type
    //     await _pickViewportCenter();
    //     break;

    //   case ScaleEventType.update:
    //     if (_lastScale == null || _lastRotation == null) break;

    //     final scaleDelta = event.scale - _lastScale!;
    //     final rotationDelta = event.rotation - _lastRotation!;
    //     _lastScale = event.scale;
    //     _lastRotation = event.rotation;

    //     _detectGesture(event.delta, scaleDelta, rotationDelta);

    //     final modelMatrix = await camera.getModelMatrix();
    //     final distance = await manager.getDistanceToSurface() ?? 0.1;

    //     bool transformed = false;
    //     if (_scale2type == Scale2Type.pinch) {
    //       await _applyZoom(modelMatrix, -scaleDelta * 10, distance);
    //       transformed = true;
    //     } else if (_scale2type == Scale2Type.rotate) {
    //       await _applyRoll(modelMatrix, rotationDelta);
    //       transformed = true;
    //     } else if (_scale2type == Scale2Type.swipe) {
    //       await _applyPan(modelMatrix, event.delta, distance);
    //       transformed = true;
    //     }

    //     if (transformed) {
    //       await _updateCameraPosition();
    //       _cameraUpdatedController.add(true);
    //     }
    //     break;

    //   case ScaleEventType.end:
    //     _lastScale = null;
    //     _lastRotation = null;
    //     _startRotation = null;
    //     _startScale = null;
    //     _scale2type = null;
    //     break;
    // }
  }

  void _detectGesture(
    Vector2 panDelta,
    double scaleDelta,
    double rotationDelta,
  ) {
    if (_scale2type != null) return;

    // Use absolute values for comparison
    var zoomAmount = (-scaleDelta * 10).abs();
    var rollAmount = rotationDelta.abs();

    // Threshold to prioritize swipe gesture
    if (panDelta.length > 5.0) {
      _scale2type = Scale2Type.swipe;
      return;
    }

    // Use a ratio to distinguish between pinch and rotate
    // Avoid division by zero
    if (zoomAmount < 0.001 && rollAmount < 0.001) return;

    // If one is significantly larger than the other
    if (rollAmount > zoomAmount * 2.0) {
      _scale2type = Scale2Type.rotate;
    } else {
      _scale2type = Scale2Type.pinch;
    }
  }

  // --- Transformation and Utility Methods ---
  // (These methods are largely unchanged, but are now called directly from the handle methods)

  Future<void> _applyRoll(Matrix4 modelMatrix, double rollDelta) async {
    if (_focalPoint == null) return;
    var roll = Matrix4.identity()
      ..setRotation(
        Quaternion.axisAngle(
          modelMatrix.forward.normalized(),
          rollDelta * config.rollSpeed,
        ).asRotationMatrix(),
      );
    var xform =
        Matrix4.translation(_focalPoint!) *
        roll *
        Matrix4.translation(-_focalPoint!);
    await camera.setModelMatrix(xform * modelMatrix);
  }

  Future<void> _applyZoom(
    Matrix4 modelMatrix,
    double zoomDelta,
    double distance,
  ) async {
    final forward = modelMatrix.forward.normalized();
    var cameraPosition = modelMatrix.getTranslation();
    cameraPosition += forward.scaled(config.zoomSpeed * distance * zoomDelta.sign);
    modelMatrix.setTranslation(cameraPosition);
    await camera.setModelMatrix(modelMatrix);
  }

  Future<void> _applyRotation(Matrix4 modelMatrix, Vector2 rotateDelta) async {
    if (_focalPoint == null) return;
    double rotateX = rotateDelta.x * config.rotationSpeed;
    double rotateY = rotateDelta.y * config.rotationSpeed;
    var polar = _focalPoint!.normalized();
    var rot1 = Matrix4.identity()
      ..setRotation(Quaternion.axisAngle(polar, -rotateX).asRotationMatrix());
    var rot2 = Matrix4.identity()
      ..setRotation(
        Quaternion.axisAngle(
          modelMatrix.right.normalized(),
          -rotateY,
        ).asRotationMatrix(),
      );
    var xform =
        Matrix4.translation(_focalPoint!) *
        rot1 *
        rot2 *
        Matrix4.translation(-_focalPoint!);
    await camera.setModelMatrix(xform * modelMatrix);
  }

  Future<void> _applyPan(
    Matrix4 modelMatrix,
    Vector2 panDelta,
    double distance,
  ) async {
    _focalPoint = null; // Panning changes our focal point
    panDelta *= (config.panSpeed * distance);
    final right = modelMatrix.right.normalized();
    final up = modelMatrix.up.normalized();
    final rotationAroundUp = -panDelta.x;
    final rotationAroundRight = -panDelta.y;
    final quatUp = Quaternion.axisAngle(up, rotationAroundUp);
    final quatRight = Quaternion.axisAngle(right, rotationAroundRight);
    final combinedRotation = quatUp * quatRight;
    final rotationMatrix = Matrix4.identity()
      ..setRotation(combinedRotation.asRotationMatrix());
    await camera.setModelMatrix(rotationMatrix * modelMatrix);
  }

  Future<void> _pickViewportCenter() async {
    final viewport = await view.getViewport();
    await view.pick(
      (viewport.width / 2).floor(),
      (viewport.height / 2).floor(),
      _onPickResult,
    );
  }

  Future<void> _onPickResult(tf.PickResult pickResult) async {
    final cameraPosition = (await camera.getModelMatrix()).getTranslation();
    final viewport = await view.getViewport();
    var viewportCoords = Vector3(
      pickResult.fragX / viewport.width,
      pickResult.fragY / viewport.height,
      pickResult.fragZ,
    );
    var ndcCoords = (viewportCoords * 2) - Vector3.all(1);
    var clipSpace = Vector4(ndcCoords.x, ndcCoords.y, ndcCoords.z, 1);
    var projMatrix = await camera.getProjectionMatrix();
    var invProjMatrix = projMatrix.clone()..invert();
    Vector4 viewSpace = invProjMatrix * clipSpace;
    viewSpace /= viewSpace.w;
    Vector4 worldSpace = (await camera.getModelMatrix()) * viewSpace;

    if (worldSpace.isNaN) {
      _distanceToSurface = null;
      return;
    }

    _distanceToSurface = (cameraPosition - worldSpace.xyz).length;
    _cameraCenter = worldSpace.xyz;
    _focalPoint = worldSpace.xyz;
  }

  Future<void> _updateCameraPosition() async {
    final camera = await viewer.getActiveCamera();
    var modelMatrix = await camera.getModelMatrix();
    var cameraPosition = modelMatrix.getTranslation();
    var cartographic = Cesium3DTileset.cartesianToCartographic(cameraPosition);
    var lat = cartographic.latitudeInDegrees;
    var lng = cartographic.longitudeInDegrees;
    var zoom = 15 - (cartographic.height / 1000);
    zoom = zoom.clamp(1, 20);
    _cameraPositionController.add((lat: lat, lng: lng, zoom: zoom));
  }
}

enum Scale2Type { pinch, rotate, swipe }
