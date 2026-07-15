#include "game.h"

#include <rl_alias.h>

#if defined(RAYPLATE_ANGLE_ENABLED)
#include "graphics_api.h"
#endif

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#endif

static const int GAME_SCREEN_WIDTH = 800;
static const int GAME_SCREEN_HEIGHT = 450;
static const int GAME_TARGET_FPS = 60;
static const char *GAME_DISPLAY_NAME = "My Game";

static GAME_Game GAME_INSTANCE;

static void GAME_RunFrame(void *context) {
  GAME_Game *game = context;

#if defined(PLATFORM_WEB)
  if (RLIB_WindowShouldClose()) {
    emscripten_cancel_main_loop();
    RLIB_CloseWindow();
    return;
  }
#endif

  GAME_GameUpdate(game);
  GAME_GameDraw(game);
}

int main(int argc, char **argv) {
#if defined(RAYPLATE_ANGLE_ENABLED)
  GraphicsApiConfigureResult graphicsResult = GraphicsApiConfigure(argc, argv);
  if (graphicsResult == GRAPHICS_API_CONFIGURE_EXIT)
    return 0;
  if (graphicsResult == GRAPHICS_API_CONFIGURE_ERROR)
    return 2;
#else
  (void)argc;
  (void)argv;
#endif

  RLIB_InitWindow(GAME_SCREEN_WIDTH, GAME_SCREEN_HEIGHT, GAME_DISPLAY_NAME);

  if (!GAME_GameInit(&GAME_INSTANCE)) {
    RLIB_CloseWindow();
    return 3;
  }

#if defined(RAYPLATE_ANGLE_ENABLED)
  GraphicsApiLogRenderer();
#endif

  RLIB_SetTargetFPS(GAME_TARGET_FPS);

#if defined(PLATFORM_WEB)
  emscripten_set_main_loop_arg(GAME_RunFrame, &GAME_INSTANCE, GAME_TARGET_FPS,
                               1);
#else
  while (!RLIB_WindowShouldClose())
    GAME_RunFrame(&GAME_INSTANCE);

  RLIB_CloseWindow();
#endif

  return 0;
}
