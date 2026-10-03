#!/bin/bash
#
# Example on how to build Mini vMac on Macintosh
# https://minivmac.github.io/gryphel-mirror/c/minivmac/options.html

set -eou pipefail

# Clean all old/generated files
rm -rf ./bld
rm -rf ./cfg
rm -rf ./Makefile
rm -rf ./moof*
rm -rf ./build
rm -f setuptool
rm -f makefilegen

# we need to build the setup tool first
echo "Building setup tool..."


if [ ! -x ./setuptool ]; then
	gcc -o setuptool setup/tool.c
fi

echo "Running setup tool to generate makefile generator..."
./setuptool \
        -n "moof-3.8" \
        -e xcd \
        -t mcar \
        -m II \
        -hres 800 \
        -vres 600 \
        -depth 3 \
        -magnify 1 \
        -mf 2 \
        -sound 1 \
        -sss 3 \
        -sony-sum 1 \
        -sony-tag 1 \
        -speed 4 \
        -ta 2 \
        -em-cpu 2 \
        -mem 32M \
        -chr 0 \
        -drc 1 \
        -fullscreen 0 \
        -var-fullscreen 1 \
        -api cco \
        > makefilegen

# generate makefile and build
echo "Generating makefile..."
# The generated script writes relative to my_project_d and relies on
# it being empty for the current directory; set -u needs it defined.
my_project_d=""
. ./makefilegen

echo "Building project..."
xcodebuild

