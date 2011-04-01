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


# To be run in an unpacked CPROVER benchmark; updates the patch series with
# respect to the original source, the known patches, and the current code base;
# then rebuilds PKG.cprover-bm.tar.gz from the resulting cprover/ directory

set -e

die() {
  echo $1
  exit 1
}

checked_patch() {
  patch=$1
  [ -f $patch ] || die "Patch file $patch not found" 
  echo -n "Checking patch `basename $patch` ... "
  lc=`patch -f -p1 --dry-run < $patch 2>&1 | egrep -v "^patching file" | wc -l`
  if [ $lc -ne 0 ] ; then
    echo "clean application failed:"
    patch -f -p1 --dry-run < $patch || true
    die "Failed to apply patch `basename $patch`"
  fi
    
  echo "patch ok, applying"
  patch -p1 < $patch
}

usage() {
  cat <<EOF
Usage: $SELF [OPTIONS] SOURCE
  where SOURCE is an archive file
  $SELF unpacks SOURCE into a temporary directory, applies the patches from
  cprover/patches/series, and records the diff to the current source tree as new
  patch in cprover/patches/series. Then $SELF rebuilds PKG.cprover-bm.tar.gz from
  the resulting cprover/ directory.

  Options:                              Purpose:
    -h|--help                           show help
    --init                              create and populate cprover/ directory
EOF
}

SELF=$0
SELF_DIR=`dirname $0`
PKG_NAME="`basename \`pwd\``"
BM_PKG="../$PKG_NAME.cprover-bm.tar.gz"

opts=`getopt -n "$0" -o "h" --long "\
	    help,\
      init\
  " -- "$@"`
eval set -- "$opts"

while true ; do
  case "$1" in
    -h|--help) usage ; exit 0;;
    --init)
      [ ! -d cprover ] || die "cprover directory already exists"
      [ ! -f $BM_PKG ] || die "$BM_PKG already exists"
      mkdir cprover
      cp $SELF_DIR/rules.template cprover/rules
      chmod a+x cprover/rules
      cd ..
      tar czf `basename $BM_PKG` --exclude-vcs $PKG_NAME/cprover
      cd $PKG_NAME
      shift 1;;
    --) shift ; break ;;
    *) die "Unknown option $1" ;;
  esac
done

if [ $# -ne 1 ] ; then
  usage
  exit 1
fi

SOURCE=$1

[ -f $SOURCE ] || die "Source package $SOURCE not found"
[ -d cprover ] || die "Current directory does not contain a cprover directory"
[ -f $BM_PKG ] || die "Benchmark patch package $BM_PKG not found"

cprover/rules clean

cleanup() {
  if [ -n $TMP_UNPACK -a -d $TMP_UNPACK ] ; then
    rm -r $TMP_UNPACK
  fi
  for f in $TMP_FILES ; do
    if [ -f $f ] ; then
      rm $f
    fi
  done
}

trap 'cleanup' ERR EXIT

TMP_UNPACK="`TMPDIR=../ mktemp -d -t cproverbm.XXXXXX`"

case $SOURCE in
  *.zip)
    unzip -n -d $TMP_UNPACK $SOURCE
    [ `find $TMP_UNPACK -maxdepth 1 -type d | wc -l` -eq 2 ] || \
      die "Source $SOURCE must contain exactly one directory"
    [ `find $TMP_UNPACK -maxdepth 1 | wc -l` -eq 2 ] || \
      die "Source $SOURCE must not contain anything other than one directory"
    mv $TMP_UNPACK/* ${TMP_UNPACK}_
    rmdir $TMP_UNPACK
    mv ${TMP_UNPACK}_ $TMP_UNPACK
    ;;
  *.tar.gz|*.tgz)
    tar xz --no-same-owner --no-overwrite-dir --strip-components=1 -f $SOURCE -C $TMP_UNPACK
    ;;
  *.tar)
    tar x --no-same-owner --no-overwrite-dir --strip-components=1 -f $SOURCE -C $TMP_UNPACK
    ;;
  *.tar.bz2)
    tar xj --no-same-owner --no-overwrite-dir --strip-components=1 -f $SOURCE -C $TMP_UNPACK
    ;;
  *)
    die "Unsupported archive format in $SOURCE"
    ;;
esac

cd $TMP_UNPACK
if [ -d ../$PKG_NAME/cprover/patches -a -s ../$PKG_NAME/cprover/patches/series ] ; then
  for p in $(<../$PKG_NAME/cprover/patches/series) ; do
    checked_patch ../$PKG_NAME/cprover/patches/$p
  done
fi

cd ..
TMP_UNPACK="`basename $TMP_UNPACK`"
patch_tmp="`mktemp cproverbm.XXXXXX`"
TMP_FILES="$TMP_FILES $patch_tmp"
if ! diff -urN -xCVS -x.svn -xcprover $TMP_UNPACK $PKG_NAME > $patch_tmp ; then
  diff_exit_code=${PIPESTATUS[0]}
  if [ $diff_exit_code -ne 1 ] ; then
    cat $patch_tmp | egrep -v '^(-|\+|@| |diff -urN)' 1>&2
    die "diff had error exit code $diff_exit_code -- check for binary files as listed above"
  fi
  if [ ! -d $PKG_NAME/cprover/patches ] ; then
    mkdir $PKG_NAME/cprover/patches
  fi
  if [ ! -f $PKG_NAME/cprover/patches/series ] ; then
    touch $PKG_NAME/cprover/patches/series
  fi
  patch_idx="`printf "%03d" \`ls $PKG_NAME/cprover/patches | wc -l\``"
  new_patch="`TMPDIR=$PKG_NAME/cprover/patches mktemp -t "$patch_idx-new_patch.XXXXXX"`"
  mv $patch_tmp $new_patch
  echo "`basename $new_patch`" >> $PKG_NAME/cprover/patches/series
  echo "Added patch $new_patch to record the following changes:"
  diffstat $new_patch
fi
  
tar czf `basename $BM_PKG` --exclude-vcs $PKG_NAME/cprover

