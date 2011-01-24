#ifndef _DDV_IOPORT_H
#define _DDV_IOPORT_H

#include <ddverify/ddverify.h>

//#define NUMBER_IO_PORTS 65536

//ushort ddv_ioport[NUMBER_IO_PORTS - 1];

int ddv_ioport_request_start;
int ddv_ioport_request_len;

#ifdef DDV_ASSERT_IO

//   __CPROVER_assert(ddv_ioport[port], "Used I/O Port was requested")

#define ddv_correct_port_use(port)                                                    \
__CPROVER_assert(port >= ddv_ioport_request_start && port < ddv_ioport_request_start + ddv_ioport_request_len, "I/O port is requested")

#else 

#define ddv_correct_port_use(port) \
    do { } while(0)

#endif   /* DDV_ASSERT_IO */

#endif
