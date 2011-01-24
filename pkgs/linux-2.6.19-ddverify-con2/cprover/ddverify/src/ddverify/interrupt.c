#include <ddverify/satabs.h>
#include <ddverify/interrupt.h>

#ifdef OLD_INTERRUPT_HANDLER
#define __call_interrupt_handler(funct, irq, dev_id, regs) funct(irq, dev_id)
#else
#define __call_interrupt_handler(funct, irq, dev_id, regs) funct(irq, dev_id, regs)
#endif

void call_interrupt_handler()
{
    unsigned short i;
    struct pt_regs regs;

    i = nondet_int();
    __CPROVER_assume(i < MAX_IRQ_SUPPORT);

    if (registered_irq[i].handler) {
      __call_interrupt_handler((* registered_irq[i].handler),
			       (int)i, registered_irq[i].dev_id, &regs);
    }
}
