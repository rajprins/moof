# Moof

Moof is a miniature Macintosh 68K emulator for Apple Silicon Macs.

It descends from the emulator originally written by Paul C. Pratt,
reduced to a macOS-only build and rebuilt around a native host layer:
Metal rendering, a real menu bar, a SwiftUI settings window, and the
emulator running on its own thread under an ordinary AppKit run loop.

The emulated machine is unchanged from the original; all of the work
is in the host. The name is for Clarus the Dogcow.

## Requirements

- An Apple Silicon Mac running macOS 14 or later.
- Xcode with the command line tools, for building.
- A ROM image of the Macintosh model being emulated. Apple's ROMs are
  copyrighted and are not included; you need to obtain one from a
  machine you own.
- A bootable disk image with a System version that the chosen model
  supports. A System 6.0.8 image is included in `extras/disks` for
  testing.

## Building

Each build of Moof emulates one fixed Macintosh model: the model,
memory size, screen size and colour depth are chosen at build time,
not at run time. `build.sh` in the top level of the repository
produces one such configuration, chosen by a preset name:

```sh
./build.sh [preset] [--clean] [--debug] [-- extra setuptool args]
```

| Preset | Model | Screen | Memory |
|---|---|---|---|
| `ii` (default) | Macintosh II | 800×600, 256 colours | 8 MB |
| `mbp` | Macintosh II | 864×558, 256 colours, starts fullscreen | 8 MB |
| `plus` | Macintosh Plus | 512×384 mono | 1 MB |
| `classic` | Macintosh Classic | 512×384 mono, Dutch keyboard | 2 MB |
| `512k` | Macintosh 512Ke | 512×384 mono | 512 KB |

Run it from the top of the repository, for example:

```sh
./build.sh
./build.sh plus
```

The script compiles the setup tool, generates an Xcode project from
the chosen options, and runs `xcodebuild`. The result is `moof.app`
in the repository root. Everything the script generates is listed in
`.gitignore`; a run removes and regenerates the project and `cfg/`,
so edit the script rather than the generated project. The setup tool
is only recompiled when something in `setup/` changed, and
`xcodebuild`'s derived data in `build/` is kept between runs so a
rebuild only recompiles what changed. `--clean` removes `build/` and
the setup tool as well for a build from scratch.

Anything after `--` is appended to the setup tool invocation and
overrides the preset's options, so a configuration can be varied
without editing the script. For example, to enable LocalTalk, carried
over UDP multicast between Moof instances:

```sh
./build.sh -- -lt -lto udp
```

Options you are most likely to use this way:

| Option | Meaning |
|---|---|
| `-m <model>` | `128K`, `512Ke`, `Plus`, `Kanji`, `SE`, `SEFDHD`, `Classic`, `PB100`, `II`, `IIx` |
| `-mem <size>` | Emulated RAM, for example `4M`, `8M`, `32M` |
| `-hres`, `-vres` | Screen size in pixels |
| `-depth <n>` | Colour depth: `0` is monochrome, `3` is 256 colours (Macintosh II only) |
| `-speed <n>` | Default speed as a power of two: `0` is 1×, `4` is 16×, `z` is all out |
| `-magnify 1` | Start with the window doubled in size |
| `-drives <n>` | Number of disk drives, default 6 |
| `-lt -lto udp` | Enable LocalTalk, carried over UDP multicast between Moof instances |
| `-n <name>` | Name of the generated project and application |

The complete list is in `setup/SPBLDOPT.i`. To add a preset of your
own, add a line to the `case` block in `build.sh`.

### The Kanji (Japanese Macintosh Plus) variant

The [Japanese Macintosh Plus 256K ROM](https://web.archive.org/web/20250518175439/https://www.journaldulapin.com/2025/05/17/the-lost-japanese-rom-of-the-macintosh-plus-which-isnt-lost-anymore/),
which has KanjiTalk fonts built in, works with `-m Kanji`. Start from
the `plus` preset, since the Macintosh II presets ask for a colour
depth the Kanji model does not support. For example, with LocalTalk
enabled:

```sh
./build.sh plus -- -m Kanji -lt -lto udp -sgn 0
```

### A build with symbols

Release builds are stripped. `./build.sh --debug` builds the same
project without stripping and with DWARF debug information, keeping
the optimisation level, so `lldb` can show function names and
backtraces for the result.

## Running

### The ROM

Each model looks for a ROM file with a fixed name:

| Model | ROM file |
|---|---|
| 128K | `Mac128K.ROM` |
| 512Ke, Plus | `vMac.ROM` |
| Kanji | `MacPlusKanji.ROM` |
| SE | `MacSE.ROM` |
| SE FDHD | `SEFDHD.ROM` |
| Classic | `Classic.ROM` |
| PowerBook 100 | `PB100.ROM` |
| II | `MacII.ROM` |
| IIx | `MacIIx.ROM` |

Moof searches for it in this order and uses the first match:

1. The folder that contains `moof.app`.
2. `~/Library/Preferences/Gryphel/mnvm_rom/`
3. `/Library/Application Support/Gryphel/mnvm_rom/`

The second location is the convenient one if you keep several builds
around. If no ROM is found the window opens with an alert saying so;
dropping a ROM file onto the window loads it.

### Disk images

Moof mounts raw images of HFS or MFS volumes, DiskCopy 4.2 images,
and images with an Apple partition map, from which it mounts the
first HFS partition. Any extension works; `.dsk` and `.img` are
conventional. An image Moof does not recognise, such as an
unformatted file of zeros, is refused with an alert rather than
mounted, so a new blank volume has to be made on the host, for
example with Disk Jockey, or by formatting a volume on another
emulator that mounts raw files. There are four ways to insert an
image:

- **At launch.** Files named `disk1.dsk`, `disk2.dsk`, and so on in
  the folder that contains `moof.app` are inserted in order until the
  first name that is missing or the drives are full. `disk1.dsk` is usually the boot volume.
- **File › Open Disk Image…** (⌃O), which shows an open panel.
- **Drag and drop** an image file onto the Moof window.
- **Open with Moof** from the Finder, or `open -a moof.app image.dsk`.

The supplied builds have six drives (the `-drives` option sets the
count), so up to six images can be mounted at once. The emulated Mac
sees each
as a hard disk, so System software treats them as fixed volumes and
you eject them by dragging the icon to the Trash or with ⌘E in the
Finder, exactly as on the original machine.

### Ejecting from the host

**File › Eject** lists the mounted images. Ejecting one the emulated
Mac still has mounted is like pulling a drive from a running machine,
so Moof asks first and offers **Eject Anyway**. Ejecting in the guest
is always safe and is reflected in this menu at once. The Settings
window has the same list with an Eject button per drive.

### Shutting down and quitting

Shut the emulated Mac down from its own **Special › Shut Down** before
quitting Moof, so that the volumes are unmounted cleanly. Quit with
**⌃Q**, the close button, or the Dock. If any image is still mounted
Moof refuses and explains why; shut down in the guest, then quit
again. The disk images are then safe to copy or back up.

### Keyboard

The emulated Mac receives every keystroke, including every ⌘
combination, so ⌘Q, ⌘W, ⌘H and the rest go to the guest and not to
macOS. For that reason Moof's own shortcuts use **Control**:

| Shortcut | Action |
|---|---|
| ⌃O | Open Disk Image… |
| ⌃R | Reset |
| ⌃I | Interrupt (enters the debugger if one is installed) |
| ⌃M | Magnify (double the window size) |
| ⌃⌘F | Enter or leave full screen |
| ⌃, | Settings… |
| ⌃Q | Quit |

Control chords that no menu item claims still reach the guest. The
Option key and Caps Lock are passed through. The host's Command key
is the Mac's ⌘ key.

### The Machine menu

- **Reset** restarts the emulated Mac as if its reset switch had been
  pressed. Images stay inserted.
- **Interrupt** presses the programmer's switch. Without a debugger
  installed the ROM shows a `>` prompt; type `G` and Return to
  continue.
- **Speed** sets how fast the emulated CPU runs relative to the
  original: 1× through 32×, or **All Out**, which uses as much of a
  host core as it can. 1× is the only setting at which games and
  sound run at their original pace.
- **Pause** stops emulation entirely and also silences sound.
- **Run in Background** keeps the emulator running when Moof is not
  the frontmost application. Off by default, so a Moof window in the
  background costs nothing. Note that with this off a Reset chosen
  while another application is in front is queued, not lost; it
  takes effect when the window is activated.
- **Slow Down When Idle** drops to 1× when the emulated Mac has
  nothing to do, which keeps fans quiet during idle.

### Display

The window shows the emulated screen at its native size, or doubled
with **View › Magnify**. Full screen is available from the View menu
or the green button and hides the macOS menu bar; move the pointer to
the top of the screen to reveal it. Colour builds offer two depths
in the guest's Monitors control panel: black and white, and the depth
the build was made with.

### Sound

Sound is on in every supplied build and plays through the default
output device. It stops when emulation is paused or when the window
goes to the background with Run in Background off.

### Networking

A build made with `-lt -lto udp` has a LocalTalk port on the printer
port. Frames are carried on UDP multicast group 239.192.76.84, port
1954, so any Moof instances on the same local network, including
several on one machine, see each other on one LocalTalk segment.
Turn on AppleTalk in the guest's Chooser to use it, for example for
file sharing between two emulated machines.

### Where Moof keeps its state

- **Parameter RAM**, the settings the Mac keeps in its clock chip
  (mouse speed, startup disk, sound volume, AppleTalk node), is saved
  per model in `~/Library/Application Support/Moof/`, for example
  `MacII.pram`. Delete the file to return to factory defaults.
- Disk images are modified in place. Nothing else is written.

## Contributing

If you find any bugs and/or implement new features, please feel free
to create a pull request. Changes of general interest are welcome.

## License

Moof is distributed under version 2 of the GNU General Public License.
See COPYING.txt.
