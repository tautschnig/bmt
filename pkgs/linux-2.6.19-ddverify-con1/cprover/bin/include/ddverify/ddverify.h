#ifndef _DDVERIFY_H
#define _DDVERIFY_H

enum __bool { false, true };

#ifndef NULL
#define NULL ((void *)0)
#endif


int current_execution_context;

#define CONTEXT_PROCESS     1
#define CONTEXT_INTERRUPT   2

#define switch_context(x) current_execution_context = x

#ifdef DDV_ASSERT_CONTEXT

static inline assert_context_process()
{
    __CPROVER_assert(current_execution_context == CONTEXT_PROCESS, "Process context");
}

static inline assert_context_interrupt()
{
    __CPROVER_assert(current_execution_context == CONTEXT_INTERRUPT, "Interrupt context");
}

#else

static inline assert_context_process()
{
}

static inline assert_context_interrupt()
{
}

#endif            /* DDV_ASSERT_CONTEXT */

int (* _ddv_module_init)(void);
void (* _ddv_module_exit)(void);

int call_ddv();

#endif
