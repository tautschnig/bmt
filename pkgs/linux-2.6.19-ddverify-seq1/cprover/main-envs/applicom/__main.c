#include <ddverify/ddverify.h>
#include "applicom.c"

int main()
{
   _ddv_module_init = applicom_init;
   _ddv_module_exit = applicom_exit;
   call_ddv();

   return 0;
}
