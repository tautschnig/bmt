#!/bin/bash
#
# Michael Tautschnig
# michael.tautschnig@comlab.ox.ac.uk
#
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
      cat > cprover/rules <<"EOF"
#!/usr/bin/make -f

# put files for verification in here
OBJS=

build::
\ttest -d cprover
# put your build rules in here

TOOL1=cbmc
TOOL_OPTS1=--unwind 3 --no-unwinding-assertions --32
TOOL2=satabs
TOOL_OPTS2=--iterations 20 --32
TOOL3=wolverine
TOOL_OPTS3=--unwind 5 --32

TOOL=$(TOOL1)
TOOL_OPTS=$(TOOL_OPTS1)
TIMEOUT=60

verify:: build
\ttest -d cprover
\t$(MAKE) -f cprover/rules cprover/verified

cprover/verified: $(OBJS)
\tmkdir -p results
\techo "TOOL: $(TOOL) $(TOOL_OPTS)" > $@
\techo "TIMEOUT: $(TIMEOUT)" >> $@
\techo "RESULTS:" >> $@
\tset -e ; cd results ; for f in $^ ; do \
\t  verify.sh --timeout $(TIMEOUT) --$(TOOL) ../$$f -- $(TOOL_OPTS) >> ../$@ ; \
\tdone

clean::
\ttest -d cprover
\trm -rf results
\trm -f cprover/verified
\trm -f $(OBJS)

EOF
      sed -i 's/\\t/\t/' cprover/rules
      chmod a+x cprover/rules
      cd ..
      tar czf `basename $BM_PKG` $PKG_NAME/cprover
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

TMP_UNPACK="`mktemp -d --tmpdir=../ cproverbm.XXXXXX`"

case $SOURCE in
  *.zip)
    unzip -n -d $TMP_UNPACK $SOURCE
    [ `find $TMP_UNPACK -maxdepth 1 -type d | wc -l` -eq 2 ] || \
      die "Source $SOURCE must contain exactly one directory"
    mv $TMP_UNPACK/* ${TMP_UNPACK}_
    rmdir $TMP_UNPACK
    mv ${TMP_UNPACK}_ $TMP_UNPACK
    ;;
  *.tar.gz)
    tar xz --no-same-owner --no-overwrite-dir --strip-components=1 -f $SOURCE -C $TMP_UNPACK
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
if ! diff -urN -xcprover $TMP_UNPACK $PKG_NAME > $patch_tmp ; then
  diff_exit_code=${PIPESTATUS[0]}
  [ $diff_exit_code -eq 1 ] || die "diff had unexpected exit code $diff_exit_code -- check for binary files"
  if [ ! -d $PKG_NAME/cprover/patches ] ; then
    mkdir $PKG_NAME/cprover/patches
  fi
  if [ ! -f $PKG_NAME/cprover/patches/series ] ; then
    touch $PKG_NAME/cprover/patches/series
  fi
  patch_idx="`printf "%03d" \`ls $PKG_NAME/cprover/patches | wc -l\``"
  new_patch="`mktemp --tmpdir=$PKG_NAME/cprover/patches "$patch_idx-new_patch.XXX"`"
  mv $patch_tmp $new_patch
  echo "`basename $new_patch`" >> $PKG_NAME/cprover/patches/series
fi
  
tar czf `basename $BM_PKG` $PKG_NAME/cprover

