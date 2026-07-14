# Khronos OpenGL ES headers

These platform-independent headers let raylib compile its OpenGL ES 3 rlgl
backend on desktop systems that do not ship GLES development headers.

- `GLES3/gl3.h`, `GLES3/gl3platform.h`, and `GLES2/gl2ext.h` come from
  KhronosGroup/OpenGL-Registry commit
  `9d527dbc81bb76e35ba284fe385ed8a5ddb90cbc`.
- `KHR/khrplatform.h` comes from KhronosGroup/EGL-Registry commit
  `3d7796b3721d93976b6bfe536aa97bbc4bce8667`.

Each file retains its upstream license notice. `gl3.h`, `gl2ext.h`, and
`khrplatform.h` use the MIT license; `gl3platform.h` uses Apache-2.0.
