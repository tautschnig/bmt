#include <ddverify/satabs.h>
#include <ddverify/cdev.h>
#include <ddverify/ioctl.h>

void call_cdev_functions() 
{
    int cdev_no, function_no, result;
    
    loff_t loff_t_value;
    int int_value;
    unsigned int uint_value;
    unsigned long ulong_value;
    char char_value;
    size_t size_t_value;

    if (number_cdev_registered == 0) {
	return;
    }

    cdev_no = nondet_ushort();
    __CPROVER_assume (0 <= cdev_no && cdev_no < number_cdev_registered);

    switch (nondet_ushort()) {
	case 0:
	    if (cdev_registered[cdev_no].cdevp->ops->llseek) {
		loff_t_value = nondet_loff_t();
		int_value = nondet_int();
		
		(* cdev_registered[cdev_no].cdevp->ops->llseek)(&cdev_registered[cdev_no].filp,
								loff_t_value,
								int_value);
	    }
	    break;
	case 1:
	    if (cdev_registered[cdev_no].cdevp->ops->read) {
		char_value = nondet_char();
		size_t_value = nondet_size_t();
		
		(* cdev_registered[cdev_no].cdevp->ops->read)(&cdev_registered[cdev_no].filp,
							      &char_value,
							      size_t_value,
							      &loff_t_value);
	    }
	    break;
	case 2:
	    // aio_read - NOT SUPPORTED!
	    break;
	case 3:
	    if (cdev_registered[cdev_no].cdevp->ops->write) {	
		char_value = nondet_char();
		size_t_value = nondet_size_t();
		
		(* cdev_registered[cdev_no].cdevp->ops->write)(&cdev_registered[cdev_no].filp,
							       &char_value,
							       size_t_value,
							       &loff_t_value);
	    }
	    break;
	case 4:
	    // aio_write - NOT SUPPORTED!
	    break;
	case 5:
	    // readdir - NOT SUPPORTED!
	    break;
	case 6:
	    // poll - NOT SUPPORTED!
	    break;
	case 7:
	    if (cdev_registered[cdev_no].cdevp->ops->ioctl) {
		uint_value = nondet_uint();
		ulong_value = nondet_ulong();
		
		(* cdev_registered[cdev_no].cdevp->ops->ioctl)(&cdev_registered[cdev_no].inode,
							       &cdev_registered[cdev_no].filp,
							       uint_value,
							       ulong_value);
	    }
	    
	    break;
	case 8:
	    // unlocked_ioctl - NOT SUPPORTED!
	    break;
	case 9:
	    // compat_ioctl - NOT SUPPORTED!
	    break;
	case 10:
	    // mmap - NOT SUPPORTED!
	    break;
	case 11:
	    if ((cdev_registered[cdev_no].cdevp->ops->open) &&
		(!cdev_registered[cdev_no].open)) {
		result = (* cdev_registered[cdev_no].cdevp->ops->open)(&cdev_registered[cdev_no].inode, 
								       &cdev_registered[cdev_no].filp);

		if (!result) {
		    cdev_registered[cdev_no].open = 1;
		}		
	    }
	    break;
	case 12:
	    // flush - NOT SUPPORTED!
	    break;
	case 13:
	    if ((cdev_registered[cdev_no].cdevp->ops->release) &&
	        (cdev_registered[cdev_no].open)) {
		result = (* cdev_registered[cdev_no].cdevp->ops->release)(&cdev_registered[cdev_no].inode,
									  &cdev_registered[cdev_no].filp);		

		if (!result) {
		    cdev_registered[cdev_no].open = 0;
		}
	    }
	    break;
	case 14:
	    // fsync - NOT SUPPORTED!
	    break;
	case 15:
	    // aio_fsync - NOT SUPPORTED!
	    break;
	case 16:
	    // fasync - NOT SUPPORTED!
	    break;
	case 17:
	    // lock - NOT SUPPORTED!
	    break;
	case 18:
	    // readv - NOT SUPPORTED!
	    break;
	case 19:
	    // writev - NOT SUPPORTED!
	    break;
	case 20:
	    // sendfile - NOT SUPPORTED!
	    break;
	case 21:
	    // sendpage - NOT SUPPORTED!
	    break;
	case 22:
	    // get_unmapped_area - NOT SUPPORTED!
	    break;
	case 23:
	    // check_flags - NOT SUPPORTED!
	    break;
	case 24:
	    // dir_notify - NOT SUPPORTED!
	    break;
	case 25:
	    // flock - NOT SUPPORTED!
	    break;
	case 26:
	    // open_exec - NOT SUPPORTED!
	    break;
	default:
	    break;
    }
}
