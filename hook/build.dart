import 'dart:io';
import 'package:logging/logging.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';

Logger _prepareLogger(Uri packageRoot) {
  var logDir = Directory(
      "${packageRoot.toFilePath()}.dart_tool/cesium_3d_native/log/");
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
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    final config = input.config;
    final packageRoot = input.packageRoot;
    final targetOS = config.code.targetOS;
    final targetArchitecture = config.code.targetArchitecture;
    final logger = _prepareLogger(packageRoot);

    final packageName = input.packageName;

    final sources = Directory("${packageRoot.toFilePath()}/native/src")
        .listSync(recursive: true)
        .whereType<File>()
        .where((x) => x.path.endsWith(".cpp"))
        .map((f) => f.path)
        .toList();

    String targetArch;

    if (targetOS == OS.android) {
      targetArch = switch (targetArchitecture) {
        Architecture.arm => "armeabi-v7a",
        Architecture.arm64 => "arm64-v8a",
        Architecture.x64 => "x86_64",
        Architecture.ia32 => "x86",
        _ => "arm64-v8a"
      };
    } else {
      targetArch = targetArchitecture?.toString() ?? "arm64";
    }

    final libDir = await getLibDir(packageRoot, targetOS, logger, targetArch);

    final sqliteDir = Directory(
            "${packageRoot.toFilePath()}/.dart_tool/cesium_3d_native/sqlite/$_sqliteVersion/${targetOS.toString().toLowerCase()}/${targetArch}");

    logger.info("Using lib dir : ${libDir.path}");
    logger.info("Using SQLite dir : ${sqliteDir.path}");

    var libs = <String>[];
    var flags = <String>[];
    var includes = <String>[
      'native/include',
      'native/generated/include',
      'native/thirdparty/include'
    ];

    /// Windows
    if (targetOS == OS.windows) {
      flags.addAll(["/std:c++17", "/MD", "/EHsc"]);
      flags.addAll(
          includes.map((i) => "/I${packageRoot.toFilePath()}/$i"));
      flags.addAll(["/DWIN32=1", "/D_DLL=1", "/DRELEASE"]);
      flags.addAll(sources);

      sources.clear();
      includes.clear();
    } else {
      libs.addAll(libDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith(".a"))
          .map((f) {
        var basename = p.basename(f.path);
        basename = basename.replaceAll(RegExp("^lib"), "");
        basename = basename.replaceAll(".a", "");
        return "-l${basename}";
      }));

      flags.addAll([
        "--std=c++17",
        "-L${libDir.path}",
        "-L${sqliteDir.path}",
        "-fPIC",
        "-lcurl",
        "-lssl",
        "-lcrypto",
        "-lz",
        "-lsqlite3",
        if (targetOS == OS.android) ...[
          "-landroid",
          "-lidn2",
          "-lunistring",
          "-liconv"
        ],
        ...libs,
        if (targetOS == OS.iOS || targetOS == OS.macOS) ...[
          "-framework",
          "CoreFoundation",
          "-framework",
          "SystemConfiguration"
        ],
        if (targetOS == OS.iOS) ...[
          '-mios-version-min=13.0',
          '-framework',
          'Security'
        ]
      ]);
    }

    final cbuilder = CBuilder.library(
      name: packageName,
      language: Language.cpp,
      assetName: 'cesium_native/cesium_native.dart',
      sources: sources,
      includes: includes,
      flags: flags,
      libraryDirectories:[libDir.path, sqliteDir.path]
    );

    await cbuilder.run(
      input: input,
      output: output,
      logger: logger,
    );

    // this conflicts with other Dart packages that ship libc++_shared.so (e.g.
    // Thermion). I've commented out rather than deleted in case we want to
    // reintroduce in future - if building without a package that ships
    // libc++_shared.so, I think the straightforward option will be to
    // add to Android's jniLibs for the app.

    // if (targetOS == OS.android && !config.dryRun) {
    //   var compilerPath = config.cCompiler.compiler!.path;

    //   if (Platform.isWindows && compilerPath.startsWith("/")) {
    //     compilerPath = compilerPath.substring(1);
    //   }

    //   var ndkRoot = File(compilerPath)
    //       .parent
    //       .parent
    //       .uri
    //       .toFilePath(windows: true)
    //       .replaceAll("//", "/");

    //   var stlPath = File([
    //     ndkRoot,
    //     "sysroot",
    //     "usr",
    //     "lib",
    //     targetArch,
    //     "libc++_shared.so"
    //   ].join(Platform.pathSeparator));

    //   if (!stlPath.existsSync()) {
    //     stlPath =
    //         File(stlPath.path.replaceAll("arm64-v8a", "aarch64-linux-android"));
    //   }

    //   output.addAsset(NativeCodeAsset(
    //       package: packageName,
    //       name: "libc++_shared.so",
    //       linkMode: LookupInProcess(),
    //       os: targetOS,
    //       // file: stlPath.uri,
    //       architecture: targetArchitecture));
    // }
  });
}

const _cesiumNativeVersion = "v0.39.0";
const _sqliteVersion = "3470000";

String _getLibraryUrl(String platform, String mode, String arch) {
  return "https://pub-b19d1b9d30844d689622bf750da1df69.r2.dev/cesium-native-$_cesiumNativeVersion-$platform-$arch-$mode.zip";
}

String _getSqliteUrl(String platform) {
  switch (platform) {
    case "windows":
      return "https://sqlite.org/2024/sqlite-dll-win-x64-$_sqliteVersion.zip";
    case "android":
      return "https://sqlite.org/2024/sqlite-android-$_sqliteVersion.aar";
    case "linux":
      return "https://www.sqlite.org/2024/sqlite-tools-linux-x64-$_sqliteVersion.zip";
    case "macos":
    case "ios":
      return "https://www.sqlite.org/2024/sqlite-tools-osx-x64-$_sqliteVersion.zip";
    default:
      throw Exception("Unsupported platform for SQLite: $platform");
  }
}

//
// Download precompiled Cesium Native libraries for the target platform from Cloudflare.
//
Future<Directory> getLibDir(
    Uri packageRoot, OS targetOS, Logger logger, String targetArch) async {
  var platform = targetOS.toString().toLowerCase();

  var mode = "release";

  var libDir = Directory(
      "${packageRoot.toFilePath()}/.dart_tool/cesium_3d_native/lib/$_cesiumNativeVersion/$platform/$mode/${targetArch}");

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

    late Archive archive;

    try {
      archive = ZipDecoder().decodeBytes(await libraryZip.readAsBytes());
    } catch (err) {
      throw Exception("Failed to decode archive at ${libraryZip.path} : $err");
    }

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

  final sqliteDir = Directory(
      "${packageRoot.toFilePath()}/.dart_tool/cesium_3d_native/sqlite/$_sqliteVersion/$platform/${targetArch}");
  await _downloadAndExtractSqlite(sqliteDir, _getSqliteUrl(platform), logger);

  return libDir;
}

Future<void> _downloadAndExtractSqlite(
    Directory targetDir, String url, Logger logger) async {
  final filename = url.split("/").last;
  final unzipDir = targetDir.path;
  final successToken = File("$unzipDir/success");
  final archiveFile = File("$unzipDir/$filename");

  if (!successToken.existsSync()) {
    if (!archiveFile.parent.existsSync()) {
      archiveFile.parent.createSync(recursive: true);
    }

    logger.info("Downloading SQLite from $url");
    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();
    await response.pipe(archiveFile.openWrite());

    // Extract based on file type
    if (filename.endsWith('.zip')) {
      final archive = ZipDecoder().decodeBytes(await archiveFile.readAsBytes());
      for (final file in archive) {
        if (file.isFile) {
          final f = File('${unzipDir}/${file.name}');
          await f.create(recursive: true);
          await f.writeAsBytes(file.content as List<int>);
        }
      }
    } else if (filename.endsWith('.tar.gz')) {
      // Handle .tar.gz files
      final gzipBytes = await archiveFile.readAsBytes();
      final tarBytes = GZipDecoder().decodeBytes(gzipBytes);
      final archive = TarDecoder().decodeBytes(tarBytes);

      for (final file in archive) {
        if (file.isFile) {
          final f = File('${unzipDir}/${file.name}');
          await f.create(recursive: true);
          await f.writeAsBytes(file.content as List<int>);
        }
      }
    }

    successToken.writeAsStringSync("SUCCESS");
  }
}
