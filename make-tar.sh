#!/bin/bash

set -e

version="`cat scripts/VERSION`"
cp -a scripts bmt-$version
tar czf bmt-$version.tar.gz --exclude-vcs bmt-$version
rm -rf bmt-$version

