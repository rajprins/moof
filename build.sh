#!/bin/bash
#
# Example on how to build Mini vMac on Macintosh
# https://minivmac.github.io/gryphel-mirror/c/minivmac/options.html
#
# Usage: ./build.sh [preset] [--clean] [--debug] [-- extra setuptool args]
#
#   preset   which machine to build; see the table in usage() below
#   --clean  also remove ./build (xcodebuild's derived data) so the
#            next xcodebuild starts from scratch instead of incrementally
#   --debug  keep symbols and skip stripping so lldb works on the result
#   --       everything after it is appended to the setuptool command;
#            later options override the preset's, so for example
#            `./build.sh plus -- -m Kanji -lt -lto udp -sgn 0` works

set -euo pipefail

cd "$(dirname "$0")"

usage() {
	cat <<USAGE
Usage: ./build.sh [preset] [--clean] [--debug] [-- extra setuptool args]

Presets:
  ii       Macintosh II, 800x600, 256 colours, 8 MB (default)
  mbp      Macintosh II, 864x558, 256 colours, 8 MB, starts fullscreen
  plus     Macintosh Plus, 512x384 mono, 1 MB
  classic  Macintosh Classic, 512x384 mono, 2 MB, Dutch keyboard
  512k     Macintosh 512Ke, 512x384 mono, 512 KB
USAGE
}

preset=ii
clean=0
debug=0
extra=()
while [ $# -gt 0 ]; do
	case "$1" in
		--clean) clean=1 ;;
		--debug) debug=1 ;;
		-h|--help) usage; exit 0 ;;
		--) shift; extra=("$@"); break ;;
		-*) echo "build.sh: unknown flag '$1'" >&2; usage >&2; exit 2 ;;
		*) preset="$1" ;;
	esac
	shift
done

# Options shared by every preset.
common=(
	-n "moof-3.8"
	-e xcd
	-t mcar
	-magnify 1
	-mf 2
	-sound 1
	-sony-sum 1
	-sony-tag 1
	-ta 2
	-em-cpu 2
	-chr 0
	-drc 1
	-var-fullscreen 1
	-api cco
)

# What differs between presets.
case "$preset" in
	ii)      model=(-m II      -hres 800 -vres 600 -depth 3 -sss 3 -speed 4 -mem 8M   -fullscreen 0) ;;
	mbp)     model=(-m II      -hres 864 -vres 558 -depth 3 -sss 3 -speed 4 -mem 8M   -fullscreen 1) ;;
	plus)    model=(-m Plus    -hres 512 -vres 384 -depth 0 -sss 4 -speed 1 -mem 1M   -fullscreen 0) ;;
	classic) model=(-m Classic -hres 512 -vres 384 -depth 0 -sss 4 -speed z -mem 2M   -fullscreen 0 -lang dut) ;;
	512k)    model=(-m 512Ke   -hres 512 -vres 384 -depth 0 -sss 4 -speed z -mem 512K -fullscreen 0) ;;
	*)
		echo "build.sh: unknown preset '$preset'" >&2
		usage >&2
		exit 2
		;;
esac

# Extra arguments go after a "!" so they may repeat (and so override)
# an option already given by the preset.
if [ ${#extra[@]} -gt 0 ]; then
	extra=("!" "${extra[@]}")
fi

# Remove the generated outputs. ./build holds xcodebuild's derived
# data; keeping it makes the next build incremental.
rm -rf ./moof.app ./moof.xcodeproj ./moof.swiftmodule ./cfg ./bld
rm -f ./Makefile ./makefilegen ./setup.sh
if [ "$clean" -eq 1 ]; then
	rm -rf ./build ./setuptool
fi

# Rebuild the setup tool only when its sources are newer than it.
if [ ! -x ./setuptool ] \
	|| [ -n "$(find setup -newer ./setuptool \( -name tool.c -o -name '*.i' \) -print -quit)" ]
then
	echo "Building setup tool..."
	gcc -o setuptool setup/tool.c
fi

echo "Preset: $preset"
echo "Running setup tool to generate makefile generator..."
echo "./setuptool ${common[*]} ${model[*]} ${extra[*]:-}"
./setuptool "${common[@]}" "${model[@]}" ${extra[@]+"${extra[@]}"} > makefilegen

# generate makefile and build
echo "Generating makefile..."
# The generated script writes relative to my_project_d and relies on
# it being empty for the current directory; set -u needs it defined.
my_project_d=""
. ./makefilegen

echo "Building project..."
xcb=(xcodebuild)
if [ "$debug" -eq 1 ]; then
	xcb+=(
		STRIP_INSTALLED_PRODUCT=NO
		DEPLOYMENT_POSTPROCESSING=NO
		DEBUG_INFORMATION_FORMAT=dwarf
		GCC_GENERATE_DEBUGGING_SYMBOLS=YES
	)
fi
"${xcb[@]}"
