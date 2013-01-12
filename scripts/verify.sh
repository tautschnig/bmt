#!/bin/bash
#
# Copyright (c) 2011 Michael Tautschnig <michael.tautschnig@comlab.ox.ac.uk>
# Daniel Kroening
# Computing Laboratory, Oxford University
# 
# All rights reserved. Redistribution and use in source and binary forms, with
# or without modification, are permitted provided that the following
# conditions are met:
# 
#   1. Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
# 
#   2. Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
# 
#   3. All advertising materials mentioning features or use of this software
#      must display the following acknowledgement:
# 
#      This product includes software developed by Daniel Kroening,
#      Edmund Clarke, Computer Systems Institute, ETH Zurich
#      Computer Science Department, Carnegie Mellon University
# 
#   4. Neither the name of the University nor the names of its contributors
#      may be used to endorse or promote products derived from this software
#      without specific prior written permission.
# 
#    
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS `AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# wrapper around CPROVER verification tools to verify a claim at a time and
# generate useful benchmarking data

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
        rm -f $f
      fi
    done
    rm -f tmp.stderr*.txt
  fi
}

trap 'cleanup' ERR EXIT

mktemp_local_prefix_suffix() {
  local varname=$1
  local prefix=$2
  local suffix=$3
  local tmpf="`TMPDIR=. mktemp -t $prefix.XXXXXX`"
  TMP_FILES="$TMP_FILES $tmpf"
  local rand="`echo $tmpf | sed "s#^./$prefix\\\.##"`"
  eval $varname=\"${prefix}_$rand$suffix\"
  TMP_FILES="$TMP_FILES ${!varname}"
  [ ! -f "${!varname}" ] || die "File already exists"
  mv $tmpf ${!varname}
}

usage() {
  cat <<EOF
Usage: $SELF [OPTIONS] SOURCES ... [-- BACKENDOPTS]
  where SOURCES are C files or goto binaries
  $SELF runs a verification tool of choice to verify a given claim or all all
  contained claims (until a counterexample is found). All options following "--"
  are handed on to the back end.

  Options:                              Purpose:
    -h|--help                           show help
    --no-cleanup                        don't remove generated files
    --claim CLAIM                       verify claim CLAIM
    --timeout                           timeout per claim in seconds
    --maxmem                            memory limit (in MiB)
  Expected verification result
    --unknown                           result is unknown (default)
    --valid                             claim is valid
    --invalid                           claim is invalid
  Back end:
    --cmd CMD                           execute verification command CMD

EOF
}

run_tool() {
  which $TOOL > /dev/null || die "$TOOL is not an executable"

  TMP_FILES="$TMP_FILES .smv_lock cegar_tmp_abstract.warn \
    cegar_tmp_abstract.smv cegar_tmp_abstract.stats \
    cegar_tmp_abstract.out cegar_tmp_abstract.update \
    cegar_tmp_smv_out1 cegar_tmp_smv_out2"
  exit_code=0
  tmp_files=$TMP_FILES
  cl="`echo $CLAIM | sed 's/^ //' | sed 's/ /+/g'`"
  mktemp_local_prefix_suffix claim_out "`basename $MAIN_SOURCE`_${cl}_`date +%Y-%m-%d_%H%M%S`" .log
  # we want to keep this file
  TMP_FILES=$tmp_files
 
  echo "SOURCES: $SOURCES"
  echo "CLAIM: $CLAIM"

  case "$TOOL" in
    *pblast.opt)
      version_info=`$TOOL 2>&1 | grep ^BLAST`
      ;;
    *cpa.sh)
      version_info="no info"
      ;;
    checkfence)
      version_info="no info"
      ;;
    *cream)
      version_info=`$TOOL --help | grep "Cream ver " | awk '{ print $4 }'`
      ;;
    *)
      version_info=`$TOOL --version || true`
      ;;
  esac
  
  case `uname -s` in
    Linux|CYGWIN_*)
      mktemp_local_prefix_suffix time_out stats .stat
      BENCHMARKING="/usr/bin/time -v -o$time_out"
      cat > $claim_out <<EOF
### uname -a:
`uname -a`
### cat /proc/cpuinfo:
`cat /proc/cpuinfo`
### cat /proc/meminfo:
`cat /proc/meminfo`
EOF
      ;;
    Darwin)
      BENCHMARKING="/usr/bin/time -l"
      cat > $claim_out <<EOF
### uname -a:
`uname -a`
### /usr/sbin/system_profiler -detailLevel full SPHardwareDataType:
`/usr/sbin/system_profiler -detailLevel full SPHardwareDataType`
### /usr/sbin/system_profiler -detailLevel full SPMemoryDataType:
`/usr/sbin/system_profiler -detailLevel full SPMemoryDataType`
EOF
      ;;
    MINGW32_*)
      cat > $claim_out <<EOF
### uname -a:
`uname -a`
EOF
      ;;
    *)
      die "Unsupported platform `uname -s`"
      ;;
  esac
  
  cat >> $claim_out <<EOF
### date:
`date`
### user:
$USER
### ulimit -a:
`ulimit -a`
### timeout:
$TIMEOUT
### tool version info:
$version_info
### tool command:
$TOOL $OPTS
### full command line:
$TOOL $OPTS $CLAIM_CMD $SOURCES
### expected verification result:
$EXPECT_RESULT
###############################################################################
EOF
  $TIMEOUT $BENCHMARKING $TOOL $OPTS $CLAIM_CMD $SOURCES >> $claim_out 2>&1 || exit_code=$?
  sleep 1
  # interactive bash needed for proper support of Ctrl-c ?
  # bash -i -c "$TIMEOUT $BENCHMARKING $TOOL $OPTS --claim ${!claim_id_var} $SOURCES >> $claim_out 2>&1" || exit_code=$?
  cat >> $claim_out <<EOF
###############################################################################
### exit code:
$exit_code
EOF
  
  case `uname -s` in
    Linux|CYGWIN_*|MINGW32_*)
      cat >> $claim_out <<EOF
### /usr/bin/time -v:
`cat $time_out`
EOF
      ;;
    Darwin)
      cat >> $claim_out <<EOF
### /usr/bin/time -l:
`cat $claim_out | perl -n -e '$do = 1 if(/.* real .* user .* sys$/); print $_ if($do);'`
EOF
      ;;
  esac

  echo "LOGFILE: $PWD/$claim_out"
}

SELF=$0

opts=`getopt -n "$0" -o "h" --long "\
	    help,\
      no-cleanup,\
      claim:,\
      timeout:,\
      maxmem:,\
      unknown,\
      valid,\
      invalid,\
      cmd:,\
  " -- "$@"`
eval set -- "$opts"

unset NO_CLEANUP CLAIM CLAIM_CMD TIMEOUT MAXMEM TOOL TO_OPTS

EXPECT_RESULT=unknown

while true ; do
  case "$1" in
    -h|--help) usage ; exit 0;;
    --no-cleanup) NO_CLEANUP=1 ; shift 1;;
    --claim) CLAIM="$CLAIM $2" ; shift 2;;
    --timeout)
      if ! echo $2 | egrep -q "^[[:digit:]]+$" ; then
        die "Invalid parameter to --timeout"
      fi
      TO_OPTS="-s SIGINT"
      if ! timeout $TO_OPTS 3 true > /dev/null 2>&1 ; then
        TO_OPTS="-2"
        if ! timeout $TO_OPTS 3 true > /dev/null 2>&1 ; then
          die "No working timeout command found"
        fi
      fi
      TIMEOUT="timeout $TO_OPTS $2" ; shift 2;;
    --maxmem)
      if ! echo $2 | egrep -q "^[[:digit:]]+$" ; then
        die "Invalid parameter to --maxmem"
      fi
      ulimit -S -v $(( $2 * 1024 )) ; shift 2;;
	  --unknown|--valid|--invalid) EXPECT_RESULT="`echo $1 | cut -b3-`" ; shift 1;;
    --cmd) TOOL="$2" ; shift 2;;
    --) shift ; break ;;
    *) die "Unknown option $1" ;;
  esac
done

[ -n "$TOOL" ] || die "Please select the verification tool to be used"

if [ -n "$CLAIM" ] && [ "$CLAIM" != " ALL_CLAIMS" ] ; then
  for c in $CLAIM ; do
    if [ "$TOOL" = "loopfrog" ] ; then
      CLAIM_CMD="$CLAIM_CMD --testclaim $c"
    else
      CLAIM_CMD="$CLAIM_CMD --claim $c"
    fi
  done
else
  CLAIM="ALL_CLAIMS"
fi

unset MAIN_SOURCE OTHER_SOURCES OPTS
for o in $@ ; do
  case "$o" in
    -*)
      OPTS=$@
      if [ "$TOOL" = "loopfrog" ] ; then
        OPTS="--no-progress $OPTS"
      fi
      break
      ;;
    *)
      [ -f "$o" ] || die "Source file $o not found"
      if [ "$TOOL" = "scratch" -a "`file -b $o`" = "data" ] ; then
        SOURCES="$SOURCES --binary $o"
      else
        SOURCES="$SOURCES $o"
      fi
      if [ -z "$MAIN_SOURCE" ] ; then
        MAIN_SOURCE=$o
      fi
      shift 1
      ;;
  esac
done
[ -n "$MAIN_SOURCE" ] || die "No source file given"

run_tool

