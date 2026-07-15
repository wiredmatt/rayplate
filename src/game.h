#ifndef GAME_H
#define GAME_H

#include <rl_alias.h>

typedef struct GAME_Game {
  Vector2 trianglePositions[3];
  int selectedVertex;
  bool linesMode;
  float handleRadius;
} GAME_Game;

bool GAME_GameInit(GAME_Game *game);
void GAME_GameUpdate(GAME_Game *game);
void GAME_GameDraw(const GAME_Game *game);

#endif
