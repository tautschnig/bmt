#include <linux/blkdev.h>
#include <linux/hdreg.h>
#include <linux/spinlock.h>
#include <ddverify/satabs.h>
#include <ddverify/genhd.h>

create_request(int genhd_no)
{
    struct request rq;
    
    rq.cmd_type = REQ_TYPE_FS;
    rq.rq_disk = genhd_registered[genhd_no].gd;
    rq.sector = nondet_sector_t();
    rq.current_nr_sectors = nondet_uint();
    rq.buffer = nondet_pchar();

    genhd_registered[genhd_no].current_request = rq;
    genhd_registered[genhd_no].requests_open   = 1;
}

void call_rq_function(int genhd_no)
{
    if ((genhd_registered[genhd_no].gd->queue->request_fn != NULL) &&
	(genhd_registered[genhd_no].gd->queue->__ddv_queue_alive))
    {
	spin_lock(genhd_registered[genhd_no].gd->queue->queue_lock);

	create_request(genhd_no);
	genhd_registered[genhd_no].gd->queue->__ddv_genhd_no = genhd_no;

	(* genhd_registered[genhd_no].gd->queue->request_fn)(genhd_registered[genhd_no].gd->queue);
	//	do_cm206_request(genhd_registered[genhd_no].gd->queue);

	spin_unlock(genhd_registered[genhd_no].gd->queue->queue_lock);
	
	return;
    }
    
    if (genhd_registered[genhd_no].gd->queue->make_request_fn) {
	return;
    }
}

void call_genhd_functions() 
{
    unsigned short genhd_no, function_no;
    unsigned int uint_value;
    unsigned long ulong_value;
    int result;
    
    if (number_genhd_registered == 0) {
	return;
    }
    
    genhd_no = nondet_ushort();
    __CPROVER_assume (genhd_no < number_genhd_registered);
    

    function_no = nondet_ushort();

    switch (function_no) {
	case 0:
	    call_rq_function(genhd_no);
	    break;

	case 1:    
	    if (genhd_registered[genhd_no].gd->fops->open) {
		genhd_registered[genhd_no].inode.i_bdev = (struct block_device*)malloc(sizeof(struct block_device));
		genhd_registered[genhd_no].inode.i_bdev->bd_disk = genhd_registered[genhd_no].gd;
		
		(* genhd_registered[genhd_no].gd->fops->open)(&genhd_registered[genhd_no].inode, 
							      &genhd_registered[genhd_no].file);		
	    }
	    break;

	case 2:
	    if (genhd_registered[genhd_no].gd->fops->release) {
		(* genhd_registered[genhd_no].gd->fops->release)(&genhd_registered[genhd_no].inode, 
								 &genhd_registered[genhd_no].file);
	    }
	    break;

	case 3:
	    if (genhd_registered[genhd_no].gd->fops->ioctl) {
		uint_value = nondet_uint();
		ulong_value = nondet_ulong();
		(* genhd_registered[genhd_no].gd->fops->ioctl)(&genhd_registered[genhd_no].inode, 
							       &genhd_registered[genhd_no].file,
							       uint_value,
							       ulong_value);		
	    }    
	    break;

	case 4:
	    if (genhd_registered[genhd_no].gd->fops->media_changed) {
		(* genhd_registered[genhd_no].gd->fops->media_changed)(genhd_registered[genhd_no].gd);	
	    }    
	    break;
	    
	case 5:
	    if (genhd_registered[genhd_no].gd->fops->revalidate_disk) {
		(* genhd_registered[genhd_no].gd->fops->revalidate_disk)(genhd_registered[genhd_no].gd);
	    }   
	    break;
	    
	case 6:
	    if (genhd_registered[genhd_no].gd->fops->getgeo) {
		struct hd_geometry hdg;
		struct block_device blk_dev;
		
		blk_dev.bd_disk = genhd_registered[genhd_no].gd;
		
		(* genhd_registered[genhd_no].gd->fops->getgeo)(&blk_dev, &hdg);
	    }
	    break;
	    
	default:
	    break;
    }
}
