#ifndef _DDV_WORKQUEUE_H_
#define _DDV_WORKQUEUE_H_

#include <linux/workqueue.h>

#define MAX_WORKQUEUE_ELEMENTS_SUPPORT 10

struct work_struct *shared_workqueue[MAX_WORKQUEUE_ELEMENTS_SUPPORT];

void call_shared_workqueue_functions();

#endif
