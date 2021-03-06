#ifndef _DDV_CDEV_H
#define _DDV_CDEV_H

#include <linux/fs.h>
#include <linux/cdev.h>

#ifdef MODEL_TYPE_SEQUENTIAL1
#define MAX_CDEV_SUPPORT 1
#else
#define MAX_CDEV_SUPPORT 10
#endif

#include <ddverify/fixed_cdev.h>

short number_cdev_registered = 0;

struct ddv_cdev {
    struct cdev *cdevp;

    struct file filp;
    struct inode inode;

    int open;
};

struct ddv_cdev cdev_registered[MAX_CDEV_SUPPORT];

void call_cdev_functions();

#endif
