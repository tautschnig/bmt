#include <ddverify/satabs.h>
#include <ddverify/timer.h>

void call_timer_functions()
{
  unsigned short i = nondet_ushort();

  __CPROVER_assume(i < number_timer_registered);

  if (timer_registered[i].timer->__ddv_active) {
    (* timer_registered[i].timer->function)(timer_registered[i].timer->data);
  }
}
