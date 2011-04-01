#!/bin/bash

set -evx

mv pkgs pkgs.src
pkgs=`ls pkgs.src`
mkdir pkgs
cd pkgs.src
for i in $pkgs ; do
  [ -d $i ] || continue
  ./make-pkg.sh $i
  mv $i.cprover-bm.tar.gz ../pkgs/
done
cd ..

rsync --progress --archive -L --delete --exclude=".svn" webpage/ /fs/website/people/michael.tautschnig/cpbm
chmod -R a+rX /fs/website/people/michael.tautschnig/cpbm

rm -r pkgs
mv pkgs.src pkgs

