#include <rl_alias.h>

#if defined(RAYPLATE_ANGLE_ENABLED)
#include "graphics_api.h"
#endif

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#endif

static const Vector2 startingPositions[3] = {
    {400.0f, 150.0f}, {300.0f, 300.0f}, {500.0f, 300.0f}};
static Vector2 trianglePositions[3] = {
    startingPositions[0], startingPositions[1], startingPositions[2]};

// Currently selected vertex, -1 means none
int triangleIndex = -1;
bool linesMode = false;
float handleRadius = 8.0f;

static void UpdateDrawFrame(void);

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

  const int screenWidth = 800;
  const int screenHeight = 450;

  RLIB_InitWindow(screenWidth, screenHeight,
                  "raylib [core] example - basic window");

  Vector2 startingPositions[3] = {
      {400.0f, 150.0f}, {300.0f, 300.0f}, {500.0f, 300.0f}};
  Vector2 trianglePositions[3] = {startingPositions[0], startingPositions[1],
                                  startingPositions[2]};

#if defined(RAYPLATE_ANGLE_ENABLED)
  GraphicsApiLogRenderer();
#endif

  RLIB_SetTargetFPS(60);

#if defined(PLATFORM_WEB)
  emscripten_set_main_loop(UpdateDrawFrame, 60, 1);
#else
  while (!RLIB_WindowShouldClose())
    UpdateDrawFrame();
#endif

  RLIB_CloseWindow();
  return 0;
}

static void UpdateDrawFrame(void) {
  if (RLIB_IsKeyPressed(KEY_SPACE))
    linesMode = !linesMode;

  // Check selected vertex
  for (unsigned int i = 0; i < 3; i++) {
    // If the mouse is within the handle circle
    if (RLIB_CheckCollisionPointCircle(RLIB_GetMousePosition(),
                                       trianglePositions[i], handleRadius) &&
        RLIB_IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
      triangleIndex = i;
      break;
    }
  }

  // If the user has selected a vertex, offset it by the mouse's delta this
  // frame
  if (triangleIndex != -1) {
    Vector2 *position = &trianglePositions[triangleIndex];

    Vector2 mouseDelta = RLIB_GetMouseDelta();
    position->x += mouseDelta.x;
    position->y += mouseDelta.y;
  }

  // Reset index on release
  if (RLIB_IsMouseButtonReleased(MOUSE_BUTTON_LEFT))
    triangleIndex = -1;

  // Enable/disable backface culling (2-sided triangles, slower to render)
  if (RLIB_IsKeyPressed(KEY_LEFT))
    RLGL_EnableBackfaceCulling();
  if (RLIB_IsKeyPressed(KEY_RIGHT))
    RLGL_DisableBackfaceCulling();

  // Reset triangle vertices to starting positions and reset backface culling
  if (RLIB_IsKeyPressed(KEY_R)) {
    trianglePositions[0] = startingPositions[0];
    trianglePositions[1] = startingPositions[1];
    trianglePositions[2] = startingPositions[2];

    RLGL_EnableBackfaceCulling();
  }

  RLIB_BeginDrawing();

  RLIB_ClearBackground(RAYWHITE);

  if (linesMode) {
    // Draw triangle with lines
    RLGL_Begin(RL_LINES);
    // Three lines, six points
    // Define color for next vertex
    RLGL_Color4ub(255, 0, 0, 255);
    // Define vertex
    RLGL_Vertex2f(trianglePositions[0].x, trianglePositions[0].y);
    RLGL_Color4ub(0, 255, 0, 255);
    RLGL_Vertex2f(trianglePositions[1].x, trianglePositions[1].y);

    RLGL_Color4ub(0, 255, 0, 255);
    RLGL_Vertex2f(trianglePositions[1].x, trianglePositions[1].y);
    RLGL_Color4ub(0, 0, 255, 255);
    RLGL_Vertex2f(trianglePositions[2].x, trianglePositions[2].y);

    RLGL_Color4ub(0, 0, 255, 255);
    RLGL_Vertex2f(trianglePositions[2].x, trianglePositions[2].y);
    RLGL_Color4ub(255, 0, 0, 255);
    RLGL_Vertex2f(trianglePositions[0].x, trianglePositions[0].y);
    RLGL_End();
  } else {
    // Draw triangle as a triangle
    RLGL_Begin(RL_TRIANGLES);
    // One triangle, three points
    // Define color for next vertex
    RLGL_Color4ub(255, 0, 0, 255);
    // Define vertex
    RLGL_Vertex2f(trianglePositions[0].x, trianglePositions[0].y);
    RLGL_Color4ub(0, 255, 0, 255);
    RLGL_Vertex2f(trianglePositions[1].x, trianglePositions[1].y);
    RLGL_Color4ub(0, 0, 255, 255);
    RLGL_Vertex2f(trianglePositions[2].x, trianglePositions[2].y);
    RLGL_End();
  }

  // Render the vertex handles, reacting to mouse movement/input
  for (unsigned int i = 0; i < 3; i++) {
    // Draw handle fill focused by mouse
    if (RLIB_CheckCollisionPointCircle(RLIB_GetMousePosition(),
                                       trianglePositions[i], handleRadius))
      RLIB_DrawCircleV(trianglePositions[i], handleRadius,
                       RLIB_ColorAlpha(DARKGRAY, 0.5f));

    // Draw handle fill selected
    if (i == triangleIndex)
      RLIB_DrawCircleV(trianglePositions[i], handleRadius, DARKGRAY);

    // Draw handle outline
    RLIB_DrawCircleLinesV(trianglePositions[i], handleRadius, BLACK);
  }

  // Draw controls
  DrawText("SPACE: Toggle lines mode", 10, 10, 20, DARKGRAY);
  DrawText("LEFT-RIGHT: Toggle backface culling", 10, 40, 20, DARKGRAY);
  DrawText("MOUSE: Click and drag vertex points", 10, 70, 20, DARKGRAY);
  DrawText("R: Reset triangle to start positions", 10, 100, 20, DARKGRAY);

  RLIB_EndDrawing();
}
