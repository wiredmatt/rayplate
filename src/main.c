#include "game.h"

#if defined(GAME_ANGLE_ENABLED)
#include "angle_cfg.h"
#endif

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#endif

int main(int argc, char **argv) {
#if defined(GAME_ANGLE_ENABLED) // Configure ANGLE if enabled
  ANGLE_ConfigureResult angleResult = ANGLE_Configure(argc, argv);
  if (angleResult == ANGLE_CONFIGURE_EXIT)
    return 0;
  if (angleResult == ANGLE_CONFIGURE_ERROR)
    return 2;
#endif

  (void)argc;
  (void)argv;

  GAME_Init(); // Initialize raylib window and game resources

#if defined(GAME_ANGLE_ENABLED)
  ANGLE_LogRenderer();
#endif

#if defined(PLATFORM_WEB) // Initialize emscripten specific main loop
  emscripten_set_main_loop(GAME_RunFrame, 0, 1);
#else // Run main game loop (desktop)

  while (!GAME_ShouldShutDown())
    GAME_RunFrame();

  GAME_ShutDown();
#endif

  return 0;
}
