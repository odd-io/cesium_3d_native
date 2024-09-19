import 'dart:io';
import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';

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

    logger.info("Using lib dir : ${libDir.path}");
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

const _cesiumNativeVersion = "v0.39.0";

String _getLibraryUrl(String platform, String mode, String arch) {
  return "https://pub-b19d1b9d30844d689622bf750da1df69.r2.dev/cesium-native-$_cesiumNativeVersion-$platform-$arch-$mode.zip";
}

//
// Download precompiled Cesium Native libraries for the target platform from Cloudflare.
//
Future<Directory> getLibDir(BuildConfig config, Logger logger) async {
  var platform = config.targetOS.toString().toLowerCase();

  var mode = "release";

  final targetArch = config.targetArchitecture?.toString() ?? "arm64";

  var libDir = Directory(
      "${config.packageRoot.toFilePath()}/.dart_tool/cesium_3d_native/lib/$_cesiumNativeVersion/$platform/$mode/${targetArch}");

  final url = _getLibraryUrl(platform, mode, targetArch);

  final filename = url.split("/").last;

  // We will write an empty file called success to the unzip directory after successfully downloading/extracting the prebuilt libraries.
  // If this file already exists, we assume everything has been successfully extracted and skip
  final unzipDir = libDir.path;
  final successToken = File("$unzipDir/success");
  final libraryZip = File("$unzipDir/$filename");

  if (!successToken.existsSync()) {
    if (libraryZip.existsSync()) {
      libraryZip.deleteSync();
    }

    if (!libraryZip.parent.existsSync()) {
      libraryZip.parent.createSync(recursive: true);
    }

    logger.info(
        "Downloading prebuilt libraries for $platform/$mode from $url to ${libraryZip}, files will be unzipped to ${unzipDir}");
    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();

    await response.pipe(libraryZip.openWrite());

    final archive = ZipDecoder().decodeBytes(await libraryZip.readAsBytes());

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final f = File('${unzipDir}/$filename');
        await f.create(recursive: true);
        await f.writeAsBytes(data);
      } else {
        final d = Directory('${unzipDir}/$filename');
        await d.create(recursive: true);
      }
    }
    successToken.writeAsStringSync("SUCCESS");
  }
  return libDir;
}
