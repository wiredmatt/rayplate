#ifndef RAYPLATE_GRAPHICS_API_H
#define RAYPLATE_GRAPHICS_API_H

typedef enum GraphicsApiConfigureResult {
    GRAPHICS_API_CONFIGURE_ERROR = -1,
    GRAPHICS_API_CONFIGURE_CONTINUE = 0,
    GRAPHICS_API_CONFIGURE_EXIT = 1
} GraphicsApiConfigureResult;

GraphicsApiConfigureResult GraphicsApiConfigure(int argc, char **argv);
const char *GraphicsApiName(void);
void GraphicsApiLogRenderer(void);

#endif
