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

rsync --progress --archive -L --delete --exclude=".svn" webpage/ \
  /srv/www/cprover.org/software/benchmarks/
chmod -R a+rX /srv/www/cprover.org/software/benchmarks

rm -r pkgs
mv pkgs.src pkgs

