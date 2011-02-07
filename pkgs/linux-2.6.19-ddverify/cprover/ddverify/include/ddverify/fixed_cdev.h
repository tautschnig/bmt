#ifndef _DDV_FIXED_CDEV_H_
#define _DDV_FIXED_CDEV_H_

#include <ddverify/cdev.h>
#include <linux/fs.h>
#include <linux/cdev.h>

// Used in function misc_register and cdev_alloc. Instead allocating a cdev structure,
// a cdev structure from this array is used. This make the verification process much 
// simpler.

struct cdev fixed_cdev[MAX_CDEV_SUPPORT];
int fixed_cdev_used = 0;

#endif
