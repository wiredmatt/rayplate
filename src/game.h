#ifndef GAME_H
#define GAME_H

#include <rl_alias.h>

#ifndef GAME_WINDOW_TITLE
#define GAME_WINDOW_TITLE "My Game"
#endif

#ifndef GAME_WINDOW_WIDTH
#define GAME_WINDOW_WIDTH 800
#endif

#ifndef GAME_WINDOW_HEIGHT
#define GAME_WINDOW_HEIGHT 450
#endif

#ifndef GAME_TARGET_FPS
#define GAME_TARGET_FPS 60
#endif

void GAME_GameInit(void);
void GAME_GameRunFrame(void);
static inline _Bool GAME_ShouldShutDown(void) {
  return RLIB_WindowShouldClose();
}
void GAME_ShutDown(void);

#endif