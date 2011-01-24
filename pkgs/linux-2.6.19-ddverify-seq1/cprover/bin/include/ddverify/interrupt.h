#ifndef _DDV_INTERRUPT_H
#define _DDV_INTERRUPT_H

#include <ddverify/ddverify.h>
#include <linux/interrupt.h>

#define MAX_IRQ_SUPPORT 16

struct registered_irq {
  irq_handler_t handler;
  void *dev_id;
};

struct registered_irq registered_irq[MAX_IRQ_SUPPORT];

void call_interrupt_handler();

#endif

