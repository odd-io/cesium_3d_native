import 'dart:io';
import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as p;

Logger _prepareLogger(BuildConfig config) {
  var logDir = Directory(
      "${config.packageRoot.toFilePath()}.dart_tool/cesium_3d_native/log/");
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }
  var logFile = File(logDir.path + "/build.log");

  final logger = Logger("")
    ..level = Level.ALL
    ..onRecord.listen((record) => logFile.writeAsStringSync(
        record.message + "\n",
        mode: FileMode.append,
        flush: true));
  return logger;
}

Future<Directory> getLibDir(BuildConfig config, Logger logger) async {
  var platform = config.targetOS.toString().toLowerCase();
  var libDir =
      Directory("${config.packageRoot.toFilePath()}/native/lib/$platform");
  return libDir;
}

void main(List<String> args) async {
  await build(args, (config, output) async {
    final logger = _prepareLogger(config);

    final packageName = config.packageName;

    final sources = Directory("${config.packageRoot.toFilePath()}/native/src")
        .listSync(recursive: true)
        .whereType<File>()
        .where((x) => x.path.endsWith(".cpp"))
        .map((f) => f.path)
        .toList();

    final libDir = await getLibDir(config, logger);
    final libs = libDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith(".a"))
        .where((f) => !f.path.contains("spd"))
        .map((f) {
      var basename = p.basename(f.path);
      basename = basename.replaceAll(RegExp("^lib"), "");
      basename = basename.replaceAll(".a", "");
      return "-l${basename}";
    });

    final cbuilder = CBuilder.library(
      name: packageName,
      language: Language.cpp,
      assetName: 'cesium_3d_native.dart',
      sources: sources,
      includes: [
        'native/include',
        'native/generated/include',
        'native/thirdparty/include'
      ],
      flags: [
        "--std=c++17",
        "-L${libDir.path}",
        "-lcurl",
        "-lssl",
        "-lcrypto",
        "-lz",
        ...libs,
        "-framework",
        "CoreFoundation",
        "-framework",
        "SystemConfiguration"
      ],
      dartBuildFiles: ['hook/build.dart'],
    );

    await cbuilder.run(
      buildConfig: config,
      buildOutput: output,
      logger: logger,
    );
  });
}
