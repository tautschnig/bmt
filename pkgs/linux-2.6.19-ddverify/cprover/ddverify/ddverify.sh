#!/bin/bash
#
# Michael Tautschnig
# michael.tautschnig@comlab.ox.ac.uk
#
# Re-implementation of ddverify main code as shell script instead of C code (we
# want readability and extensibility here, no need for super-efficiency)

set -e

die() {
  echo $1
  exit 1
}
  
ifs_bak=$IFS

cleanup() {
  IFS=$ifs_bak
  if [ -z "$NO_CLEANUP" ] ; then
    for f in $TMP_FILES ; do
      if [ -f $f ] ; then
        rm $f
      fi
    done
  fi
}

trap 'cleanup' ERR EXIT

mktemp_local_prefix_suffix() {
  local varname=$1
  local prefix=$2
  local suffix=$3
  local tmpf="`mktemp --tmpdir=. $prefix.XXX`"
  TMP_FILES="$TMP_FILES $tmpf"
  local rand="`echo $tmpf | sed "s#^./$prefix\\\.##"`"
  eval $varname=\"${prefix}_$rand$suffix\"
  TMP_FILES="$TMP_FILES ${!varname}"
  [ ! -f "${!varname}" ] || die "File already exists"
  mv $tmpf ${!varname}
}

usage() {
  cat <<EOF
********************************************************************
*                                                                  *
*                          DDVerify 0.3.0                          *
*                                                                  *
********************************************************************

Usage: $SELF [OPTIONS] SOURCES ...
  where SOURCES are C files containing a Linux device driver
  $SELF extracts the init and exit routines from the first device driver file and
  compiles these to a goto binary amenable to verification using tools such as
  SATABS, CBMC, or WOLVERINE, or to CIL preprocessed source, just runs the
  preprocessor, or uses clang to compile to LLVM bytecode
   
  Options for the DDVerify front end:   Purpose:
    -h|--help                           show help
    -D macro                            define preprocessor macro
    -o file                             file name of resulting output (defaults to first SOURCE+suffix)
    --ddv-path                          set ddverify path (defaults to path to $SELF)
    --kernel-src                        set kernel source directory (defaults to current directory)
    --no-cleanup                        don't remove generated files
    --prepare-only                      stop after preparation (implies --no-cleanup)
  Checks to enable:
    --check-spinlock                    spinlock check
    --check-semaphore                   semaphore check
    --check-mutex                       mutex check
    --check-io                          I/O communication check
    --check-wait-queue                  wait queue check
    --check-tasklet                     tasklet check
    --check-work-queue                  work queue check
    --check-timer                       timer check
    --check-context                     context check
  Compiler selection:
    --goto-cc                           compile using goto-cc (creates binary)
    --cil                               compile using CIL (creates preprocessed source)
    --cil-blast                         compile using CIL (creates preprocessed source) and include ERROR labels
    --cpp                               compile using gcc -E (creates directory with preprocessed files)
    --clang                             compile using clang (creates LLVM bytecode)
  Driver description:
    --module-init <func>                set module initalization function to <func>, otherwise extracted from SOURCE
    --module-exit <func>                set module cleanup function <func>, otherwise extracted from SOURCE
    --driver-type <type>                set driver type to <type> (char, block or net), otherwise extracted from SOURCE

EOF
}

parse_file() {
  local tmp_file
  mktemp_local_prefix_suffix tmp_file ddv ""
  awk -f ${DDV_PATH}awk/parse_dd_file $MAIN_SOURCE > $tmp_file
  local ifs=$IFS
  IFS='
'
  while read line1 && read line2 ; do
    case $line1 in
      INCLUDE)
        case $line2 in
          "<linux/miscdevice.h>"|"<linux/cdev.h>") DRIVER_TYPE="char" ;;
          "<linux/blkdev.h>") DRIVER_TYPE="block" ;;
          "<linux/pci.h>") DRIVER_TYPE_PCI=1 ;;
        esac 
        ;;
      MODULE_INIT) 
        if [ -z "$MODULE_INIT" ] ; then
          MODULE_INIT=`echo $line2 | sed -e 's/module_init(//' -e 's/).*$//'`
        fi
        ;;
      MODULE_EXIT)
        if [ -z "$MODULE_EXIT" ] ; then
          MODULE_EXIT=`echo $line2 | sed -e 's/module_exit(//' -e 's/).*$//'`
        fi
        ;;
      *) die "Error while parsing main driver file (found $line1,$line2)" ;;
    esac
  done < $tmp_file
  IFS=$ifs
}

print_driver_information() {
  local pci_if="no"
  [ -z "$DRIVER_TYPE_PCI" ] || pci_if="yes"
  local more_opts="-D CONFIG_MODULES"
  for o in `echo $MORE_CONFIG_OPTS | tr ' ' '\n' | sort -u` ; do
    if ! echo "$DEFINES" | grep -q $o ; then
      more_opts="$more_opts -D $o"
    fi
  done
  cat <<EOF
Module initalization function: $MODULE_INIT
Module cleanup function: $MODULE_EXIT
Device driver type: $DRIVER_TYPE
PCI interface: $pci_if
EOF
  echo "You may want to enable additional code by re-running DDVerify with $more_opts"
}

write_cc_file() {
  cat > $OUTPUT_CC_FILE <<EOF
#include <ddverify/ddverify.h>
#include "$MAIN_SOURCE"

int main()
{
#ifndef DDV_MODULE_INIT
  _ddv_module_init = $MODULE_INIT;
#endif
#ifndef DDV_MODULE_EXIT
  _ddv_module_exit = $MODULE_EXIT;
#endif
  call_ddv();
  return 0;
}
EOF
}

get_preprocessor_string() {
  local defs=" -D__KERNEL__ -DMODULE"
  
  case $DRIVER_TYPE in
    char) defs="$defs -DDRIVER_TYPE_CHAR" ;;
    block) defs="$defs -DDRIVER_TYPE_BLOCK -DCONFIG_BLOCK" ;;
  esac
  [ -z "$DRIVER_TYPE_PCI" ] || defs="$defs -DDRIVER_TYPE_PCI -DCONFIG_PCI"
  
  for c in SPINLOCK SEMAPHORE MUTEX IO WAIT_QUEUE TASKLET WORK_QUEUE TIMER CONTEXT ; do
    c2="CHECK_$c"
    [ -z "${!c2}" ] || defs="$defs -DDDV_ASSERT_$c"
  done

  DEFINES="$DEFINES $defs"
}

write_compile_script() {
  local t_src="${DRIVER_TYPE}_SOURCES"
  local all_src="$OUTPUT_CC_FILE $OTHER_SOURCES $DDV_SOURCES ${!t_src}"
  local preproc="-I ${DDV_PATH}include/ -I ${KERNEL_SRC}include/ $DEFINES"
  cat > $OUTPUT_COMPILE_FILE <<EOF
#!/bin/bash
cleanup () {
  if [ \$link_exists -eq 0 ] ; then
    rm -f $KERNEL_SRC/include/asm
  fi
}
trap cleanup EXIT ERR
set -e
link_exists=1
if [ ! -L $KERNEL_SRC/include/asm ] ; then
  link_exists=0
  ln -snf asm-i386 $KERNEL_SRC/include/asm
  echo "Created temporary symlink $KERNEL_SRC/include/asm -> $KERNEL_SRC/include/asm-i386"
fi
EOF
  
  case "$COMPILER" in
    goto-cc)
      cat >> $OUTPUT_COMPILE_FILE <<EOF
goto-cc --32 -o $OUTPUT $preproc $all_src
EOF
      ;;
    cil) 
      cat >> $OUTPUT_COMPILE_FILE <<EOF
cpbm cillify -D__CPROVER__ \
  -DDDV_MODULE_INIT=`echo $MODULE_INIT | sed 's/&//'` \
  -DDDV_MODULE_EXIT=`echo $MODULE_EXIT | sed 's/&//'` \
  $preproc $all_src -o $OUTPUT
EOF
      ;;
    cil-blast) 
      cat >> $OUTPUT_COMPILE_FILE <<EOF
cpbm cillify --blast -D__CPROVER__ \
  -DDDV_MODULE_INIT=`echo $MODULE_INIT | sed 's/&//'` \
  -DDDV_MODULE_EXIT=`echo $MODULE_EXIT | sed 's/&//'` \
  -D_Bool=int \
  $preproc $all_src -o $OUTPUT
EOF
      ;;
    cpp)
      cat >> $OUTPUT_COMPILE_FILE <<EOF
mkdir $OUTPUT.dir
i=0
for f in $all_src ; do
  i=\$((i + 1))
  gcc -E -D__CPROVER__ $preproc \$f -o $OUTPUT/\`basename \$f .c\`\$i.i
done
EOF
      ;;
    clang)
      cat >> $OUTPUT_COMPILE_FILE <<EOF
cpbm cillify -D__CPROVER__ \
  $preproc $all_src -o `dirname $OUTPUT`/`basename $OUTPUT .s`.i
clang -emit-llvm -c -o $OUTPUT `dirname $OUTPUT`/`basename $OUTPUT .s`.i
EOF
      ;;
  esac
  
  chmod a+x $OUTPUT_COMPILE_FILE
}

SELF=$0

opts=`getopt -n "$0" -o "hD:o:" --long "\
	    help,\
	    ddv-path:,\
      kernel-src:,\
	    prepare-only,\
      no-cleanup,\
	    check-spinlock,\
	    check-semaphore,\
	    check-mutex,\
      check-io,\
	    check-wait-queue,\
	    check-tasklet,\
	    check-work-queue,\
	    check-timer,\
	    check-context,\
	    goto-cc,\
	    cil,\
	    cil-blast,\
      cpp,\
      clang,\
      module-init:,\
	    module-exit:,\
	    driver-type:,\
  " -- "$@"`
eval set -- "$opts"

unset DEFINES OUTPUT PREPARE_ONLY NO_CLEANUP
unset CHECK_SPINLOCK CHECK_SEMAPHORE CHECK_MUTEX CHECK_IO CHECK_WAIT_QUEUE
unset CHECK_TASKLET CHECK_WORK_QUEUE CHECK_TIMER CHECK_CONTEXT
unset MODULE_INIT MODULE_EXIT DRIVER_TYPE

DDV_PATH="`dirname $SELF`/"
KERNEL_SRC="./"
COMPILER=goto-cc

while true ; do
  case "$1" in
    -h|--help) usage ; exit 0;;
    -D) DEFINES="$DEFINES -D$2" ; shift 2;;
    -o) OUTPUT="$2" ; shift 2;;
	  --ddv-path) DDV_PATH="$2/" ; shift 2;;
	  --kernel-src) KERNEL_SRC="$2/" ; shift 2;;
	  --prepare-only) PREPARE_ONLY=1 ; NO_CLEANUP=1 ; shift 1;;
    --no-cleanup) NO_CLEANUP=1 ; shift 1;;
	  --check-spinlock) CHECK_SPINLOCK=1 ; shift 1;;
	  --check-semaphore) CHECK_SEMAPHORE=1 ; shift 1;;
	  --check-mutex) CHECK_MUTEX=1 ; shift 1;;
    --check-io) CHECK_IO=1 ; shift 1;;
	  --check-wait-queue) CHECK_WAIT_QUEUE=1 ; shift 1;;
	  --check-tasklet) CHECK_TASKLET=1 ; shift 1;;
	  --check-work-queue) CHECK_WORK_QUEUE=1 ; shift 1;;
	  --check-timer) CHECK_TIMER=1 ; shift 1;;
	  --check-context) CHECK_CONTEXT=1 ; shift 1;;
	  --goto-cc) COMPILER=goto-cc ; shift 1;;
	  --cil) COMPILER=cil ; shift 1;;
	  --cil-blast) COMPILER=cil-blast ; shift 1;;
	  --cpp) COMPILER=cpp ; shift 1;;
	  --clang) COMPILER=clang ; shift 1;;
    --module-init) MODULE_INIT="$2" ; shift 2;;
	  --module-exit) MODULE_EXIT="$2" ; shift 2;;
	  --driver-type)
      case $2 in
        char|block) DRIVER_TYPE=$2 ;;
        net) die "Network drivers are not supported" ;;
        *) die "Unrecognized driver type. Use char, block, or net" ;;
      esac
      shift 2;;
    --) shift ; break ;;
    *) die "Unknown option $1" ;;
  esac
done

mktemp_local_prefix_suffix OUTPUT_CC_FILE __main .c
mktemp_local_prefix_suffix OUTPUT_COMPILE_FILE compile .sh

unset MAIN_SOURCE OTHER_SOURCES MORE_CONFIG_OPTS
for f in $@ ; do
  if [ -z "$MAIN_SOURCE" ] ; then
    MAIN_SOURCE=$f
    if [ -z "$OUTPUT" ] ; then
      OUTPUT="`basename $MAIN_SOURCE .c`"
      case "$COMPILER" in
        goto-cc) OUTPUT="$OUTPUT.bin" ;;
        cil|cil-blast) OUTPUT="$OUTPUT.i" ;;
        cpp) OUTPUT="$OUTPUT.dir" ;;
        clang) OUTPUT="$OUTPUT.s" ;;
      esac
    fi
  else
    OTHER_SOURCES="$OTHER_SOURCES $f"
  fi
  MORE_CONFIG_OPTS="$MORE_CONFIG_OPTS `egrep "#if( |def )" $f | grep "CONFIG_" |\
    sed -e 's/#ifdef[[:space:]]*CONFIG/CONFIG/' \
    -e 's/#if[[:space:]]*defined(\(CONFIG_.*\))/\1/'`"
done
[ -n "$MAIN_SOURCE" ] || die "No source file given"

[ -d "$KERNEL_SRC/include/asm-i386" ] || die "Kernel source not found in $KERNEL_SRC, use --kernel-src"

DDV_SOURCES="\
  ${DDV_PATH}src/ddverify/ddverify.c \
  ${DDV_PATH}src/ddverify/cdev.c \
  ${DDV_PATH}src/ddverify/interrupt.c \
  ${DDV_PATH}src/ddverify/ioctl.c \
  ${DDV_PATH}src/ddverify/pci.c \
  ${DDV_PATH}src/ddverify/tasklet.c \
  ${DDV_PATH}src/ddverify/timer.c \
  ${KERNEL_SRC}drivers/pci/pci.c \
  ${KERNEL_SRC}arch/i386/lib/usercopy.c \
  ${KERNEL_SRC}fs/char_dev.c \
  ${KERNEL_SRC}kernel/mutex.c \
  ${KERNEL_SRC}kernel/resource.c \
  ${KERNEL_SRC}kernel/sched.c \
  ${KERNEL_SRC}arch/i386/kernel/semaphore.c \
  ${KERNEL_SRC}kernel/softirq.c \
  ${KERNEL_SRC}kernel/spinlock.c \
  ${KERNEL_SRC}kernel/timer.c \
  ${KERNEL_SRC}kernel/wait.c \
  ${KERNEL_SRC}kernel/workqueue.c \
  ${KERNEL_SRC}kernel/irq/manage.c \
  ${KERNEL_SRC}mm/page_alloc.c \
  ${KERNEL_SRC}mm/slab.c \
  ${KERNEL_SRC}mm/vmalloc.c"

char_SOURCES="\
  ${KERNEL_SRC}drivers/char/misc.c \
  ${KERNEL_SRC}drivers/char/tty_io.c"

block_SOURCES="\
  ${DDV_PATH}src/ddverify/genhd.c \
  ${KERNEL_SRC}block/genhd.c \
  ${KERNEL_SRC}block/ll_rw_blk.c"

parse_file

[ -n "$DRIVER_TYPE" ] || die "No driver type set"

print_driver_information

write_cc_file
get_preprocessor_string
write_compile_script

if [ -z "$PREPARE_ONLY" ] ; then
  ./$OUTPUT_COMPILE_FILE
fi

