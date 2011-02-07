#include <ddverify/tasklet.h>

void call_tasklet_functions()
{
  unsigned int i;
  __CPROVER_assume(i < MAX_TASKLET_SUPPORT);

  if ((tasklet_registered[i].tasklet != NULL) &&
      (tasklet_registered[i].tasklet->count == 0)) {
    tasklet_registered[i].is_running = 1;
    (* tasklet_registered[i].tasklet->func)(tasklet_registered[i].tasklet->data);
    tasklet_registered[i].is_running = 0;
    tasklet_registered[i].tasklet = NULL;
  }
}
