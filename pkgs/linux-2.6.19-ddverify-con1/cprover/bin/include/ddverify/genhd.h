#ifndef _DDV_GENHD_H
#define _DDV_GENHD_H

#include <linux/blkdev.h>
#include <linux/fs.h>
#include <linux/genhd.h>

#include <ddverify/ddverify.h>

#define MAX_GENHD_SUPPORT 10

short number_genhd_registered = 0;
short number_fixed_genhd_used = 0;

struct ddv_genhd {
  struct gendisk       *gd;

  struct inode         inode;
  struct file          file;
  struct request       current_request;
  int                  requests_open;
};

struct gendisk fixed_gendisk[MAX_GENHD_SUPPORT];
struct ddv_genhd genhd_registered[MAX_GENHD_SUPPORT];

void call_genhd_functions();

#endif
