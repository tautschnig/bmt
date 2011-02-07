#ifndef _DDV_TASKLET_H_
#define _DDV_TASKLET_H_

#include <linux/interrupt.h>

#ifdef MODEL_TYPE_SEQUENTIAL1
#define MAX_TASKLET_SUPPORT 1
#else
#define MAX_TASKLET_SUPPORT 10
#endif

short number_tasklet_registered = 0;

struct ddv_tasklet {
  struct tasklet_struct *tasklet;
  unsigned short is_running;
};

struct ddv_tasklet tasklet_registered[MAX_TASKLET_SUPPORT];

void call_tasklet_functions();

#endif

