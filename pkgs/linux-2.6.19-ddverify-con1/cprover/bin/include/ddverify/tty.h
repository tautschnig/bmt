#ifndef _DDV_TTY_H_
#define _DDV_TTY_H_

#include <ddverify/ddverify.h>
#include <linux/tty.h>

struct ddv_tty_driver {
  struct tty_driver   driver;
  unsigned short      allocated;
  unsigned short      registered;
};

struct ddv_tty_driver global_tty_driver;

#endif

