#!/bin/bash
#
# Example on how to build Mini vMac on Macintosh
# https://minivmac.github.io/gryphel-mirror/c/minivmac/options.html

# Native resolution: 3456 x 2234
# Scaled 1728 X 1117, halved again to 864 x 558

# Clean all old/generated files
rm -rf ./bld
rm -rf ./cfg
rm -rf ./Makefile
rm -rf ./moof*
rm -rf ./build
rm setuptool
rm makefilegen

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
        -hres 864 \
        -vres 558 \
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
        -mem 8M \
        -chr 0 \
        -drc 1 \
        -fullscreen 1 \
        -var-fullscreen 1 \
        -api cco \
        > makefilegen

# generate makefile and build
echo "Generating makefile..."
. ./makefilegen

echo "Building project..."
xcodebuild

