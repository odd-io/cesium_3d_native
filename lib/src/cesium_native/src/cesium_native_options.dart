class CesiumNativeOptions {
  /// The path where the SQLite cache database will be stored
  final String? cacheDbPath;

  /// Number of threads to use for processing tasks
  final int numThreads;

  const CesiumNativeOptions({
    this.cacheDbPath,
    this.numThreads = 16,
  });
}
