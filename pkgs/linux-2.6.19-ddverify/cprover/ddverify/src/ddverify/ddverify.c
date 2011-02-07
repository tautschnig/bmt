#include <ddverify/ddverify.h>
#include <ddverify/satabs.h>
#include <ddverify/pthread.h>
#include <ddverify/cdev.h>
#ifdef DRIVER_TYPE_BLOCK
#include <ddverify/genhd.h>
#endif
#include <ddverify/ioctl.h>
#include <ddverify/pci.h>
#include <ddverify/interrupt.h>
#include <ddverify/tasklet.h>
#include <ddverify/timer.h>
#include <ddverify/workqueue.h>
#include <linux/init.h>
#include <linux/smp_lock.h>

void init_kernel()
{
    int i;
  
    spin_lock_init(&kernel_lock);
    
    for (i = 0; i < MAX_WORKQUEUE_ELEMENTS_SUPPORT; i++) {
	shared_workqueue[i] = NULL;
    }

    for (i = 0; i < MAX_TASKLET_SUPPORT; i++) {
	tasklet_registered[i].tasklet = NULL;
	tasklet_registered[i].is_running = 0;
    }
}

static void * ddv_2(void *arg)
{
  unsigned short random;
      
    do {
	random = nondet_ushort();

	switch (random) {
	    case 1:
#ifdef MODEL_TYPE_SEQUENTIAL1
		switch_context(CONTEXT_PROCESS);
#ifdef DRIVER_TYPE_CHAR
		call_cdev_functions();
#endif
		
#ifdef DRIVER_TYPE_BLOCK
		call_genhd_functions();
#endif
#endif
		break;
		
	    case 2:
		switch_context(CONTEXT_INTERRUPT);
		call_timer_functions();
#ifndef MODEL_TYPE_SEQUENTIAL1
		switch_context(CONTEXT_PROCESS);
#endif
		break;
		
	    case 3:
		switch_context(CONTEXT_INTERRUPT);
		call_interrupt_handler();
#ifndef MODEL_TYPE_SEQUENTIAL1
		switch_context(CONTEXT_PROCESS);
#endif
		break;
		
	    case 4:
		switch_context(CONTEXT_PROCESS);
		call_shared_workqueue_functions();
#ifndef MODEL_TYPE_SEQUENTIAL1
		switch_context(CONTEXT_PROCESS);
#endif
		break;
		
	    case 5:
		switch_context(CONTEXT_INTERRUPT);
		call_tasklet_functions();
#ifndef MODEL_TYPE_SEQUENTIAL1
		switch_context(CONTEXT_PROCESS);
#endif
		break;
		
#ifdef DRIVER_TYPE_PCI
	    case 6:
		switch_context(CONTEXT_PROCESS);
		call_pci_functions();
#ifndef MODEL_TYPE_SEQUENTIAL1
		switch_context(CONTEXT_PROCESS);
#endif
		break;
#endif
		
	    default:
		break;
	} 
    } while(random);
}

void ddv()
{
#ifdef MODEL_TYPE_SEQUENTIAL1
  ddv_2(NULL);
#else
  unsigned short random;

    pthread_t thread;

    pthread_create(&thread, NULL, ddv_2, NULL);

    do {
      switch_context(CONTEXT_PROCESS);
#ifdef DRIVER_TYPE_CHAR
	call_cdev_functions();
#endif
		
#ifdef DRIVER_TYPE_BLOCK
	call_genhd_functions();
#endif
    } while (nondet_int());
#endif
}

int call_ddv()
{
    int err;

    switch_context(CONTEXT_PROCESS);

    init_kernel();

    err =  (* _ddv_module_init)();
    
    if (err) {
	return -1;
    }

    ddv();

    switch_context(CONTEXT_PROCESS);
    (* _ddv_module_exit)();  

    return 0;
}
