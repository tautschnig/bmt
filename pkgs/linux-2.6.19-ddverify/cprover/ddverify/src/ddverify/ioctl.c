#include <ddverify/satabs.h>
#include <ddverify/ioctl.h>

/*void add_ioctl(unsigned int ioctl)
{
    if (number_ioctl_registered < MAX_IOCTL_SUPPORT) {
	ioctl_registered[number_ioctl_registered] = ioctl;
	number_ioctl_registered++;
    }
}

unsigned int get_ioctl_cmd()
{
    short cmd = nondet_short();
    __CPROVER_assume (cmd >= 0 && cmd < number_ioctl_registered);

    return ioctl_registered[cmd];
}
*/
