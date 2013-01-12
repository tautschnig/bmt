#!/bin/bash

set -e

version="`cat scripts/VERSION`"
cp -a scripts cpbm-$version
tar czf cpbm-$version.tar.gz --exclude-vcs cpbm-$version
rm -rf cpbm-$version

