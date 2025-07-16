import 'dart:async';
import 'dart:math';
import 'package:cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'cesium_input_handler.dart';
import 'thermion_tileset_renderer.dart';
import 'package:vector_math/vector_math_64.dart';

const ionAccessToken = String.fromEnvironment("accessToken");

class ExampleViewModel {
  late ThermionViewer _viewer;
  ThermionViewer get viewer => _viewer;

  late ThermionTilesetRenderer _renderer;
  ThermionTilesetRenderer get renderer => _renderer;
  late TilesetManager _manager;
  TilesetManager get manager => _manager;

  final initialized = ValueNotifier<bool>(false);

  late CesiumInputHandler _inputHandler;
  CesiumInputHandler get inputHandler => _inputHandler;

  final layers = ValueNotifier<List<Cesium3DTileset>>([]);

  late StreamSubscription _gestureListener;

  Timer? timer;

  ExampleViewModel._(
    this._viewer,
    this._renderer,
    this._manager,
    this._inputHandler,
  ) {
    _gestureListener = inputHandler.cameraUpdated.listen((_) async {
      timer?.cancel();
      timer = Timer(const Duration(milliseconds: 5), () async {
        var distanceToSurface = await manager.getDistanceToSurface();
        await renderer.setDistanceToSurface(distanceToSurface);
        await renderer.updateCameraProjectionMatrix();
        manager.markDirty();
      });
    });
  }

  ///
  ///
  ///
  static Future<ExampleViewModel> create() async {
    if (ionAccessToken.isEmpty) {
      throw Exception("You must set the accessToken");
    }

    final viewer = await ThermionFlutterPlugin.createViewer();

    await viewer.setPostProcessing(true);
    await viewer.setAntiAliasing(false, true, false);
    await viewer.setBackgroundColor(1, 1, 1, 1);
    await viewer.setRendering(true);

    final renderer = ThermionTilesetRenderer(viewer);
    final manager = QueueingTilesetManager(renderer);

    final inputHandler = CesiumInputHandler(
      viewer: viewer,
      manager: manager,
      useViewportCenterForRotation: true,
    );

    var viewModel = ExampleViewModel._(viewer, renderer, manager, inputHandler);
    return viewModel;
  }

  // Future moveTo(double latitudeInRads, double longitudeInRads, double height) async {
  //   final northEast = Cesium3DTileset.cartographicToCartesian(
  //     latitudeInRads,
  //     longitudeInRads,
  //   );

  //   double width = (northEast - northEast).length;

  //   vm.Vector3 southEast = Cesium3DTileset.cartographicToCartesian(
  //     bounds.southEast.latitudeInRad,
  //     bounds.southEast.longitudeInRad,
  //   );
  //   double height = (southEast - northEast).length;

  //   double verticalFovInRadians = await renderer.verticalFovInRadians;
  //   double horizontalFovInRadians =
  //       await renderer.horizontalFovInRadians;

  //   final distanceFromWidth = width / 2 / tan(horizontalFovInRadians / 2);
  //   final distanceFromHeight = height / 2 / tan(verticalFovInRadians / 2);

  //   double cameraDistToSurface = max(distanceFromHeight, distanceFromWidth);

  //   await moveCameraToPosition(
  //     latitude,
  //     center.longitude,
  //     heightAboveTarget: cameraDistToSurface,
  //   );
  // }

  ///
  ///
  ///
  Future dispose() async {
    await _gestureListener.cancel();
  }

  ///
  ///
  ///
  Future addLayer(int ionAssetId, RenderLayer renderLayer) async {
    const options = TilesetOptions(
      forbidHoles: true,
      enableFogCulling: true,
      enableOcclusionCulling: true,
      enableLodTransitionPeriod: false,
    );

    final layer = await Cesium3DTileset.fromCesiumIon(
      ionAssetId,
      ionAccessToken,
      renderLayer: renderLayer,
      tilesetOptions: options,
    );
    layer.isRootTileLoaded();
    layers.value.add(layer);
    layers.notifyListeners();
    await _manager.addLayer(layer);
  }

  ///
  ///
  ///
  Future addMarker(Cesium3DTileset layer, double heightAboveSurface) async {
    final tileCenter = layer.getBoundingVolumeCenter(layer.rootTile!);
    if (tileCenter == null) {
      throw Exception("Failed to get tile center");
    }
    final position =
        tileCenter; // + tileCenter.normalized().scaled(heightAboveSurface);
    final marker = GeometryRenderableMarker(
      position: position,
      r: 1.0,
      g: 0.0,
      b: 0.0,
      visibilityDistance: 10000.0,
      onClick: () async {
        print("MARKER CLICKED");
      },
    );
    await _manager.addMarker(marker);
    var lookAt = makeViewMatrix(
      marker.position.length > 0
          ? marker.position + marker.position.normalized().scaled(10)
          : Vector3(0, 1, 0),
      marker.position,
      Vector3(0, 1, 0),
    );
    lookAt.invert();
    await _renderer.setCameraModelMatrix(lookAt);
  }

  ///
  ///
  ///
  Future viewportResized(Size newSize, double pixelRatio) async {
    await _renderer.setDistanceToSurface(await _manager.getDistanceToSurface());
    await _renderer.updateCameraProjectionMatrix();
    _manager.markDirty();
  }

  ///
  ///
  ///
  Future removeLayer(Cesium3DTileset layer) async {
    await manager.remove(layer);
    layers.value.remove(layer);
    layers.notifyListeners();
  }

  ///
  /// Latitude: -90° to +90° (negative for South, positive for North)
  /// Longitude: -180° to +180° (negative for West, positive for East)
  ///
  Future<void> animateCameraToLocation(
    double latInDegrees,
    double longInDegrees, {
    double heightAboveTarget = 1000,
  }) async {
    final latInRadians = degrees2Radians * latInDegrees;
    final longInRadians = degrees2Radians * longInDegrees;
    final targetPoint = Cesium3DTileset.cartographicToCartesian(
      latInRadians,
      longInRadians,
      height: 0,
    );
    if (heightAboveTarget <= 0) {
      heightAboveTarget = 1.0;
    }

    final targetCameraPosition = Cesium3DTileset.cartographicToCartesian(
      latInRadians,
      longInRadians,
      height: heightAboveTarget,
    );

    // Calculate view matrix from camera position, forward & up vectors
    final lookAt = makeViewMatrix(
      targetCameraPosition,
      targetPoint,
      Vector3(0, 1, 0),
    );
    lookAt.invert();

    await _renderer.zoomTo(lookAt);
    await Future.delayed(const Duration(milliseconds: 1500));

    // Update necessary state
    _manager.markDirty();
    await _renderer.setDistanceToSurface(await _manager.getDistanceToSurface());
    await _renderer.updateCameraProjectionMatrix();
  }

  ///
  /// Instantly moves the camera to the specified location without animation
  /// Latitude: -90° to +90° (negative for South, positive for North)
  /// Longitude: -180° to +180° (negative for West, positive for East)
  ///
  Future<void> moveCameraToPosition(
    double latInDegrees,
    double longInDegrees, {
    double heightAboveTarget = 1000,
  }) async {
    final latInRadians = degrees2Radians * latInDegrees;
    final longInRadians = degrees2Radians * longInDegrees;

    final targetPoint = Cesium3DTileset.cartographicToCartesian(
      latInRadians,
      longInRadians,
      height: 0,
    );

    if (heightAboveTarget <= 0) {
      heightAboveTarget = 1.0;
    }

    final targetCameraPosition = Cesium3DTileset.cartographicToCartesian(
      latInRadians,
      longInRadians,
      height: heightAboveTarget,
    );

    // Calculate view matrix from camera position, forward & up vectors
    final lookAt = makeViewMatrix(
      targetCameraPosition,
      targetPoint,
      Vector3(0, 1, 0),
    );
    lookAt.invert();

    // Set camera position directly without animation
    final camera = await _viewer.getActiveCamera();
    await camera.setModelMatrix(lookAt);

    // Update necessary state
    _manager.markDirty();
    await _renderer.setDistanceToSurface(await _manager.getDistanceToSurface());
    await _renderer.updateCameraProjectionMatrix();
  }
}
