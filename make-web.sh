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

chmod -R a+rX .
#rsync --progress --archive -L --delete --exclude=".svn" webpage/ /srv/www/cprover.org/software/benchmarks/
rsync --progress --archive -L --delete --exclude=".svn" webpage/ tmp-web
cd tmp-web
scp -r * tautschnig@dkr-srv.cs.ox.ac.uk:/srv/www/cprover.org/software/benchmarks/ || true
cd ..
rm -r tmp-web

rm -r pkgs
mv pkgs.src pkgs

