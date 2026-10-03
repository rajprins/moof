#!/bin/bash
#
# Example on how to build Mini vMac on Macintosh
# https://minivmac.github.io/gryphel-mirror/c/minivmac/options.html


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
        -m Plus \
        -hres 512 \
        -vres 384 \
        -depth 0 \
        -magnify 1 \
        -mf 2 \
        -sound 1 \
        -sss 4 \
        -sony-sum 1 \
        -sony-tag 1 \
        -speed 1 \
        -ta 2 \
        -em-cpu 2 \
        -mem 1M \
        -chr 0 \
        -drc 1 \
        -fullscreen 0 \
        -var-fullscreen 1 \
        -api cco \
        > makefilegen

# generate makefile and build
echo "Generating makefile..."
. ./makefilegen

echo "Building project..."
xcodebuild

