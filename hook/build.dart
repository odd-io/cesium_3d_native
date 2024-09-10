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
// //     if (config.targetOS == OS.android) {
// //       if (!config.dryRun) {
// //         final archExtension = switch (config.targetArchitecture) {
// //           Architecture.arm => "arm-linux-androideabi",
// //           Architecture.arm64 => "aarch64-linux-android",
// //           Architecture.x64 => "x86_64-linux-android",
// //           Architecture.ia32 => "i686-linux-android",
// //           _ => throw FormatException('Invalid')
// //         };
          
// //         var compilerPath = config.cCompiler.compiler!.path;
        
// //         if(Platform.isWindows && compilerPath.startsWith("/")) {
// //           compilerPath = compilerPath.substring(1);
// //         }
        
// //         var ndkRoot = File(compilerPath).parent.parent.uri.toFilePath(windows:true);

// //         var stlPath =
// //             File([ndkRoot, "sysroot", "usr", "lib", archExtension, "libc++_shared.so"].join(Platform.pathSeparator));
// //         output.addAsset(NativeCodeAsset(
// //             package: "thermion_dart",
// //             name: "libc++_shared.so",
// //             linkMode: DynamicLoadingBundled(),
// //             os: config.targetOS,
// //             file: stlPath.uri,
// //             architecture: config.targetArchitecture));
// //       }
// //     }
// //     // do we need this?
// //     if (config.targetOS == "windows") {
// //       output.addAsset(
// //           NativeCodeAsset(
// //               package: "thermion_dart",
// //               name: "thermion_dart.dll",
// //               linkMode: DynamicLoadingBundled(),
// //               os: config.targetOS,
// //               file: Uri.file(
// //                   config.outputDirectory.toFilePath() + "/thermion_dart.dll"),
// //               architecture: config.targetArchitecture),
// //           linkInPackage: config.packageName);
// //     }
// //   });
// // }

// // String _FILAMENT_VERSION = "v1.51.2";
// // String _getLibraryUrl(String platform, String mode) {
// //   return "https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/filament-${_FILAMENT_VERSION}-${platform}-${mode}.zip";
// // }

// // //
// // // Download precompiled Filament libraries for the target platform from Cloudflare.
// // //
// // Future<Directory> getLibDir(BuildConfig config, Logger logger) async {
// //   var platform = config.targetOS.toString().toLowerCase();

// //   // Except on Windows, most users will only need release builds of Filament.
// //   // Debug builds are probably only relevant if you're a package developer debugging an internal Filament issue
// //   // or if you're working on Flutter+Windows (which requires the CRT debug DLLs).
// //   // Also note that there are known driver issues with Android debug builds, e.g.:
// //   // https://github.com/google/filament/issues/7162
// //   // (these aren't present in Filament release builds).
// //   // However, if you know what you're doing, you can change "release" to "debug" below.
// //   // TODO - check if we can pass this as a CLI compiler flag
// //   var mode = "release";
// //   if (platform == "windows") {
// //     mode = config.buildMode == BuildMode.debug ? "debug" : "release";
// //   }

// //   var libDir = Directory(
// //       "${config.packageRoot.toFilePath()}/.dart_tool/thermion_dart/lib/${_FILAMENT_VERSION}/$platform/$mode/");

// //   if (platform == "android") {
// //     final archExtension = switch (config.targetArchitecture) {
// //       Architecture.arm => "armeabi-v7a",
// //       Architecture.arm64 => "arm64-v8a",
// //       Architecture.x64 => "x86_64",
// //       Architecture.ia32 => "x86",
// //       _ => throw FormatException('Invalid')
// //     };
// //     libDir = Directory("${libDir.path}/$archExtension/");
// //   } else if (platform == "windows") {
// //     if (config.targetArchitecture != Architecture.x64) {
// //       throw Exception(
// //           "Unsupported architecture : ${config.targetArchitecture}");
// //     }
// //   }

// //   final url = _getLibraryUrl(platform, mode);

// //   final filename = url.split("/").last;

// //   // We will write an empty file called success to the unzip directory after successfully downloading/extracting the prebuilt libraries.
// //   // If this file already exists, we assume everything has been successfully extracted and skip
// //   final unzipDir = platform == "android" ? libDir.parent.path : libDir.path;
// //   final successToken = File("$unzipDir/success");
// //   final libraryZip = File("$unzipDir/$filename");

// //   if (!successToken.existsSync()) {
// //     if (libraryZip.existsSync()) {
// //       libraryZip.deleteSync();
// //     }

// //     if (!libraryZip.parent.existsSync()) {
// //       libraryZip.parent.createSync(recursive: true);
// //     }

// //     logger.info(
// //         "Downloading prebuilt libraries for $platform/$mode from $url to ${libraryZip}, files will be unzipped to ${unzipDir}");
// //     final request = await HttpClient().getUrl(Uri.parse(url));
// //     final response = await request.close();

// //     await response.pipe(libraryZip.openWrite());

// //     final archive = ZipDecoder().decodeBytes(await libraryZip.readAsBytes());

// //     for (final file in archive) {
// //       final filename = file.name;
// //       if (file.isFile) {
// //         final data = file.content as List<int>;
// //         final f = File('${unzipDir}/$filename');
// //         await f.create(recursive: true);
// //         await f.writeAsBytes(data);
// //       } else {
// //         final d = Directory('${unzipDir}/$filename');
// //         await d.create(recursive: true);
// //       }
// //     }
// //     successToken.writeAsStringSync("SUCCESS");
// //   }
// //   return libDir;
// // }
