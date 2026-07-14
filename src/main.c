#include <rl_alias.h>

#if defined(RAYPLATE_ANGLE_ENABLED)
    #include "graphics_api.h"
#endif

#if defined(PLATFORM_WEB)
    #include <emscripten/emscripten.h>
#endif

static void UpdateDrawFrame(void);

int main(int argc, char **argv)
{
#if defined(RAYPLATE_ANGLE_ENABLED)
    GraphicsApiConfigureResult graphicsResult = GraphicsApiConfigure(argc, argv);
    if (graphicsResult == GRAPHICS_API_CONFIGURE_EXIT) return 0;
    if (graphicsResult == GRAPHICS_API_CONFIGURE_ERROR) return 2;
#else
    (void)argc;
    (void)argv;
#endif

    const int screenWidth = 800;
    const int screenHeight = 450;

    RLIB_InitWindow(screenWidth, screenHeight, "raylib [core] example - basic window");

#if defined(RAYPLATE_ANGLE_ENABLED)
    GraphicsApiLogRenderer();
#endif

    RLIB_SetTargetFPS(60);

#if defined(PLATFORM_WEB)
    emscripten_set_main_loop(UpdateDrawFrame, 60, 1);
#else
    while (!RLIB_WindowShouldClose()) UpdateDrawFrame();
#endif

    RLIB_CloseWindow();
    return 0;
}

static void UpdateDrawFrame(void)
{
    // clang-format off
    RLIB_BeginDrawing();

        RLIB_ClearBackground(RAYWHITE);

        RLIB_DrawText("Congrats! You created your first window!", 190, 200, 20, LIGHTGRAY);

    RLIB_EndDrawing();
    // clang-format on
}
