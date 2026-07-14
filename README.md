# Rayplate

A neat raylib 6.0 template using CMake and collision-free, SDL-style aliases for both API layers. Public raylib functions such as `InitWindow` become `RLIB_InitWindow`, while low-level rlgl functions such as `rlLoadShader` become `RLGL_LoadShader`. The aliases are customizable and available either through `#define` macros or static inline wrappers (default). CMake downloads the pinned raylib release automatically during configuration.

```c
#include <rl_alias.h>

int main(void)
{
    // Initialization
    //--------------------------------------------------------------------------------------
    const int screenWidth = 800;
    const int screenHeight = 450;

    RLIB_InitWindow(screenWidth, screenHeight, "raylib [core] example - basic window");

    RLIB_SetTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!RLIB_WindowShouldClose()) // Detect window close button or ESC key
    {
        // Update
        //----------------------------------------------------------------------------------
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------

        RLIB_BeginDrawing();

            RLIB_ClearBackground(RAYWHITE);

            RLIB_DrawText("Congrats! You created your first window!", 190, 200, 20, LIGHTGRAY);

        RLIB_EndDrawing();

        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    RLIB_CloseWindow(); // Close window and OpenGL context
    //--------------------------------------------------------------------------------------

    return 0;
}
```

## Setup

### Clone the repository

```sh
git clone git@github.com:wiredmatt/rayplate.git
cd rayplate
```

### Install Debian dependencies

On Debian, install the build dependencies:

```sh
sudo apt update
sudo apt install \
  build-essential \
  cmake \
  git \
  libgl1-mesa-dev \
  libwayland-bin \
  libdecor-0-0 \
  libdecor-0-plugin-1-gtk \
  libwayland-dev \
  libx11-dev \
  libxcursor-dev \
  libxext-dev \
  libxi-dev \
  libxinerama-dev \
  libxrandr-dev \
  libxkbcommon-dev \
  libsdl3-dev \
  pkg-config
```

These packages provide CMake, a C compiler, OpenGL headers, SDL, and the
Wayland/X11 development headers used by Linux desktop backends.

raylib 6.0 requires CMake 3.25 or newer.

If `libsdl3-dev` is not available on your Debian version, install
`libsdl2-dev` instead. raylib checks for SDL3 first and falls back to SDL2.

### Build

```sh
cmake -B build -DPLATFORM=SDL -DRL_ALIAS_MODE="INLINE" -DRAYLIB_ALIAS_PREFIX="RLIB_" -DRLGL_ALIAS_PREFIX="RLGL_" && cmake --build build # make sure to reload your IDE afterwards so rl_alias.h gets picked up and you get proper intellisense.
```

### Optional GLFW backend builds

The default build above uses SDL. If you specifically want to build raylib's
bundled GLFW backend, use a dedicated build directory so CMake cache values do
not conflict between backends.

```sh
cmake -B build/glfw-x11 -DPLATFORM=Desktop -DRL_ALIAS_MODE="INLINE" -DRAYLIB_ALIAS_PREFIX="RLIB_" -DRLGL_ALIAS_PREFIX="RLGL_" -DGLFW_BUILD_X11=ON -DGLFW_BUILD_WAYLAND=OFF && cmake --build build/glfw-x11
```

```sh
cmake -B build/glfw-wayland -DPLATFORM=Desktop -DRL_ALIAS_MODE="INLINE" -DRAYLIB_ALIAS_PREFIX="RLIB_" -DRLGL_ALIAS_PREFIX="RLGL_" -DGLFW_BUILD_X11=OFF -DGLFW_BUILD_WAYLAND=ON && cmake --build build/glfw-wayland
```

### Run

```sh
./build/my_game
./build/glfw-x11/my_game
./build/glfw-wayland/my_game
```

### Build for web

On Debian, install Emscripten:

```sh
sudo apt install emscripten
```

Then configure through `emcmake`:

```sh
emcmake cmake -B build/web -DPLATFORM=Web -DRL_ALIAS_MODE="INLINE" -DRAYLIB_ALIAS_PREFIX="RLIB_" -DRLGL_ALIAS_PREFIX="RLGL_"
cmake --build build/web
```

The web build produces:

```sh
./build/web/my_game.html
./build/web/my_game.js
./build/web/my_game.wasm
```

Serve the build directory with a local web server:

```sh
python3 -m http.server --directory build/web 8000
```

Then open `http://localhost:8000/my_game.html`.

## Releases

Pushing to `main` updates the rolling `latest` release. To publish an immutable
versioned release, push a semver-style tag:

```sh
git checkout main
git pull
git tag v1.2.3
git push origin v1.2.3
```

Tags containing `-alpha`, `-beta`, or `-rc` are published as prereleases.

## Customizing API alias generation

The generated `rl_alias.h` includes both API layers:

- raylib functions use `RAYLIB_ALIAS_PREFIX` (`RLIB_` by default), for example `RLIB_LoadShader`.
- rlgl functions use `RLGL_ALIAS_PREFIX` (`RLGL_` by default). Their existing `rl` or `rlgl` prefix is replaced, so `rlLoadShader` becomes `RLGL_LoadShader` and `rlglInit` becomes `RLGL_Init`.

### Disabling rl_alias generation

Set `RL_ALIAS_MODE=""`. The bundled example uses the generated names, so application source must also switch to `#include <raylib.h>` and the original raylib function names when aliases are disabled.

```sh
cmake -B build -DPLATFORM=SDL -DRL_ALIAS_MODE="" && cmake --build build
```

### Enabling inline rl_alias generation

Simply set `RL_ALIAS_MODE="INLINE"`

```sh
cmake -B build -DPLATFORM=SDL -DRL_ALIAS_MODE="INLINE" && cmake --build build
```

### Enabling \#define rl_alias generation

Simply set `RL_ALIAS_MODE="DEFINE"`

```sh
cmake -B build -DPLATFORM=SDL -DRL_ALIAS_MODE="DEFINE" && cmake --build build
```

### Changing the prefixes

Change either prefix independently. Prefixes are concatenated with the existing PascalCase function suffix.

```sh
cmake -B build -DPLATFORM=SDL -DRL_ALIAS_MODE="INLINE" -DRAYLIB_ALIAS_PREFIX="GAME_" -DRLGL_ALIAS_PREFIX="GPU_" && cmake --build build
```
