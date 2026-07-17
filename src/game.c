#include <im_alias.h>
#include <rl_alias.h>

#include "game.h"
#include "game_assets.h"

typedef struct GAME_Game {
  Vector2 trianglePositions[3];
  Texture2D raylibLogo;
  int selectedVertex;
  bool linesMode;
  bool backfaceCulling;
  float handleRadius;
} GAME_Game;

enum { GAME_VERTEX_COUNT = 3 };
static const Vector2 GAME_STARTING_POSITIONS[GAME_VERTEX_COUNT] = {
    {400.0f, 150.0f},
    {300.0f, 300.0f},
    {500.0f, 300.0f},
};
static const float GAME_HANDLE_RADIUS = 8.0f;

static GAME_Game game;

static void GAME_ResetTriangle(void) {
  for (int index = 0; index < GAME_VERTEX_COUNT; index++) {
    game.trianglePositions[index] = GAME_STARTING_POSITIONS[index];
  }
}

static void GAME_DrawTriangle(void) {
  if (game.backfaceCulling)
    RLGL_EnableBackfaceCulling();
  else
    RLGL_DisableBackfaceCulling();

  if (game.linesMode) {
    RLGL_Begin(RLGL_LINES);
    {
      RLGL_Color4ub(255, 0, 0, 255);
      RLGL_Vertex2f(game.trianglePositions[0].x, game.trianglePositions[0].y);

      RLGL_Color4ub(0, 255, 0, 255);
      RLGL_Vertex2f(game.trianglePositions[1].x, game.trianglePositions[1].y);

      RLGL_Color4ub(0, 255, 0, 255);
      RLGL_Vertex2f(game.trianglePositions[1].x, game.trianglePositions[1].y);

      RLGL_Color4ub(0, 0, 255, 255);
      RLGL_Vertex2f(game.trianglePositions[2].x, game.trianglePositions[2].y);

      RLGL_Color4ub(0, 0, 255, 255);
      RLGL_Vertex2f(game.trianglePositions[2].x, game.trianglePositions[2].y);

      RLGL_Color4ub(255, 0, 0, 255);
      RLGL_Vertex2f(game.trianglePositions[0].x, game.trianglePositions[0].y);
    }
    RLGL_End();
    return;
  }

  RLGL_Begin(RLGL_TRIANGLES);
  {
    RLGL_Color4ub(255, 0, 0, 255);
    RLGL_Vertex2f(game.trianglePositions[0].x, game.trianglePositions[0].y);

    RLGL_Color4ub(0, 255, 0, 255);
    RLGL_Vertex2f(game.trianglePositions[1].x, game.trianglePositions[1].y);

    RLGL_Color4ub(0, 0, 255, 255);
    RLGL_Vertex2f(game.trianglePositions[2].x, game.trianglePositions[2].y);
  }
  RLGL_End();
}

static void GAME_DrawVertexHandles(void) {
  Vector2 mousePosition = RLIB_GetMousePosition();

  for (int index = 0; index < GAME_VERTEX_COUNT; index++) {
    Vector2 position = game.trianglePositions[index];

    if (RLIB_CheckCollisionPointCircle(mousePosition, position, game.handleRadius)) {
      RLIB_DrawCircleV(position, game.handleRadius, RLIB_ColorAlpha(RLIB_DARKGRAY, 0.5f));
    }

    if (index == game.selectedVertex) {
      RLIB_DrawCircleV(position, game.handleRadius, RLIB_DARKGRAY);
    }

    RLIB_DrawCircleLinesV(position, game.handleRadius, RLIB_BLACK);
  }
}

static void GAME_DrawControls(void) {
  RLIB_DrawText("SPACE: Toggle lines mode", 10, 10, 20, RLIB_DARKGRAY);
  RLIB_DrawText("LEFT/RIGHT: Enable/disable backface culling", 10, 40, 20, RLIB_DARKGRAY);
  RLIB_DrawText("MOUSE: Click and drag vertex points", 10, 70, 20, RLIB_DARKGRAY);
  RLIB_DrawText("R: Reset triangle to start positions", 10, 100, 20, RLIB_DARKGRAY);
}

static void GAME_DrawImGui(void) {
  RGUI_BeginFrame();
  IMGUI_BeginWindow("Triangle controls", NULL, IMGUI_WindowFlags_AlwaysAutoResize);
  {
    IMGUI_Text("cimgui %s", IMGUI_GetVersion());
    IMGUI_Checkbox("Draw lines", &game.linesMode);
    IMGUI_Checkbox("Backface culling", &game.backfaceCulling);
    IMGUI_SliderFloat("Handle radius", &game.handleRadius, 4.0f, 24.0f, "%.0f px", 0);
    if (IMGUI_Button("Reset triangle", (ImVec2){0.0f, 0.0f})) {
      GAME_ResetTriangle();
      game.backfaceCulling = true;
    }
  }
  IMGUI_EndWindow();
  RGUI_EndFrame();
}

void GAME_Init(void) {
  RLIB_SetConfigFlags(RLIB_FLAG_WINDOW_HIGHDPI);
  RLIB_InitWindow(GAME_WINDOW_WIDTH, GAME_WINDOW_HEIGHT, GAME_WINDOW_TITLE);
  RLIB_SetTargetFPS(GAME_TARGET_FPS);
  RLIB_ChangeDirectory(RLIB_GetApplicationDirectory());

  RGUI_Setup(true);

  game.raylibLogo = RLIB_LoadTexture(AssetPaths.images.raylib_logo_png);
  game.selectedVertex = -1;
  game.linesMode = false;
  game.backfaceCulling = true;
  game.handleRadius = GAME_HANDLE_RADIUS;

  GAME_ResetTriangle();
}

static void GAME_GameUpdate(void) {
  if (RLIB_IsKeyPressed(RLIB_KEY_SPACE)) {
    game.linesMode = !game.linesMode;
  }

  Vector2 mousePosition = RLIB_GetMousePosition();
  for (int index = 0; index < GAME_VERTEX_COUNT; index++) {
    if (RLIB_CheckCollisionPointCircle(mousePosition, game.trianglePositions[index], game.handleRadius) &&
        RLIB_IsMouseButtonDown(RLIB_MOUSE_BUTTON_LEFT)) {
      game.selectedVertex = index;
      break;
    }
  }

  if (game.selectedVertex != -1) {
    Vector2 mouseDelta = RLIB_GetMouseDelta();
    Vector2 *position = &game.trianglePositions[game.selectedVertex];
    position->x += mouseDelta.x;
    position->y += mouseDelta.y;
  }

  if (RLIB_IsMouseButtonReleased(RLIB_MOUSE_BUTTON_LEFT)) {
    game.selectedVertex = -1;
  }

  if (RLIB_IsKeyPressed(RLIB_KEY_LEFT)) {
    game.backfaceCulling = true;
  }

  if (RLIB_IsKeyPressed(RLIB_KEY_RIGHT)) {
    game.backfaceCulling = false;
  }

  if (RLIB_IsKeyPressed(RLIB_KEY_R)) {
    GAME_ResetTriangle();
    game.backfaceCulling = true;
  }
}

static void GAME_GameDraw(void) {
  RLIB_BeginDrawing();
  {
    RLIB_ClearBackground(RLIB_RAYWHITE);
    GAME_DrawTriangle();
    GAME_DrawVertexHandles();
    RLIB_DrawTexture(game.raylibLogo, GAME_WINDOW_WIDTH - 256, 24, RLIB_WHITE);
    GAME_DrawControls();
    GAME_DrawImGui();
  }
  RLIB_EndDrawing();
}

void GAME_RunFrame(void) {
  GAME_GameUpdate();
  GAME_GameDraw();
}

void GAME_ShutDown(void) {
  RGUI_Shutdown();

  if (RLIB_IsTextureValid(game.raylibLogo))
    RLIB_UnloadTexture(game.raylibLogo);

  RLIB_CloseWindow();
}
