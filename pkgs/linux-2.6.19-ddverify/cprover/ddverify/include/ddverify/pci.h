#ifndef _DDV_PCI_H_
#define _DDV_PCI_H_

#include <linux/pci.h>

struct ddv_pci_driver {
    struct pci_driver     *pci_driver;
    struct pci_dev        pci_dev;

    unsigned int          no_pci_device_id;
    int                   dev_initialized;
};

struct ddv_pci_driver registered_pci_driver;

int pci_probe_device();
void pci_remove_device();

void call_pci_functions();


#endif
