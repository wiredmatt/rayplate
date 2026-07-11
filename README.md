# Rayplate

A neat raylib 6.0 template using git submodules, cmake and custom aliases, mapping functions such as `InitWindow` to `rlInitWindow`; fully customizable and available either through `#define` macros, or static inline (default).

```c
#include <rl_alias.h>

int main(void)
{
    // Initialization
    //--------------------------------------------------------------------------------------
    const int screenWidth = 800;
    const int screenHeight = 450;

    rlInitWindow(screenWidth, screenHeight, "raylib [core] example - basic window");

    rlSetTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rlWindowShouldClose()) // Detect window close button or ESC key
    {
        // Update
        //----------------------------------------------------------------------------------
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------

        rlBeginDrawing();

            rlClearBackground(RAYWHITE);

            rlDrawText("Congrats! You created your first window!", 190, 200, 20, LIGHTGRAY);

        rlEndDrawing();

        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rlCloseWindow(); // Close window and OpenGL context
    //--------------------------------------------------------------------------------------

    return 0;
}
```

## Setup

### Clone repo with submodules included

```sh
git clone --recurse-submodules git@github.com:wiredmatt/rayplate.git
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

If `libsdl3-dev` is not available on your Debian version, install
`libsdl2-dev` instead. raylib checks for SDL3 first and falls back to SDL2.

### Build

```sh
cmake -B build -DPLATFORM=SDL -DRL_ALIAS_MODE="INLINE" -DRL_ALIAS_PREFIX="rl" && cmake --build build # make sure to reload your IDE afterwards so rl_alias.h gets picked up and you get proper intellisense.
```

### Optional GLFW backend builds

The default build above uses SDL. If you specifically want to build raylib's
bundled GLFW backend, use a dedicated build directory so CMake cache values do
not conflict between backends.

```sh
cmake -B build/glfw-x11 -DPLATFORM=Desktop -DRL_ALIAS_MODE="INLINE" -DRL_ALIAS_PREFIX="rl" -DGLFW_BUILD_X11=ON -DGLFW_BUILD_WAYLAND=OFF && cmake --build build/glfw-x11
```

```sh
cmake -B build/glfw-wayland -DPLATFORM=Desktop -DRL_ALIAS_MODE="INLINE" -DRL_ALIAS_PREFIX="rl" -DGLFW_BUILD_X11=OFF -DGLFW_BUILD_WAYLAND=ON && cmake --build build/glfw-wayland
```

### Run

```sh
./build/my_game
./build/glfw-x11/my_game
./build/glfw-wayland/my_game
```

### Cross-platform releases

The local CMake commands are intended for building and running the game on the host machine. Cross-platform release artifacts for Windows, macOS, web, Android, and other targets should be produced by CI/CD using target-specific toolchains.

## Customizing rl_alias generation

### Disabling rl_alias generation

Simply set `RL_ALIAS_MODE=""`

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

### Changing the prefix

Simply change `RL_ALIAS_PREFIX=` to whatever you want.

```sh
cmake -B build -DPLATFORM=SDL -DRL_ALIAS_MODE="INLINE" -DRL_ALIAS_PREFIX="CHANGEME" && cmake --build build
```
