/*******************************************************************************************
 *
 *   raylib [core] example - Basic window
 *
 *   Welcome to raylib!
 *
 *   To test examples, just press F6 and execute 'raylib_compile_execute' script
 *   Note that compiled executable is placed in the same folder as .c file
 *
 *   To test the examples on Web, press F6 and execute 'raylib_compile_execute_web' script
 *   Web version of the program is generated in the same folder as .c file
 *
 *   You can find all basic examples on C:\raylib\raylib\examples folder or
 *   raylib official webpage: www.raylib.com
 *
 *   Enjoy using raylib. :)
 *
 *   Example originally created with raylib 1.0, last time updated with raylib 1.0
 *
 *   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
 *   BSD-like license that allows static linking with closed source software
 *
 *   Copyright (c) 2013-2024 Ramon Santamaria (@raysan5)
 *
 ********************************************************************************************/
#include <rl_alias.h>

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
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
        // clang-format off

        rlBeginDrawing();

            rlClearBackground(RAYWHITE);

            rlDrawText("Congrats! You created your first window!", 190, 200, 20, LIGHTGRAY);

        rlEndDrawing();

        // clang-format on
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rlCloseWindow(); // Close window and OpenGL context
    //--------------------------------------------------------------------------------------

    return 0;
}