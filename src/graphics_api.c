#if !defined(_WIN32) && !defined(_POSIX_C_SOURCE)
#define _POSIX_C_SOURCE 200809L
#endif

#include "graphics_api.h"

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <raylib.h>

typedef struct GraphicsApiChoice {
    const char *argument;
    const char *displayName;
    const char *anglePlatform;
    int glfwAngleType;
} GraphicsApiChoice;

#if defined(_WIN32)
static const GraphicsApiChoice choices[] = {
    { "directx", "DirectX 11", "d3d11", GLFW_ANGLE_PLATFORM_TYPE_D3D11 },
    { "vulkan", "Vulkan", "vulkan", GLFW_ANGLE_PLATFORM_TYPE_VULKAN },
#if !defined(_M_ARM64) && !defined(__aarch64__)
    { "opengl", "OpenGL", "gl", GLFW_ANGLE_PLATFORM_TYPE_OPENGL },
#endif
};
#elif defined(__APPLE__)
static const GraphicsApiChoice choices[] = {
    { "metal", "Metal", "metal", GLFW_ANGLE_PLATFORM_TYPE_METAL },
    { "opengl", "OpenGL", "gl", GLFW_ANGLE_PLATFORM_TYPE_OPENGL }
};
#else
static const GraphicsApiChoice choices[] = {
    { "vulkan", "Vulkan", "vulkan", GLFW_ANGLE_PLATFORM_TYPE_VULKAN },
    { "opengl", "OpenGL", "gl", GLFW_ANGLE_PLATFORM_TYPE_OPENGL }
};
#endif

enum { defaultChoice = 0 };
static const GraphicsApiChoice *selectedChoice = &choices[defaultChoice];

static int StringEquals(const char *left, const char *right)
{
    return strcmp(left, right) == 0;
}

static const GraphicsApiChoice *FindChoice(const char *value)
{
    if (StringEquals(value, "dx11") || StringEquals(value, "d3d11")) value = "directx";
    else if (StringEquals(value, "vk")) value = "vulkan";
    else if (StringEquals(value, "gl")) value = "opengl";

    for (size_t index = 0; index < sizeof(choices)/sizeof(choices[0]); index++)
    {
        if (StringEquals(value, choices[index].argument)) return &choices[index];
    }
    return NULL;
}

static void PrintUsage(const char *program)
{
    fprintf(stderr, "Usage: %s [--graphics-api=<api>]\n", program);
    fprintf(stderr, "Available graphics APIs:");
    for (size_t index = 0; index < sizeof(choices)/sizeof(choices[0]); index++)
    {
        fprintf(stderr, "%s%s", (index == 0)? " " : ", ", choices[index].argument);
    }
    fprintf(stderr, "\n");
}

static int SetAnglePlatform(const char *value)
{
#if defined(_WIN32)
    return _putenv_s("ANGLE_DEFAULT_PLATFORM", value) == 0;
#else
    return setenv("ANGLE_DEFAULT_PLATFORM", value, 1) == 0;
#endif
}

#if defined(__linux__)
static int ConfigureLinuxVulkanLoader(void)
{
    const char *driverFiles = getenv("VK_DRIVER_FILES");
    const char *legacyDriverFiles = getenv("VK_ICD_FILENAMES");
    const char *selectedDrivers = getenv("VK_LOADER_DRIVERS_SELECT");
    const char *disabledDrivers = getenv("VK_LOADER_DRIVERS_DISABLE");

    // The Vulkan loader enumerates every installed ICD.  Stale system
    // SwiftShader builds can crash while ANGLE queries device properties, so
    // keep the hardware path clear unless the user explicitly selected ICDs.
    if ((driverFiles != NULL && driverFiles[0] != '\0') ||
        (legacyDriverFiles != NULL && legacyDriverFiles[0] != '\0') ||
        (selectedDrivers != NULL && selectedDrivers[0] != '\0'))
    {
        return 1;
    }
    if (disabledDrivers == NULL || disabledDrivers[0] == '\0')
    {
        return setenv("VK_LOADER_DRIVERS_DISABLE", "*swiftshader*", 1) == 0;
    }
    if (strstr(disabledDrivers, "swiftshader") != NULL) return 1;

    size_t length = strlen(disabledDrivers) + strlen(",*swiftshader*") + 1;
    char *combined = malloc(length);
    if (combined == NULL) return 0;
    int written = snprintf(combined, length, "%s,*swiftshader*", disabledDrivers);
    int result = (written > 0 && (size_t)written < length &&
                  setenv("VK_LOADER_DRIVERS_DISABLE", combined, 1) == 0);
    free(combined);
    return result;
}
#endif

GraphicsApiConfigureResult GraphicsApiConfigure(int argc, char **argv)
{
    const char *requested = NULL;
    for (int index = 1; index < argc; index++)
    {
        const char *argument = argv[index];
        if (StringEquals(argument, "--help") || StringEquals(argument, "-h"))
        {
            PrintUsage(argv[0]);
            return GRAPHICS_API_CONFIGURE_EXIT;
        }
        if (strncmp(argument, "--graphics-api=", 15) == 0)
        {
            requested = argument + 15;
        }
        else if (StringEquals(argument, "--graphics-api"))
        {
            if (index + 1 >= argc)
            {
                fprintf(stderr, "--graphics-api requires a value\n");
                PrintUsage(argv[0]);
                return GRAPHICS_API_CONFIGURE_ERROR;
            }
            requested = argv[++index];
        }
    }

    if (requested != NULL)
    {
        selectedChoice = FindChoice(requested);
        if (selectedChoice == NULL)
        {
            fprintf(stderr, "Unsupported graphics API on this platform: %s\n", requested);
            PrintUsage(argv[0]);
            return GRAPHICS_API_CONFIGURE_ERROR;
        }
    }

    if (!SetAnglePlatform(selectedChoice->anglePlatform))
    {
        fprintf(stderr, "Could not set ANGLE_DEFAULT_PLATFORM\n");
        return GRAPHICS_API_CONFIGURE_ERROR;
    }
#if defined(__linux__)
    if (StringEquals(selectedChoice->argument, "vulkan") &&
        !ConfigureLinuxVulkanLoader())
    {
        fprintf(stderr, "Could not configure the Vulkan loader\n");
        return GRAPHICS_API_CONFIGURE_ERROR;
    }
#endif
    glfwInitHint(GLFW_ANGLE_PLATFORM_TYPE, selectedChoice->glfwAngleType);
    return GRAPHICS_API_CONFIGURE_CONTINUE;
}

const char *GraphicsApiName(void)
{
    return selectedChoice->displayName;
}

void GraphicsApiLogRenderer(void)
{
    typedef const unsigned char *(*GlGetStringProc)(unsigned int name);
    const unsigned int GL_RENDERER_VALUE = 0x1F01;
    const unsigned int GL_VERSION_VALUE = 0x1F02;
    GLFWglproc glfwGetString = glfwGetProcAddress("glGetString");
    GlGetStringProc getString = NULL;
    if (sizeof(getString) == sizeof(glfwGetString))
    {
        memcpy(&getString, &glfwGetString, sizeof(getString));
    }
    if (getString != NULL)
    {
        const unsigned char *renderer = getString(GL_RENDERER_VALUE);
        const unsigned char *version = getString(GL_VERSION_VALUE);
        TraceLog(LOG_INFO, "ANGLE: Requested backend: %s", selectedChoice->displayName);
        TraceLog(LOG_INFO, "ANGLE: GL renderer: %s", (renderer != NULL)? (const char *)renderer : "unknown");
        TraceLog(LOG_INFO, "ANGLE: GL version: %s", (version != NULL)? (const char *)version : "unknown");
    }
}
