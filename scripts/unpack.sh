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


# Takes an original source archive and the benchmark package to build an
# unpacked and patched source tree with a cprover directory

set -e

die() {
  echo $1
  exit 1
}

checked_patch() {
  patch=$1
  [ -f $patch ] || die "Patch file $patch not found" 
  lc=`patch -f -p1 --dry-run < $patch 2>&1 | egrep -v "^patching file" | wc -l`
  if [ $lc -ne 0 ] ; then
    patch -f -p1 --dry-run < $patch || true
    die "Failed to apply patch `basename $patch`"
  fi
    
  echo "Applying patch `basename $patch`"
  patch -p1 < $patch
}

usage() {
  cat <<EOF
Usage: $0 SOURCE PKG.cprover-bm.tar.gz
  where SOURCE is either an archive file or a URL of the form http://...
  $0 unpacks SOURCE into a directory PKG, unpacks PKG.cprover-bm.tar.gz as
  PKG/cprover/, and applies any patches from PKG/cprover/patches according to
  PKG/cprover/series. 
EOF
}

if [ $# -ne 2 ] ; then
  usage
  exit 1
fi

SOURCE=$1
source_file_name=$SOURCE
BM_PKG=$2

if echo $SOURCE | grep -q "^http://" ; then
  source_file_name="`echo $SOURCE | sed 's#.*/##'`"
  [ -f $source_file_name ] && die "File target $source_file_name for download already exists"
  wget $SOURCE
  SOURCE=$source_file_name
else
  [ -f $SOURCE ] || die "Source package $SOURCE not found"
fi

[ -f $BM_PKG ] || die "Benchmark patch package $BM_PKG not found"
( echo $BM_PKG | egrep -q '.+\.cprover-bm\.tar\.gz$' ) || \
  die "Benchmark patch package $BM_PKG does not have a name ending in .cprover-bm.tar.gz"

cleanup() {
  if [ -n $TMP_UNPACK -a -d $TMP_UNPACK ] ; then
    rm -r $TMP_UNPACK
  fi
}

trap 'cleanup' ERR EXIT

TMP_UNPACK="`TMPDIR=. mktemp -d -t cproverbm.XXXXXX`"
PKG_NAME="`basename $BM_PKG | sed 's#\.cprover-bm\.tar\.gz$##'`"
[ -d $PKG_NAME ] && die "Target directory $PKG_NAME already exists"

case $SOURCE in
  *.zip)
    unzip -n -d $TMP_UNPACK $SOURCE
    [ `find $TMP_UNPACK -maxdepth 1 -type d | wc -l` -eq 2 ] || \
      die "Source $SOURCE must contain exactly one directory"
    [ `find $TMP_UNPACK -maxdepth 1 | wc -l` -eq 2 ] || \
      die "Source $SOURCE must not contain anything other than one directory"
    mv $TMP_UNPACK/* $PKG_NAME
    rmdir $TMP_UNPACK
    ;;
  *.tar.gz|*.tgz)
    tar xz --no-same-owner --no-overwrite-dir --strip-components=1 -f $SOURCE -C $TMP_UNPACK
    mv $TMP_UNPACK $PKG_NAME
    ;;
  *.tar)
    tar x --no-same-owner --no-overwrite-dir --strip-components=1 -f $SOURCE -C $TMP_UNPACK
    mv $TMP_UNPACK $PKG_NAME
    ;;
  *.tar.bz2)
    tar xj --no-same-owner --no-overwrite-dir --strip-components=1 -f $SOURCE -C $TMP_UNPACK
    mv $TMP_UNPACK $PKG_NAME
    ;;
  *)
    die "Unsupported archive format in $SOURCE"
    ;;
esac

trap - ERR EXIT

mkdir $PKG_NAME/cprover
tar xz --no-same-owner --no-overwrite-dir --strip-components=2 -f $BM_PKG -C $PKG_NAME/cprover

cd $PKG_NAME
if [ -d cprover/patches -a -s cprover/patches/series ] ; then
  for p in $(<cprover/patches/series) ; do
    checked_patch cprover/patches/$p
  done
fi

chmod a+x cprover/rules

