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


# wrapper around Cil to compile multiple source files into a single
# Cil-simplified and preprocessed file.

set -e

die() {
  echo $1
  exit 1
}

unset TMP_FILES TMP_DIRS NO_CLEANUP
ifs_bak=$IFS
cleanup() {
  IFS=$ifs_bak
  if [ -z "$NO_CLEANUP" ] ; then
    for f in $TMP_FILES ; do
      if [ -f $f ] ; then
        rm $f
      fi
    done
    for d in $TMP_DIRS ; do
      if [ -d $d ] ; then
        rm -r $d
      fi
    done
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
Usage: $SELF [OPTIONS] SOURCES ...
  where SOURCES are C files containing to be merged and cil-simplified as
  required, e.g., by CPAChecker.
   
  Options:                              Purpose:
    -h|--help                           show help
    --no-cleanup                        don't remove generated files
    --no-simplify                       only preprocess and merge files
    --blast                             translate __CPROVER_assert to ERROR labels
    -D macro                            define preprocessor macro
    -I path                             add to preprocessor search path
    -o file                             file name of resulting output (defaults to first SOURCE.i)

EOF
}

SELF=$0

opts=`getopt -n "$0" -o "hD:I:o:" --long "help,no-cleanup,no-simplify,blast" -- "$@"`
eval set -- "$opts"

unset DEFINES INCLUDES OUTPUT NO_SIMPLIFY BLAST

while true ; do
  case "$1" in
    -h|--help) usage ; exit 0;;
    --no-cleanup) NO_CLEANUP=1 ; shift 1;;
    --no-simplify) NO_SIMPLIFY=1 ; shift 1;;
    --blast) BLAST=1 ; shift 1;;
    -D) DEFINES="$DEFINES -D$2" ; shift 2;;
    -I) INCLUDES="$INCLUDES -I$2" ; shift 2;;
    -o) OUTPUT="$2" ; shift 2;;
    --) shift ; break ;;
    *) die "Unknown option $1" ;;
  esac
done

unset MAIN_SOURCE OTHER_SOURCES
for f in $@ ; do
  if [ -z "$MAIN_SOURCE" ] ; then
    MAIN_SOURCE=$f
    if [ -z "$OUTPUT" ] ; then
      OUTPUT="`basename $MAIN_SOURCE .c`.i"
    fi
  else
    OTHER_SOURCES="$OTHER_SOURCES $f"
  fi
done
[ -n "$MAIN_SOURCE" ] || die "No source file given"


d=`TMPDIR=. mktemp -d -t cil.XXXXXX`
TMP_DIRS="$d"
preproc_files=""
for f in $MAIN_SOURCE $OTHER_SOURCES ; do
  cd $d
  mktemp_local_prefix_suffix preproc_src preproc .i
  cd ..
  if [ -n "$BLAST" ] ; then
    cat > $d/$preproc_src <<EOF
void __CPROVER_assert(int a, char * b) {
  if(a) { 
    ERROR:
      (void)0; 
    goto ERROR;
  }
}
EOF
  fi
  gcc -E -D__CPROVER__ $DEFINES $INCLUDES $f >> $d/$preproc_src
  preproc_files="$preproc_files $preproc_src"
done

cd $d
TMP_DIRS="../$d"
if [ "x$OTHER_SOURCES" = "x" ] ; then
  if [ -n "$NO_SIMPLIFY" ] ; then
    cd ..
    TMP_DIRS="$d"
    mv $d/`basename $preproc_files` $OUTPUT
  else
    CILLY_DONT_LINK_AFTER_MERGE=1 cilly --save-temps -x c --dosimplify --printCilAsIs --domakeCFG -o `basename $OUTPUT` $preproc_files
    cd ..
    TMP_DIRS="$d"
    mv $d/`basename $preproc_files .i`.cil.c $OUTPUT
  fi
else
  CILLY_DONT_LINK_AFTER_MERGE=1 cilly --save-temps -x c --merge --keepmerged -o `basename $OUTPUT` $preproc_files
  if [ -n "$NO_SIMPLIFY" ] ; then
    cd ..
    TMP_DIRS="$d"
    mv $d/`basename ${OUTPUT}_comb.c` $OUTPUT
  else
    CILLY_DONT_LINK_AFTER_MERGE=1 cilly --save-temps -x c --dosimplify --printCilAsIs --domakeCFG -o `basename $OUTPUT` `basename ${OUTPUT}_comb.c`
    cd ..
    TMP_DIRS="$d"
    mv $d/`basename ${OUTPUT}_comb.cil.c` $OUTPUT
  fi
fi

