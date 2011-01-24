#include <ddverify/ddverify.h>
#include <ddverify/satabs.h>
#include <ddverify/pthread.h>
#include <ddverify/cdev.h>
#include <ddverify/genhd.h>
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
		switch_context(CONTEXT_INTERRUPT);
		call_timer_functions();
		switch_context(CONTEXT_PROCESS);
		break;
		
	    case 2:
		switch_context(CONTEXT_INTERRUPT);
		call_interrupt_handler();
		switch_context(CONTEXT_PROCESS);
		break;
		
	    case 3:
		switch_context(CONTEXT_PROCESS);
		call_shared_workqueue_functions();
		switch_context(CONTEXT_PROCESS);
		break;
		
	    case 4:
		switch_context(CONTEXT_INTERRUPT);
		call_tasklet_functions();
		switch_context(CONTEXT_PROCESS);
		break;
		
	    case 5:
		switch_context(CONTEXT_PROCESS);
		call_pci_functions();
		switch_context(CONTEXT_PROCESS);
		break;
		
	    default:
		break;
	} 
    } while(random);
}

void ddv()
{
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
