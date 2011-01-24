#ifndef _SATABS_H
#define _SATABS_H

#include <ddverify/ddverify.h>
#include <linux/types.h>
#include <ddverify/pthread.h>

// memory management

void *malloc(size_t size);


// nondeterministic functions

short nondet_short();
unsigned short nondet_ushort();
int nondet_int();
unsigned int nondet_uint();
long nondet_long();
unsigned long nondet_ulong();
char nondet_char();
unsigned char nondet_uchar();
unsigned nondet_unsigned();
loff_t nondet_loff_t();
size_t nondet_size_t();
sector_t nondet_sector_t();
u32 nondet_u32();
char * nondet_pchar();
enum __bool nondet_bool();


// handling asm code

void noop();
#define asm(code, ...) noop()


// __CPROVER functions

void __CPROVER_atomic_begin();
void __CPROVER_atomic_end();

/*
// pthread
struct __pthread_t_struct
{
    int id;
};

struct __pthread_attr_t_struct
{
  int dummy;
};

typedef struct __pthread_t_struct pthread_t;
typedef struct __pthread_attr_t_struct pthread_attr_t;

pthread_t nondet_pthread_t();

extern inline int pthread_create(pthread_t *__threadp,
				 __const pthread_attr_t *__attr,
				 void *(*__start_routine) (void *),
				 void *__arg)
{
  __CPROVER_HIDE:
  *__threadp = nondet_pthread_t();
  CPROVER_ASYNC_1: __start_routine(__arg);
  return 0;
}
*/
#endif
