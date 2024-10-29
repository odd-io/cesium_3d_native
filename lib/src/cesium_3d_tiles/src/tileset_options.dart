class TilesetOptions {
    final bool forbidHoles;
    final bool enableLodTransitionPeriod;
    final double lodTransitionLength;
    final bool enableOcclusionCulling;
    final bool enableFogCulling;
    final bool enableFrustumCulling;
    final bool enforceCulledScreenSpaceError;
    final double culledScreenSpaceError;
    final double maximumScreenSpaceError;
    final int maximumSimultaneousTileLoads;
    final int maximumSimultaneousSubtreeLoads;
    final int loadingDescendantLimit;

  const TilesetOptions({
    this.forbidHoles = false,
    this.enableLodTransitionPeriod = false,
    this.lodTransitionLength = 1.0,
    this.enableOcclusionCulling = true,
    this.enableFogCulling = true,
    this.enableFrustumCulling = true,
    this.enforceCulledScreenSpaceError = true,
    this.culledScreenSpaceError = 64.0,
    this.maximumScreenSpaceError = 16.0,
    this.maximumSimultaneousTileLoads = 20,
    this.maximumSimultaneousSubtreeLoads = 20,
    this.loadingDescendantLimit = 20,
  });
}