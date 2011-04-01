#!/bin/bash

set -e

mv pkgs pkgs.src
pkgs=`ls pkgs.src`
mkdir pkgs
cd pkgs.src
for i in $pkgs ; do
  [ -d $i ] || continue
  ./make-pkg.sh $i
  mv $i.cprover-bm.tar.gz ../pkgs/
done

rsync --archive -L --delete --ignore=".svn" webpage/ /fs/website/people/michael.tautschnig/cpbm

rm -r pkgs.src
mv pkgs.src pkgs

