#ifndef ANGLE_CFG_H
#define ANGLE_CFG_H

typedef enum ANGLE_ConfigureResult {
  ANGLE_CONFIGURE_ERROR = -1,
  ANGLE_CONFIGURE_CONTINUE = 0,
  ANGLE_CONFIGURE_EXIT = 1
} ANGLE_ConfigureResult;

ANGLE_ConfigureResult ANGLE_Configure(int argc, char **argv);
const char *ANGLE_ApiName(void);
void ANGLE_LogRenderer(void);

#endif
