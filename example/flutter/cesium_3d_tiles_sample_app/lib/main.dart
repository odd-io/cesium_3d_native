import 'package:cesium_3d_tiles/cesium_3d_tiles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

import 'example_viewmodel.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      print('${record.loggerName} ${record.level.name}  ${record.message}');
    }
  });
  CesiumNative.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cesium 3D Tiles Demo',
      theme: ThemeData(useMaterial3: true),
      home: const MyHomePage(title: 'Cesium 3D Tiles'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  ExampleViewModel? viewModel;
  String? error;

  @override
  void initState() {
    super.initState();
    ExampleViewModel.create().then((viewModel) async {
      this.viewModel = viewModel;
      // Automatically load Google 3D tiles
      await viewModel.addLayer(2275207, RenderLayer.layer0);

      await viewModel.moveCameraToPosition(51.507889, -0.087837, heightAboveTarget: 100.0);

      setState(() {});
    }).onError((err, st) {
      if(err is AccessTokenException) {
        error = "Cesium Ion accessToken not set. Make sure you have followed the instructions in README.md in the root repository, and that you are running with flutter run --dart-define accessToken=YOUR_CESIUM_ION_ACCESS_TOKEN";
      } else { 
        error = err.toString();
      }
      setState(() {
        
      });
    });
  }

  @override
  void dispose() {
    viewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: error != null ? Center(child:SizedBox(width:500, child:Text(error!))) : viewModel == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: ThermionListenerWidget(
                    inputHandler: viewModel!.inputHandler,
                    child: ThermionWidget(
                      onResize: (Size newSize, _, double pixelRatio) async {
                        viewModel!.viewportResized(newSize, pixelRatio);
                      },
                      viewer: viewModel!.viewer,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: CameraOrientationWidget(viewer: viewModel!.viewer),
                ),
              ],
            ),
    );
  }
}
