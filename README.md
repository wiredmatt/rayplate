# Rayplate

Rayplate is a raylib 6.0 CMake template with runtime-selectable native graphics backends through [ANGLE](https://chromium.googlesource.com/angle/angle). Application code continues to use raylib and rlgl normally; raylib targets OpenGL ES 3 while ANGLE translates it to the selected platform API.

| Platform | Launch values | Default |
| --- | --- | --- |
| Windows x64 | `directx`, `vulkan`, `opengl` | DirectX 11 |
| Windows ARM64 | `directx`, `vulkan` | DirectX 11 |
| Linux | `vulkan`, `opengl` | Vulkan |
| macOS | `metal`, `opengl` | Metal |

The desktop build downloads a small, SHA-256-locked ANGLE runtime bundle produced from Electron. Web builds continue to use Emscripten/WebGL without ANGLE.

```c
#include "graphics_api.h"
#include <rl_alias.h>

int main(int argc, char **argv)
{
    GraphicsApiConfigureResult result = GraphicsApiConfigure(argc, argv);
    if (result != GRAPHICS_API_CONFIGURE_CONTINUE)
        return (result == GRAPHICS_API_CONFIGURE_EXIT)? 0 : 2;

    RLIB_InitWindow(800, 450, "My game");
    GraphicsApiLogRenderer();

    while (!RLIB_WindowShouldClose())
    {
        RLIB_BeginDrawing();
        RLIB_ClearBackground(RAYWHITE);
        RLIB_DrawText("Hello from raylib through ANGLE", 120, 210, 20, DARKGRAY);
        RLIB_EndDrawing();
    }

    RLIB_CloseWindow();
    return 0;
}
```

## How the graphics stack works

Rayplate builds raylib and rlgl for OpenGL ES 3 and uses raylib's bundled GLFW EGL context path. At startup, `--graphics-api` selects an ANGLE renderer before `InitWindow()` creates the context.

```text
raylib / rlgl (OpenGL ES 3)
            |
          ANGLE
     /       |       \
 DirectX  Vulkan  Metal/OpenGL
```

Normal raylib drawing APIs and rlgl calls remain available. Custom raw shaders must be valid GLSL ES 3 shaders, generally using `#version 300 es`, rather than desktop-only GLSL.

## Build

raylib 6.0 requires CMake 3.25 or newer. CMake downloads both the pinned raylib source and the much smaller prepackaged ANGLE runtime.

On Debian or Ubuntu, install the desktop window-system dependencies:

```sh
sudo apt update
sudo apt install \
  build-essential \
  cmake \
  git \
  libgl1-mesa-dev \
  libwayland-bin \
  libwayland-dev \
  libx11-dev \
  libxcursor-dev \
  libxext-dev \
  libxi-dev \
  libxinerama-dev \
  libxrandr-dev \
  libxkbcommon-dev \
  pkg-config
```

Configure and build:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

The ANGLE libraries and their license/provenance manifest are staged beside the executable automatically.

Electron's Windows ARM64 ANGLE build does not contain the WGL/OpenGL renderer, so that one architecture intentionally omits `opengl`. The packaging script fails closed if an Electron update lacks any backend expected for its target.

## Select a graphics API

```sh
# Linux
./build/my_game --graphics-api=vulkan
./build/my_game --graphics-api=opengl

# Windows
my_game.exe --graphics-api=directx
my_game.exe --graphics-api=vulkan
my_game.exe --graphics-api=opengl

# macOS
./my_game --graphics-api=metal
./my_game --graphics-api=opengl
```

`--graphics-api value` is also accepted. The startup log reports both the requested backend and ANGLE's actual `GL_RENDERER` string.

For a Steam-native selection popup, create one Steamworks launch option per supported value and pass the corresponding argument. Steam owns that popup; the executable only needs the command-line interface above.

## Fully local or offline ANGLE

The default provider is `DOWNLOAD`. It downloads a release bundle whose complete SHA-256 is locked in [`cmake/AngleArtifacts.cmake`](cmake/AngleArtifacts.cmake).

To use an already extracted runtime without any ANGLE network access:

```sh
cmake -S . -B build/local-angle \
  -DRAYPLATE_ANGLE_PROVIDER=LOCAL \
  -DRAYPLATE_ANGLE_ROOT=/absolute/path/to/extracted-angle
cmake --build build/local-angle --parallel
```

The directory may be an extracted Rayplate bundle or any directory tree containing the platform's matching `libEGL` and `libGLESv2` shared libraries.

To use a local Rayplate bundle:

```sh
cmake -S . -B build/local-angle \
  -DRAYPLATE_ANGLE_PROVIDER=LOCAL \
  -DRAYPLATE_ANGLE_ARCHIVE=/absolute/path/to/rayplate-angle-electron-43.1.1-linux-x64.tar.gz \
  -DRAYPLATE_ANGLE_LOCAL_SHA256=<sha256>
cmake --build build/local-angle --parallel
```

The local checksum is optional for a trusted file but recommended. No vcpkg, Python, or Electron installation is required for either local ANGLE mode. For a completely network-free build, also provide a local raylib checkout:

```sh
cmake -S . -B build/offline \
  -DRAYPLATE_ANGLE_PROVIDER=LOCAL \
  -DRAYPLATE_ANGLE_ARCHIVE=/offline/rayplate-angle-electron-43.1.1-linux-x64.tar.gz \
  -DFETCHCONTENT_SOURCE_DIR_RAYLIB=/offline/raylib
```

To disable ANGLE and use an ordinary raylib platform configuration:

```sh
cmake -S . -B build/no-angle \
  -DRAYPLATE_ANGLE_PROVIDER=OFF \
  -DPLATFORM=Desktop
cmake --build build/no-angle --parallel
```

## Produce ANGLE bundles locally

[`scripts/package_angle.py`](scripts/package_angle.py) downloads an official Electron archive, verifies it against Electron's `SHASUMS256.txt`, extracts only the runtime libraries and notices, records every file in `manifest.json`, and creates a deterministic archive.

```sh
python3 scripts/package_angle.py \
  --electron-version 43.1.1 \
  --target linux-x64
```

Available targets are `windows-x64`, `windows-arm64`, `linux-x64`, `linux-arm64`, `macos-x64`, and `macos-arm64`.

For a completely offline packaging run, provide an existing Electron ZIP and its known hash:

```sh
python3 scripts/package_angle.py \
  --electron-version 43.1.1 \
  --target linux-x64 \
  --archive /offline/electron-v43.1.1-linux-x64.zip \
  --archive-sha256 <electron-archive-sha256>
```

Python 3.10 or newer is required only to create bundles, not to build or run the game.

## Publish a new ANGLE runtime release

The manually triggered [`package-angle.yml`](.github/workflows/package-angle.yml) workflow packages all six targets concurrently, creates `SHA256SUMS`, generates signed GitHub/Sigstore provenance, and publishes an `angle-electron-v<version>` release. It refuses to replace an existing version.

```sh
gh workflow run package-angle.yml -f electron_version=43.1.1
gh run watch
```

After publishing a new Electron version, update the version and six bundle hashes in `cmake/AngleArtifacts.cmake`. Keeping those hashes in the source tree means a replaced or tampered GitHub asset is rejected during CMake configuration.

Verify a downloaded release bundle manually:

```sh
sha256sum --check SHA256SUMS --ignore-missing
gh attestation verify rayplate-angle-electron-43.1.1-linux-x64.tar.gz \
  --repo wiredmatt/rayplate
```

The integrity layers are:

- Electron's source archive is checked against its official release checksum.
- The bundle manifest records the source archive and every extracted file's SHA-256.
- `SHA256SUMS` covers every published bundle.
- CMake pins the complete bundle hash in source control.
- GitHub's Sigstore-backed attestation identifies the exact workflow and repository that produced the bundle.

A checksum alone cannot prove software is benign. The stronger malware/supply-chain property here is provenance: the workflow performs no compilation or binary rewriting and the manifest shows that shipped binaries were extracted byte-for-byte from the official Electron release.

## Build for web

Install Emscripten and configure through `emcmake`:

```sh
emcmake cmake -S . -B build/web -DPLATFORM=Web
cmake --build build/web --parallel
```

This produces `my_game.html`, `my_game.js`, and `my_game.wasm`. Serve the directory through a local web server rather than opening the HTML file directly.

## API alias generation

The generated `rl_alias.h` includes both API layers:

- raylib functions use `RAYLIB_ALIAS_PREFIX` (`RLIB_` by default), for example `RLIB_LoadShader`.
- rlgl functions use `RLGL_ALIAS_PREFIX` (`RLGL_` by default), for example `RLGL_LoadShader`.

Select inline wrappers, macros, or disable aliases with `RL_ALIAS_MODE`:

```sh
cmake -S . -B build -DRL_ALIAS_MODE=INLINE
cmake -S . -B build -DRL_ALIAS_MODE=DEFINE
cmake -S . -B build -DRL_ALIAS_MODE=""
```

Prefixes can be changed independently:

```sh
cmake -S . -B build \
  -DRAYLIB_ALIAS_PREFIX=GAME_ \
  -DRLGL_ALIAS_PREFIX=GPU_
```

When aliases are disabled, application source must include `raylib.h`/`rlgl.h` and use the original API names.

## Application releases

Pushing to `main` updates the rolling `latest` application release. Semver-style tags create immutable versioned application releases:

```sh
git tag v1.2.3
git push origin v1.2.3
```

Tags containing `-alpha`, `-beta`, or `-rc` are marked as prereleases.
