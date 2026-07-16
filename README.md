# Rayplate

Rayplate is a raylib 6.0 CMake template with runtime-selectable native graphics backends through [ANGLE](https://chromium.googlesource.com/angle/angle). Application code continues to use raylib and rlgl normally; raylib targets OpenGL ES 3 while ANGLE translates it to the selected platform API.

| Platform | Launch values | Default |
| --- | --- | --- |
| Windows x64 | `directx`, `vulkan`, `opengl` | DirectX 11 |
| Windows ARM64 | `directx`, `vulkan` | DirectX 11 |
| Linux | `vulkan`, `opengl` | Vulkan |
| macOS | `metal`, `opengl` | Metal |

The desktop build downloads a SHA-256-locked ANGLE runtime bundle produced from Electron. Web builds use Emscripten and WebGL.

## Use this template

Set the four project identity values at the top of `CMakeLists.txt` before you start building your game:

```cmake
set(GAME_BIN_NAME "my_game" CACHE STRING "Executable and build target name")
set(GAME_WINDOW_TITLE "My Game" CACHE STRING "Human-readable application name")
set(GAME_VERSION "0.1.0" CACHE STRING "Application version")
set(GAME_BUNDLE_IDENTIFIER "com.example.my-game" CACHE STRING "application bundle identifier")
```

The target name controls native executable, macOS bundle, and web artifact filenames. The display name, version, and bundle identifier configure platform metadata. Change `GAME_WINDOW_TITLE` in `src/main.c` to set the sample window title, then replace the sample game code there. The bundled release workflow intentionally retains its existing `my_game` artifact paths, so update those paths separately if you
change `GAME_BIN_NAME` and still use that workflow.

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

The repository vendors only [Khronos's platform-independent GLES declarations](third_party/khronos/README.md). At link time, rlgl's GLES calls resolve directly to the selected Electron `libGLESv2`; GLFW loads Electron's `libEGL` to create the ANGLE context. Host OpenGL remains available only for GLFW's alternate native context implementation.

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
  ninja-build \
  pkg-config
```

Configure and build:

```sh
cmake --preset desktop-debug
cmake --build --preset desktop-debug --parallel
ctest --preset desktop-debug
```

Run the configure and build commands once after cloning. They generate the compilation database used by code editors. The included `.clangd` points clangd at `build/desktop-debug`; reload the editor after the first build if it was already open.

`desktop-release` builds an optimized desktop application,
`desktop-sanitize` enables runtime memory and undefined-behavior checks, and
`desktop-no-angle` is useful when you want raylib's native OpenGL path. 

These presets use Ninja; the equivalent generator-independent commands remain available:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

The ANGLE libraries, Electron's matching Linux Vulkan loader, and their license/provenance manifest are staged automatically. Linux and Windows place them beside the executable; macOS places them in the standard locations inside `build/my_game.app`.

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
./build/my_game.app/Contents/MacOS/my_game --graphics-api=metal
./build/my_game.app/Contents/MacOS/my_game --graphics-api=opengl

# Or launch the bundle through Finder-compatible tooling
open build/my_game.app --args --graphics-api=metal
```

`--graphics-api value` is also accepted. The startup log reports both the requested backend and ANGLE's actual `GL_RENDERER` string.

For a Steam-native selection popup, create one Steamworks launch option per supported value and pass the corresponding argument. Steam owns that popup; the executable only needs the command-line interface above.

## macOS application bundle and Gatekeeper

macOS builds produce a conventional application bundle:

```text
my_game.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/my_game
    ├── Frameworks/
    │   ├── libEGL.dylib
    │   └── libGLESv2.dylib
    └── Resources/angle-licenses/
```

Set `GAME_MACOS_ADHOC_SIGN=OFF` only when another packaging system will sign the finished bundle itself. The default bundle identity and version can be changed with `GAME_BUNDLE_IDENTIFIER` and `GAME_VERSION`.

## Fully local or offline ANGLE

The default provider is `DOWNLOAD`. It downloads a release bundle whose complete SHA-256 is locked in [`cmake/AngleArtifacts.cmake`](cmake/AngleArtifacts.cmake).

To use an already extracted runtime without any ANGLE network access:

```sh
cmake -S . -B build/local-angle \
  -DGAME_ANGLE_PROVIDER=LOCAL \
  -DGAME_ANGLE_ROOT=/absolute/path/to/extracted-angle
cmake --build build/local-angle --parallel
```

The directory may be an extracted Rayplate bundle or any directory tree containing the platform's matching `libEGL` and `libGLESv2` shared libraries. Electron's Linux build also needs its matching `libvulkan.so.1` beside ANGLE when the Vulkan backend is used; the Rayplate bundle includes it automatically.

To use a local Rayplate bundle:

```sh
cmake -S . -B build/local-angle \
  -DGAME_ANGLE_PROVIDER=LOCAL \
  -DGAME_ANGLE_ARCHIVE=/absolute/path/to/rayplate-angle-electron-43.1.1-linux-x64.tar.gz \
  -DGAME_ANGLE_LOCAL_SHA256=<sha256>
cmake --build build/local-angle --parallel
```

The local checksum is optional for a trusted file but recommended. No vcpkg, Python, or Electron installation is required for either local ANGLE mode. For a completely network-free build, also provide a local raylib checkout:

```sh
cmake -S . -B build/offline \
  -DGAME_ANGLE_PROVIDER=LOCAL \
  -DGAME_ANGLE_ARCHIVE=/offline/rayplate-angle-electron-43.1.1-linux-x64.tar.gz \
  -DFETCHCONTENT_SOURCE_DIR_RAYLIB=/offline/raylib
```

To disable ANGLE and use an ordinary raylib platform configuration:

```sh
cmake -S . -B build/no-angle \
  -DGAME_ANGLE_PROVIDER=OFF \
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

Package revision `1` uses the `angle-electron-v<version>` tag. If packaging for an Electron version must be corrected without replacing immutable assets, dispatch with `-f package_revision=2` (or the next unused number); this publishes `angle-electron-v<version>-r2`.

After publishing, update the version, release tag, and six bundle hashes in `cmake/AngleArtifacts.cmake`. Keeping those hashes in the source tree means a replaced or tampered GitHub asset is rejected during CMake configuration.

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

A checksum alone cannot prove software is benign. The stronger malware/supply-chain property here is provenance: the ANGLE packaging workflow
performs no compilation or binary rewriting, and its manifest records files extracted byte-for-byte from the official Electron release. When producing a macOS application, CMake verifies that source bundle first and then ad-hoc signs its staged dylib copies; that necessarily changes their Mach-O signature metadata. The included manifest continues to identify and hash the verified pre-signing Electron inputs.

## Build for web

Install Emscripten and configure through `emcmake`:

```sh
emcmake cmake -S . -B build/web -DPLATFORM=Web
cmake --build build/web --parallel
```

This produces `my_game.html`, `my_game.js`, and `my_game.wasm`. Serve the directory through a local web server rather than opening the HTML file directly.

Pushes to `main` also build and deploy these files to GitHub Pages through
[`deploy-pages.yml`](.github/workflows/deploy-pages.yml). Enable GitHub Pages
with **GitHub Actions** as its source before the first deployment. The deployed
site uses `my_game.html` as its root `index.html`.

## API alias generation

The generated `rl_alias.h` includes both API layers:

- raylib functions and public value constants use `RAYLIB_ALIAS_PREFIX` (`RLIB_`
  by default), for example `RLIB_LoadShader`, `RLIB_DARKGRAY`, and
  `RLIB_KEY_SPACE`.
- rlgl functions and constants use `RLGL_ALIAS_PREFIX` (`RLGL_` by default),
  for example `RLGL_LoadShader` and `RLGL_TRIANGLES`.

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

## Build diagnostics

Application code is compiled as portable C99 with compiler extensions disabled.
Warnings are enabled at `/W4` on MSVC and `-Wall -Wextra -Wpedantic` on GCC and Clang. 
To make those application warnings fatal (as CI does), configure with:

```sh
cmake -S . -B build -DGAME_WARNINGS_AS_ERRORS=ON
```

AddressSanitizer can catch memory errors during local debug builds. GCC and Clang builds also enable UndefinedBehaviorSanitizer:

```sh
cmake --preset desktop-sanitize
cmake --build --preset desktop-sanitize --parallel
ctest --preset desktop-sanitize
```

Sanitizers are intended for native development builds, not WebAssembly or release packaging.
Source formatting follows `.clang-format` and basic editor behavior follows `.editorconfig`; check C formatting with `clang-format --dry-run --Werror src/*.c src/*.h`.

## Application releases

Pushing to `main` updates the rolling `latest` application release. Semver-style tags create immutable versioned application releases:

```sh
git tag v1.2.3
git push origin v1.2.3
```

Tags containing `-alpha`, `-beta`, or `-rc` are marked as prereleases.
