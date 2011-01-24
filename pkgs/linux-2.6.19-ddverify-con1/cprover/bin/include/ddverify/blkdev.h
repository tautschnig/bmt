#ifndef _DDV_BLKDEV_H_
#define _DDV_BLKDEV_H_

#define MAX_REQUEST_QUEUE_SUPPORT 10

request_queue_t fixed_request_queue[MAX_REQUEST_QUEUE_SUPPORT];

int number_request_queue_used = 0;

#endif
