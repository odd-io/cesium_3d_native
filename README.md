# Cesium 3D Tiles

A Dart package for working with Cesium 3D Tiles geospatial data.

3D Tiles is an open specification for a data format for streaming and rendering 3D geospatial content, published by the [Open Geospatial Consortium (OGC)](https://www.ogc.org/standard/3dtiles/).

AGI, a member of the OGC, maintains and publishes Cesium, its own platform implementation of the 3D Tiles standard. This platform includes Cesium Native, a C++ library for working with 3D Tiles (and AGI's cloud-based 3D Tiles service, Cesium Ion). 

This Dart package is an (unofficial) wrapper around the Cesium Native library, exposing Dart bindings for a small part of the Cesium Native API, and also some higher level Dart components to make it easier to work with Cesium 3D Tiles.

## Overview

Let's recap with a brief overview of the Cesium 3D Tile format.

A *tileset* is the root of a 3D Tiles dataset, usually a JSON file like `tileset.json`. A tileset describes the overall structure of the 3D content, including metadata, a tree of tiles, and references to the actual 3D data files. *Tiles* are the basic units of 3D Tiles content, each containing a small part of the overall 3D content of the tileset. Tiles are organized in a hierarchical tree structure, allowing for efficient streaming and rendering of large datasets.

Each tile has a bounding volume (i.e. size), transform (i.e global position) and some information about its level of detail. 

Whether or not a tile should be rendered depends on the position of the camera in the global coordinate system; a tile should only be loaded/rendered if they are inside the camera frustum, and low-detail tiles should be replaced with higher-detail tiles as the camera moves closer to the tile.

At a very high-level, working with a 3D Tiles tileset involves:
1) loading a tileset
2) waiting for the root tile to load
3) passing in a camera orientation
4) traversing the tileset hierarchy to determine which tiles require rendering (given the current camera orientation)
5) fetching the tile content for any renderable tiles
6) inserting that tile content into the scene
7) removing any tile content from the scene for tiles that have been culled or refined
8) repeat steps (3)-(7) whenever the camera moves

(see the section on Rendering below for steps (6) and (7)).

Cesium Native does most of the heavy lifting for the above; this Dart package is mostly a thin wrapper so you can pass in tileset URLs, Cesium Ion asset IDs and camera matrices, and retrieve the list of renderable tiles (and their content). 

### Package structure

This package are divided into three components: 
```
lib/cesium_3d_tiles
lib/cesium_ion
lib/cesium_native
```

`cesium_3d_tiles` contains a higher-level wrapper around the bindings in `cesium_native`; if you just want to fetch and render tilesets, you should probably start here.

`cesium_native` contains Dart FFI bindings for the Cesium Native library. We have only written bindings for a small portion of the Cesium Native library; the library exposes a lot more functionality that we haven't needed to implement for our own purposes yet. If you need to extend this package to support more functionality from Cesium Native, start here. 

`cesium_ion` contains a standalone Dart implementation for retrieving Cesium Ion assets (i.e. this is totally separate from Cesium Native). This is only intended for internal testing/debugging; you probably don't want or need to use these classes.

The `cesium_native` part of this package lets you work directly (via Dart) with the Cesium Native library. 

However, most users should work directly with the [Cesium3DTileset] provided by the `cesium_3d_tiles` library. This exposes a simpler API surface for working with tilesets (including common associated requirements, like assigning visibility layers for working with multiple tilesets, and interfaces for adding marker object overlays to tilesets).

### Rendering

It's also important to note that this package *does not provide any actual rendering capabiility*. The `cesium_native` library doesn't interact directly with a rendering surface - camera parameters go in, and a list of renderable tiles comes out.

The `cesium_3d_tiles` library includes the `TilesetManager` interface, which describes a set of methods that you could use to render a multiple `Cesium3DTileset` instances to a rendering surface. The library also provides an example implementation of `QueuingTilesetManager` that uses a queue to manage/kick tiles, using `cesium_native` to load a tileset and manage tile content. Note that this requires you to implement the `TilesetRenderer` interface to provide an actual implementation of the rendering logic. 

The intention is that end users create their own apps that depend on `cesium_3d_tiles`, and that extend `TilesetRenderer` to implement the abstract methods with a specific rendering library. You can [click here to see an example Flutter application](https://TODO) that uses the [Thermion](https://thermion.dev) rendering library to implement these abstract methods.

## Getting started

### cesium_3d_tiles

Most end users should start with the [example Flutter project](https://TODO), or running the following:
```
export CESIUM_ION_ASSET_ID=YOUR_CESIUM_ION_ASSET_TOKEN
export CESIUM_ION_ACCESS_TOKEN=YOUR_CESIUM_ION_ASSET_TOKEN
dart pub get
dart --enable-experiment=native-assets run example/cesium_3d_tiles/tileset_from_ion.dart ${CESIUM_ION_ASSET_ID} ${CESIUM_ION_ACCESS_TOKEN}
```

Let's go through this script step-by-step.

First, we load the tileset from Cesium Ion.

```
var tileset = await Cesium3DTileset.fromCesiumIon(assetId, accessToken);
```

Next, we pass the current camera orientation and viewport to the tileset:

```
final cameraModelMatrix = Matrix4.identity();
final projectionMatrix = makePerspectiveMatrix(pi / 8, 1.0, 0.05, 10000000);
final viewport = (width: 1920.0, height: 1080.0);

var renderableTiles = tileset
      .updateCameraAndViewport(
          cameraModelMatrix, projectionMatrix, viewport.width, viewport.height)
      .toList();
```

> IMPORTANT - the `cesium_3d_tiles` library always expects right-handed gLTF coordinates (i.e Y is up, -Z is into the screen). If your renderer is using a different coordinate system, you will need to transform to this space first. 


```
print("${renderableTiles.length} renderable tiles");
```

`updateCameraAndViewport` will return a list of renderable tiles; however, not every renderable tile actually requires rendering. You must iterate over each tile to check its state; tiles with the `Rendered` state need to be added to your scene, tiles with `Culled`, `Refined` generally need removing from your scene (and `RenderedAndKicked` or `RefinedAndKicked` may, depending on your application logic).

```
  for (var tile in renderableTiles) {
    print("Tile state: ${tile.state}");
    switch (tile.state) {
      // if this tile needs to be rendered
      case CesiumTileSelectionState.Rendered:
        var gltfContent = tile.loadGltf();
        // implement your own logic to insert into the scene
        await tile.freeGltf();
      case CesiumTileSelectionState.None:
      // when a tile has not yet been loaded
      case CesiumTileSelectionState.Culled:
      // remove tile from scene
      case CesiumTileSelectionState.Refined:
      // remove tile from scene
      case CesiumTileSelectionState.RenderedAndKicked:
      // remove tile from scene
      case CesiumTileSelectionState.RefinedAndKicked:
      // remove tile from scene
    }
  }
```

You will see that there is no actual viewport or rendering logic here; we suggest extending `TilesetRenderer` to implement your own.

### cesium_native

As discussed above, `cesium_native` is the lower level API for working directly with the data structures returned by the Cesium Native library. `cesium_3d_tiles` is simply a set of Dart classes that wrap this API; if you need to implement some custom logic not supported by `cesium_3d_tiles` (or you need to extend `cesium_native` yourself), work with this library instead.

```
export CESIUM_ION_ASSET_ID=YOUR_CESIUM_ION_ASSET_TOKEN
export CESIUM_ION_ACCESS_TOKEN=YOUR_CESIUM_ION_ASSET_TOKEN
dart pub get
dart --enable-experiment=native-assets run example/cesium_native/get_tileset_from_ion_id.dart ${CESIUM_ION_ASSET_ID} ${CESIUM_ION_ACCESS_TOKEN}
```

Note that unlike `cesium_3d_tiles`, `cesium_native` generally returns/expects ECEF coordinates. If you work with this library, you will probably need to handle the transformation between ECEF and your renderer's coordinate system.

## Extending cesium_native 

This package ships with pre-compiled static Cesium Native libraries (arm64 only) for iOS, Android and MacOS. 

When a Dart/Flutter application that depends on this package is run, the `hook/build.dart` file uses Dart's `native-assets` library to:

1) compile this package's native C/C++ code (under `native/src`)
2) download the precompiled Cesium Native libraries for the target platform (currently via Cloudflare)
3) link (1) with (2)

We are currently shipping with Cesium Native v0.39.0.

### Building Cesium Native

If you need to (re)build the Cesium Native libraries (e.g. to update the version of Cesium Native to a new version).

1) remove the `include/Cesium*` and `generated/include/Cesium*` directories
2) run `build.sh`, which will build for all target platforms
3) copy the headers from the Cesium Native build dir to the `include` and `generated/include` directories 

On Windows, I needed to manually insert:

```
#undef OPAQUE
```

to Material.h for the Dart package to compile, there's obviously some symbol clash (I wasn't able to locate exactly where). We should be able to at least move this somewhere into our native code so we don't have to edit the Cesium Native headers.

### Updating FFI bindings

If you have updated `CesiumTilesetCApi.h`, you will need to regenerate the FFI bindings:

```
dart --enable-experiment=native-assets run ffigen --config ffigen.yaml                
```
