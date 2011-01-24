#include <ddverify/ddverify.h>
#include "machzwd.c"

int main()
{
   _ddv_module_init = zf_init;
   _ddv_module_exit = zf_exit;
   call_ddv();

   return 0;
}
