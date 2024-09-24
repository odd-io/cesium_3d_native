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

The `cesium_3d_tiles` library includes the `TilesetRenderer` interface, which describes a set of methods that you could use to render a multiple `Cesium3DTileset` instances to a rendering surface. The library also provides a partial implementation `BaseTilesetRenderer`, using `cesium_native` to load a tileset and manage tile content, but requires that you implement the rendering-specific logic yourself. 

The intention is that end users create their own apps that depend on `cesium_3d_tiles`, and that extend `BaseTilesetRenderer` to implement the abstract methods with a specific rendering library. You can [click here to see an example Flutter application](https://TODO) that uses the [Thermion](https://thermion.dev) rendering library to implement these abstract methods.

## Getting started

### cesium_3d_tiles

Most end users should start with the [example Flutter project](https://TODO), or running the following:
```
export CESIUM_ION_ASSET_ID=YOUR_CESIUM_ION_ASSET_TOKEN
export CESIUM_ION_ACCESS_TOKEN=YOUR_CESIUM_ION_ASSET_TOKEN
dart pub get
dart --enable-experiment=native-assets  example/get_tileset_from_ion_id ${CESIUM_ION_ASSET_ID} ${CESIUM_ION_ACCESS_TOKEN}
```

### cesium_native

The simplest starting point is to run the following:

```
export CESIUM_ION_ASSET_ID=YOUR_CESIUM_ION_ASSET_TOKEN
export CESIUM_ION_ACCESS_TOKEN=YOUR_CESIUM_ION_ASSET_TOKEN
dart pub get
dart --enable-experiment=native-assets run example/cesium_3d_tiles/get_tileset_from_ion_id ${CESIUM_ION_ASSET_ID} ${CESIUM_ION_ACCESS_TOKEN}
```




## Notes Coordinate System
Cesium 3D Tiles uses a right-handed Cartesian coordinate system, typically representing positions on or near the Earth's surface. The coordinate system is usually either:

Earth-Centered, Earth-Fixed (ECEF): A global 3D coordinate system where the origin is at the center of the Earth.
Local East-North-Up (ENU): A local coordinate system defined relative to a specific point on the Earth's surface.

Renderable
In the context of 3D Tiles, a renderable typically refers to the actual 3D content that can be displayed. This could be:

3D models (often in glTF format)
Point clouds
Instanced 3D models
Vector data

Renderables are usually associated with individual tiles and are loaded and processed as needed based on the viewer's position and the tile's visibility.
To use this package, you'll likely start by creating a CesiumView, loading a tileset, and then managing the rendering and interaction with the 3D content. The cesium_3d_tiles module should provide high-level classes and methods to simplify these tasks.

dart --enable-experiment=native-assets run test/cesium_ion_client_test.dart YOUR_ACCESS_TOKEN

## Loading

By nature, tilesets and tiles are asynchronous. 

Constructing and loading are separate processes; it is possible to create and return a valid instance of Tileset, that subsequently fails to load.

Proper instantiation should therefore look like this:

```
final tileset = CesiumNative.loadFromCesiumIon(1234, "my_access_token");
CesiumNative.updateTilesetView(tileset, // etc etc );
if(CesiumNative.hasLoadError(tileset)) { 
    final error = CesiumNative.getLoadErrorMessage(tileset);
    throw Exception(error)
}



## For developers

We have compiled Cesium Native to static C++ libraries for iOS, Android and MacOS.

At runtime, the cesium_3d_native dart package must be linked with the Cesium Native libraries (and its dependencies). 

We have already built these libraries for macOS, Windows, Android and iOS; the hook/build.dart build script will pull these automatically from Cloudflare whenever a Dart/Flutter application that depends on this package is run.

Run `build.sh` if you need to (re)build these libraries (for exampe, if the upstream Cesium Native package is updated).



```
dart --enable-experiment=native-assets run ffigen --config ffigen.yaml                
```