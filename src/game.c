#include "game.h"

static const Vector2 GAME_STARTING_POSITIONS[3] = {
    {400.0f, 150.0f},
    {300.0f, 300.0f},
    {500.0f, 300.0f},
};
static const int GAME_VERTEX_COUNT = 3;
static const float GAME_HANDLE_RADIUS = 8.0f;

static void GAME_ResetTriangle(GAME_Game *game) {
  for (int index = 0; index < GAME_VERTEX_COUNT; index++)
    game->trianglePositions[index] = GAME_STARTING_POSITIONS[index];
}

static void GAME_DrawTriangle(const GAME_Game *game) {
  if (game->linesMode) {
    RLGL_Begin(RL_LINES);
    RLGL_Color4ub(255, 0, 0, 255);
    RLGL_Vertex2f(game->trianglePositions[0].x, game->trianglePositions[0].y);
    RLGL_Color4ub(0, 255, 0, 255);
    RLGL_Vertex2f(game->trianglePositions[1].x, game->trianglePositions[1].y);

    RLGL_Color4ub(0, 255, 0, 255);
    RLGL_Vertex2f(game->trianglePositions[1].x, game->trianglePositions[1].y);
    RLGL_Color4ub(0, 0, 255, 255);
    RLGL_Vertex2f(game->trianglePositions[2].x, game->trianglePositions[2].y);

    RLGL_Color4ub(0, 0, 255, 255);
    RLGL_Vertex2f(game->trianglePositions[2].x, game->trianglePositions[2].y);
    RLGL_Color4ub(255, 0, 0, 255);
    RLGL_Vertex2f(game->trianglePositions[0].x, game->trianglePositions[0].y);
    RLGL_End();
    return;
  }

  RLGL_Begin(RL_TRIANGLES);
  RLGL_Color4ub(255, 0, 0, 255);
  RLGL_Vertex2f(game->trianglePositions[0].x, game->trianglePositions[0].y);
  RLGL_Color4ub(0, 255, 0, 255);
  RLGL_Vertex2f(game->trianglePositions[1].x, game->trianglePositions[1].y);
  RLGL_Color4ub(0, 0, 255, 255);
  RLGL_Vertex2f(game->trianglePositions[2].x, game->trianglePositions[2].y);
  RLGL_End();
}

static void GAME_DrawVertexHandles(const GAME_Game *game) {
  Vector2 mousePosition = RLIB_GetMousePosition();
  for (int index = 0; index < GAME_VERTEX_COUNT; index++) {
    Vector2 position = game->trianglePositions[index];
    if (RLIB_CheckCollisionPointCircle(mousePosition, position,
                                       game->handleRadius))
      RLIB_DrawCircleV(position, game->handleRadius,
                       RLIB_ColorAlpha(DARKGRAY, 0.5f));
    if (index == game->selectedVertex)
      RLIB_DrawCircleV(position, game->handleRadius, DARKGRAY);
    RLIB_DrawCircleLinesV(position, game->handleRadius, BLACK);
  }
}

static void GAME_DrawControls(void) {
  RLIB_DrawText("SPACE: Toggle lines mode", 10, 10, 20, DARKGRAY);
  RLIB_DrawText("LEFT-RIGHT: Toggle backface culling", 10, 40, 20, DARKGRAY);
  RLIB_DrawText("MOUSE: Click and drag vertex points", 10, 70, 20, DARKGRAY);
  RLIB_DrawText("R: Reset triangle to start positions", 10, 100, 20, DARKGRAY);
}

bool GAME_GameInit(GAME_Game *game) {
  if (!game)
    return false;

  game->selectedVertex = -1;
  game->linesMode = false;
  game->handleRadius = GAME_HANDLE_RADIUS;
  GAME_ResetTriangle(game);
  return true;
}

void GAME_GameUpdate(GAME_Game *game) {
  if (RLIB_IsKeyPressed(KEY_SPACE))
    game->linesMode = !game->linesMode;

  Vector2 mousePosition = RLIB_GetMousePosition();
  for (int index = 0; index < GAME_VERTEX_COUNT; index++) {
    if (RLIB_CheckCollisionPointCircle(mousePosition,
                                       game->trianglePositions[index],
                                       game->handleRadius) &&
        RLIB_IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
      game->selectedVertex = index;
      break;
    }
  }

  if (game->selectedVertex != -1) {
    Vector2 mouseDelta = RLIB_GetMouseDelta();
    Vector2 *position = &game->trianglePositions[game->selectedVertex];
    position->x += mouseDelta.x;
    position->y += mouseDelta.y;
  }

  if (RLIB_IsMouseButtonReleased(MOUSE_BUTTON_LEFT))
    game->selectedVertex = -1;
  if (RLIB_IsKeyPressed(KEY_LEFT))
    RLGL_EnableBackfaceCulling();
  if (RLIB_IsKeyPressed(KEY_RIGHT))
    RLGL_DisableBackfaceCulling();
  if (RLIB_IsKeyPressed(KEY_R)) {
    GAME_ResetTriangle(game);
    RLGL_EnableBackfaceCulling();
  }
}

void GAME_GameDraw(const GAME_Game *game) {
  RLIB_BeginDrawing();
  RLIB_ClearBackground(RAYWHITE);
  GAME_DrawTriangle(game);
  GAME_DrawVertexHandles(game);
  GAME_DrawControls();
  RLIB_EndDrawing();
}
