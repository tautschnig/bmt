/*****************************************************************************

Copyright (C) 2001-2008, Daniel Kroening, ETH Zurich,

All rights reserved. Redistribution and use in source and binary forms, with
or without modification, are permitted provided that the following
conditions are met:

  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.

  3. All advertising materials mentioning features or use of this software
     must display the following acknowledgement:

     This product includes software developed by Daniel Kroening,
     ETH Zurich and Edmund Clarke, Computer Science Department,
     Carnegie Mellon University.

  4. Neither the name of the University nor the names of its contributors
     may be used to endorse or promote products derived from this software
     without specific prior written permission.

  5. We must be notified by email at kroening@cs.cmu.edu after you install
     the program for any purpose.

   
THIS SOFTWARE IS PROVIDED BY THE UNIVERSITIES AND CONTRIBUTORS `AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.
******************************************************************************/


#ifndef _DDVERIFY_H_
#define _DDVERIFY_H_

#define NR_FILE_SUPPORT 10
#define NR_MACRO_SUPPORT 20
#define STR_LENGTH 250
#define DEFAULT_CC_FILE "__main.c"
#define DEFAULT_SATABS_SCRIPT "ddv_satabs"
#define DEFAULT_CBMC_SCRIPT "ddv_cbmc"
#define DEFAULT_COMPILE_SCRIPT "compile"
#define UNWINDSET_PARAM " --unwindset "

#define DRIVER_TYPE_CHAR  1
#define DRIVER_TYPE_BLOCK 2
#define DRIVER_TYPE_NET   3

#define MODEL_TYPE_SEQUENTIAL1 1
#define MODEL_TYPE_CONCURRENT1 2
#define MODEL_TYPE_CONCURRENT2 3

#define MAX_NUMBER_CLAIMS 5000

typedef char string[STR_LENGTH];

typedef enum { SATABS, CBMC } tool_choice;

string src_path = "models/seq1/src/";
string include_path = "models/seq1/include";
const char ddv_files[][STR_LENGTH] = {"ddverify/ddverify.c",
                                      "ddverify/cdev.c",
                                      "ddverify/genhd.c",
                                      "ddverify/interrupt.c",
                                      "ddverify/ioctl.c",
                                      "ddverify/pci.c",
                                      "ddverify/tasklet.c",
                                      "ddverify/timer.c",
                                      "linux/pci.c",
				      "linux/arch/i386/lib/usercopy.c",
                                      "linux/block/genhd.c",
                                      "linux/block/ll_rw_blk.c",
                                      "linux/drivers/char/misc.c",
                                      "linux/drivers/char/tty_io.c",
                                      "linux/fs/char_dev.c",
				      "linux/kernel/mutex.c",
                                      "linux/kernel/resource.c",
                                      "linux/kernel/sched.c",
                                      "linux/kernel/semaphore.c",
                                      "linux/kernel/softirq.c",
                                      "linux/kernel/spinlock.c",
                                      "linux/kernel/timer.c",
	                              "linux/kernel/wait.c",
                                      "linux/kernel/workqueue.c",
                                      "linux/kernel/irq/manage.c",
				      "linux/mm/page_alloc.c",
                                      "linux/mm/slab.c",
                                      "linux/mm/vmalloc.c"};

const int nr_ddv_files = 28;

string   modelchecker = "";
string   number_iterations = "20";
char    *unwindset = NULL;
unsigned unwindset_str_size = STR_LENGTH;
char    *unwind = NULL;

string   output_cc_file = "";
string   output_tool_file = "";
string   output_compile_file = "";
string   file[NR_FILE_SUPPORT];
string   macro[NR_MACRO_SUPPORT];
string   ddv_path = "";
string   module_init = "";
string   module_exit = "";

int      driver_type = 0;
int      driver_type_pci = 0;
int      nr_file_registered = 0;
int      nr_macro_registered = 0;
int      prepare_only = 0;

int      model_type = MODEL_TYPE_SEQUENTIAL1;
int      word_width = 32;

int      check_bounds = 0;
int      check_pointer = 0;
int      check_div_by_zero = 0;
int      check_spinlock = 0;
int      check_semaphore = 0;
int      check_mutex = 0;
int      check_io = 0;
int      check_wait_queue = 0;
int      check_tasklet = 0;
int      check_work_queue = 0;
int      check_timer = 0;
int      check_context = 0;
tool_choice tool = SATABS;
int      cbmc_slicing = 1;

struct claim {
    char *claim_id;
    char *file;
    unsigned int line;
    char *text;
    char *claim;
    float time;
};

struct claim claim[MAX_NUMBER_CLAIMS];
int number_claims;

#endif
