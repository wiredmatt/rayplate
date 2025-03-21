# Rayplate

A neat raylib 5.5 template using git submodules, cmake and custom aliases, mapping functions such as `InitWindow` to `rlInitWindow`; fully customizable and available either through `#define` macros, or static inline (default).

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
```

### Build

```sh
cmake -B build && cmake --build build
```

### Run

```sh
./build/my_game # or ./build/my_game.exe
```

## Customizing rl_alias generation

### Disabling rl_alias generation

Set `set(USE_RL_ALIAS_INLINE OFF)` and `set(USE_RL_ALIAS_DEFINE OFF)` in the [./vendor/CMakeLists.txt](./vendor/CMakeLists.txt) file.

### Enabling inline rl_alias generation

You may enable inline alias by setting `set(USE_RL_ALIAS_INLINE ON)` in the [./vendor/CMakeLists.txt](./vendor/CMakeLists.txt) file.

### Enabling \#define rl_alias generation

You may enable `#define` alias by setting `set(USE_RL_ALIAS_DEFINE ON)` in the [./vendor/CMakeLists.txt](./vendor/CMakeLists.txt) file.
