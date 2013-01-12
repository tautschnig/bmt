#include <linux/mod_devicetable.h>
#include <linux/pci.h>
#include <ddverify/satabs.h>
#include <ddverify/ddverify.h>
#include <ddverify/pci.h>

void create_pci_dev()
{
}

int pci_probe_device()
{
    int err;
    unsigned int dev_id;

    registered_pci_driver.no_pci_device_id = 1;

    dev_id = nondet_uint();
    __CPROVER_assume(dev_id < registered_pci_driver.no_pci_device_id);
    
    err = (*registered_pci_driver.pci_driver->probe)(&registered_pci_driver.pci_dev,
						     &registered_pci_driver.pci_driver->id_table[dev_id]);

    if (!err) {
	registered_pci_driver.dev_initialized = 1;
    }

    return err;
}

void pci_remove_device()
{
    (*registered_pci_driver.pci_driver->remove)(&registered_pci_driver.pci_dev);

    registered_pci_driver.dev_initialized = 0;
}

void call_pci_functions()
{
    switch (nondet_uint()) {
	case 0:
	    if (!registered_pci_driver.dev_initialized) {
		pci_probe_device();
	    }	    
	    break;

	case 1:
	    if (registered_pci_driver.dev_initialized) {
		pci_remove_device();
	    }
	    break;

	default:
	    break;
    }
}
