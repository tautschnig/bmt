#ifndef _DDV_TIMER_H_
#define _DDV_TIMER_H_

#include <linux/timer.h>

#define MAX_TIMER_SUPPORT 5

short number_timer_registered = 0;

struct ddv_timer {
  struct timer_list  *timer;
};

struct ddv_timer timer_registered[MAX_TIMER_SUPPORT];

void call_timer_functions();
#endif
