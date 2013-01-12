#!/bin/bash

set -e

name=`echo $1 | sed 's#/$##'`
if [ -z "$name" -o ! -d "$name" ] ; then
  echo "Missing directory name" 1>&2
  exit 1
fi

tar czf $name.cprover-bm.tar.gz --exclude-vcs $name

