#ifndef __POSIX_PTHREAD_H
#define __POSIX_PTHREAD_H

#include <linux/types.h>

#ifdef  __cplusplus
extern "C" {
#endif

#ifndef NULL
#define NULL ((void *)0)
#endif

/* Types */
struct __pthread_t_struct
{
  int id;
};

struct __pthread_attr_t_struct
{
  int dummy;
};

struct __pthread_mutex_t_struct
{
  _Bool locked;
};

struct __pthread_mutexattr_t_struct
{
  int dummy;
};

struct __pthread_spinlock_t_struct
{
  int dummy;
};

struct __pthread_barrier_t_struct
{
  int dummy;
};

struct __pthread_barrierattr_t_struct
{
  int dummy;
};

typedef struct __pthread_t_struct pthread_t;
typedef struct __pthread_attr_t_struct pthread_attr_t;
typedef struct __pthread_mutex_t_struct pthread_mutex_t;
typedef struct __pthread_mutexattr_t_struct pthread_mutexattr_t;
typedef struct __pthread_spinlock_t_struct pthread_spinlock_t;
typedef struct __pthread_barrier_t_struct pthread_barrier_t;
typedef struct __pthread_barrierattr_t_struct pthread_barrierattr_t;

/* Initializers */

#define PTHREAD_MUTEX_INITIALIZER {0}

/* Attributes */

enum
{
  PTHREAD_CREATE_JOINABLE,
#define PTHREAD_CREATE_JOINABLE	PTHREAD_CREATE_JOINABLE
  PTHREAD_CREATE_DETACHED
#define PTHREAD_CREATE_DETACHED	PTHREAD_CREATE_DETACHED
};

enum
{
  PTHREAD_INHERIT_SCHED,
#define PTHREAD_INHERIT_SCHED	PTHREAD_INHERIT_SCHED
  PTHREAD_EXPLICIT_SCHED
#define PTHREAD_EXPLICIT_SCHED	PTHREAD_EXPLICIT_SCHED
};

enum
{
  PTHREAD_SCOPE_SYSTEM,
#define PTHREAD_SCOPE_SYSTEM	PTHREAD_SCOPE_SYSTEM
  PTHREAD_SCOPE_PROCESS
#define PTHREAD_SCOPE_PROCESS	PTHREAD_SCOPE_PROCESS
};

enum
{
  PTHREAD_MUTEX_TIMED_NP,
  PTHREAD_MUTEX_RECURSIVE_NP,
  PTHREAD_MUTEX_ERRORCHECK_NP,
  PTHREAD_MUTEX_ADAPTIVE_NP,
  PTHREAD_MUTEX_NORMAL = PTHREAD_MUTEX_TIMED_NP,
  PTHREAD_MUTEX_RECURSIVE = PTHREAD_MUTEX_RECURSIVE_NP,
  PTHREAD_MUTEX_ERRORCHECK = PTHREAD_MUTEX_ERRORCHECK_NP,
  PTHREAD_MUTEX_DEFAULT = PTHREAD_MUTEX_NORMAL
};

enum
{
  PTHREAD_PROCESS_PRIVATE,
#define PTHREAD_PROCESS_PRIVATE	PTHREAD_PROCESS_PRIVATE
  PTHREAD_PROCESS_SHARED
#define PTHREAD_PROCESS_SHARED	PTHREAD_PROCESS_SHARED
};

enum
{
  PTHREAD_RWLOCK_PREFER_READER_NP,
  PTHREAD_RWLOCK_PREFER_WRITER_NP,
  PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP,
  PTHREAD_RWLOCK_DEFAULT_NP = PTHREAD_RWLOCK_PREFER_WRITER_NP
};

#define PTHREAD_ONCE_INIT 0

/* -1 is distinct from 0 and all errno constants */
#define PTHREAD_BARRIER_SERIAL_THREAD -1

enum
{
  PTHREAD_CANCEL_ENABLE,
#define PTHREAD_CANCEL_ENABLE	PTHREAD_CANCEL_ENABLE
  PTHREAD_CANCEL_DISABLE
#define PTHREAD_CANCEL_DISABLE	PTHREAD_CANCEL_DISABLE
};
enum
{
  PTHREAD_CANCEL_DEFERRED,
#define PTHREAD_CANCEL_DEFERRED	PTHREAD_CANCEL_DEFERRED
  PTHREAD_CANCEL_ASYNCHRONOUS
#define PTHREAD_CANCEL_ASYNCHRONOUS	PTHREAD_CANCEL_ASYNCHRONOUS
};
#define PTHREAD_CANCELED ((void *) -1)

pthread_t nondet_pthread_t();

extern inline int pthread_create(
  pthread_t *__threadp,
  __const pthread_attr_t *__attr,
  void *(*__start_routine) (void *),
  void *__arg);

extern pthread_t pthread_self(void);
extern int pthread_equal(pthread_t __thread1, pthread_t __thread2);
extern void pthread_exit(void *__retval);
extern int pthread_join(pthread_t __th, void **__thread_return);
extern int pthread_detach(pthread_t __th);
extern int pthread_attr_init(pthread_attr_t *__attr);
extern int pthread_attr_destroy(pthread_attr_t *__attr);
extern int pthread_attr_setdetachstate(pthread_attr_t *__attr, int __detachstate);
extern int pthread_attr_getdetachstate(__const pthread_attr_t *__attr, int *__detachstate);
extern int pthread_attr_setschedparam(pthread_attr_t *__attr, __const struct sched_param *__param);
extern int pthread_attr_getschedparam(__const pthread_attr_t *__attr, struct sched_param *__param);
extern int pthread_attr_setschedpolicy(pthread_attr_t *__attr, int __policy);
extern int pthread_attr_getschedpolicy(__const pthread_attr_t *__attr, int *__policy);
extern int pthread_attr_setinheritsched(pthread_attr_t *__attr, int __inherit);
extern int pthread_attr_getinheritsched(__const pthread_attr_t *__attr, int *__inherit);
extern int pthread_attr_setscope(pthread_attr_t *__attr, int __scope);
extern int pthread_attr_getscope(__const pthread_attr_t *__attr, int *__scope);
extern int pthread_attr_setguardsize(pthread_attr_t *__attr, size_t __guardsize);
extern int pthread_attr_getguardsize(__const pthread_attr_t *__attr, size_t *__guardsize);
extern int pthread_attr_setstackaddr(pthread_attr_t *__attr, void *__stackaddr);
extern int pthread_attr_getstackaddr(__const pthread_attr_t *__attr, void **__stackaddr);
extern int pthread_attr_setstack(pthread_attr_t *__attr, void *__stackaddr, size_t __stacksize);
extern int pthread_attr_getstack(__const pthread_attr_t *__attr,
				 void **__stackaddr,
				 size_t *__stacksize);
extern int pthread_attr_setstacksize(pthread_attr_t *__attr, size_t __stacksize);
extern int pthread_attr_getstacksize(__const pthread_attr_t *, size_t *__stacksize);

extern int pthread_getattr_np(pthread_t __th, pthread_attr_t *__attr);

extern int pthread_setschedparam(pthread_t __target_thread, int __policy,
				 __const struct sched_param *__param);

extern int pthread_getschedparam(pthread_t __target_thread,
				 int *__policy,
				 struct sched_param *__param);

extern int pthread_getconcurrency(void);
extern int pthread_setconcurrency(int __level);
extern int pthread_yield(void);

extern inline int pthread_mutex_init(
  pthread_mutex_t *__mutex,
  __const pthread_mutexattr_t *__mutex_attr)
{
  pthread_mutex_t i=PTHREAD_MUTEX_INITIALIZER;
  *__mutex=i;
}

extern inline int pthread_mutex_destroy(pthread_mutex_t *__mutex)
{
}

extern int pthread_mutex_trylock(pthread_mutex_t *__mutex);

void __CPROVER_atomic_begin();
void __CPROVER_atomic_end();

extern inline int pthread_mutex_lock(pthread_mutex_t *__mutex)
{
  __CPROVER_HIDE:
  __CPROVER_atomic_begin();
  __CPROVER_assume(!__mutex->locked);
  __mutex->locked=1;
  __CPROVER_atomic_end();
  return 0; // we never fail
}

extern inline int pthread_mutex_unlock(pthread_mutex_t *__mutex)
{
  __CPROVER_HIDE:
  __CPROVER_assert(__mutex->locked, "pthread_mutex_unlock without lock");
  __mutex->locked=0;
  return 0; // we never fail
}

extern int pthread_spin_init(pthread_spinlock_t *__lock, int __pshared);
extern int pthread_spin_destroy(pthread_spinlock_t *__lock);
extern int pthread_spin_lock(pthread_spinlock_t *__lock);
extern int pthread_spin_trylock(pthread_spinlock_t *__lock);
extern int pthread_spin_unlock(pthread_spinlock_t *__lock);
extern int pthread_barrier_init(pthread_barrier_t *__barrier,
                                __const pthread_barrierattr_t *__attr, unsigned int __count);

extern int pthread_barrier_destroy(pthread_barrier_t *__barrier);
extern int pthread_barrierattr_init(pthread_barrierattr_t *__attr);
extern int pthread_barrierattr_destroy(pthread_barrierattr_t *__attr);
extern int pthread_barrierattr_getpshared(__const pthread_barrierattr_t *__attr,
					  int *__pshared);

extern int pthread_barrierattr_setpshared(pthread_barrierattr_t *__attr, int __pshared);
extern int pthread_barrier_wait(pthread_barrier_t *__barrier);

extern int pthread_setcancelstate(int __state, int *__oldstate);
extern int pthread_setcanceltype(int __type, int *__oldtype);
extern int pthread_cancel(pthread_t __cancelthread);
extern void pthread_testcancel(void);

extern int pthread_atfork(void (*__prepare)(void),
			  void (*__parent)(void),
			  void (*__child)(void));

extern void pthread_kill_other_threads_np(void);

#ifdef  __cplusplus
}
#endif

#endif
