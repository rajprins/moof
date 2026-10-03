# Native macOS UI Rewrite — Design

Date: 2026-09-17
Status: Approved for planning

## Summary

Replace the Cocoa backend of Mini vMac with a modern, fully native macOS
host layer: AppKit + SwiftUI chrome, Metal rendering, and the emulator
core running on its own thread under a normal AppKit run loop.

The emulator core is not modified. All work is confined to the host
backend (`src/OSGLUCCO.m` and the headers it includes) and to the build
generator in `setup/` that must learn to emit Swift.

## Finding: there is no third-party UI kit to replace

The original request asked to identify non-Apple UI toolkits that could
be replaced with SwiftUI. There are none. The application links exactly
three frameworks (`minivmac.xcodeproj/project.pbxproj:29-31`): AppKit,
AudioUnit, and OpenGL. The SDL backends carried by upstream Mini vMac
were already removed during the Apple Silicon reduction, as recorded in
`setup/GNBLDOPT.i:796`: "Only the Cocoa backend ("cco",
src/OSGLUCCO.m) remains."

Searches for "SDL" in `src/` return only false positives, recorded here
so the question is not reopened later:

| Location | Meaning |
|---|---|
| `src/OSGLUCCO.m:4,23` | Attribution comment; the window and event code was derived from SDL's Cocoa port in 2012 and vendored. No dependency. |
| `src/SCCEMDEV.c` (9 matches) | SDLC — Synchronous Data Link Control, the Zilog 8530 serial protocol. Emulated hardware. |
| `src/LTOVRBPF.h` (8 matches) | `sdl_nlen`, `sdl_data` — BSD `struct sockaddr_dl` fields. |

The work is therefore not a toolkit migration. It is a modernisation of
an existing all-Apple backend that uses obsolete APIs and renders its
own settings UI into the emulated framebuffer.

## What is actually not native today

1. **Settings are drawn into the guest framebuffer.** `src/CONTROLM.h`
   renders a character-cell overlay and reads single-letter commands
   (`CONTROLM.h:914-953`). The real menu bar has three items; Special →
   "More Commands…" merely enters that overlay (`OSGLUCCO.m:2565-2583`).
2. **Fixed-function OpenGL 1.1.** `glRasterPos2i` + `glPixelZoom` +
   `glDrawPixels` (`OSGLUCCO.m:1666-1681`, `2816`). `glDrawPixels` does
   not exist in an OpenGL core profile.
3. **The emulator replaces AppKit's run loop.** `[NSApp run]` is halted
   immediately by `applicationDidFinishLaunching` (`OSGLUCCO.m:4280`),
   after which `PROGMAIN.c:549` drives `WaitForNextTick()`
   (`OSGLUCCO.m:4067`), which hand-pumps events and `nanosleep`s to pace
   60.14 Hz.
4. **Deprecated APIs.** `NSRunAlertPanel` (2690), `NSOKButton` (2739),
   `convertBaseToScreen:`/`convertScreenToBase:` (1112, 1129,
   4013-4015). Manual retain/release throughout; no ARC.
5. **Hand-rolled fullscreen.** `setPresentationOptions:` with
   `HideDock | HideMenuBar` (`OSGLUCCO.m:2695`) rather than
   `NSWindowStyleMaskFullScreen`. No green button, no Spaces, and no
   auto-revealing menu bar.

## Decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Scope | Full backend rewrite: native chrome, Metal, file split |
| 2 | Language | Swift + SwiftUI for chrome; Obj-C for window, Metal, events, C interop |
| 3 | Settings scope | Runtime-adjustable state only; emulator configuration model untouched |
| 4 | Keyboard | Guest keeps every ⌘; host menus use ⌃; native fullscreen makes the menu bar reachable |
| 5 | Control overlay | Drawing and ⌃-mode state machine deleted; keyboard and ROM logic salvaged |
| 6 | Sequencing | Big-bang rewrite, swapped in one commit |
| 7 | Run loop | Emulator moves to a background thread; AppKit owns the main thread |

Decision 7 was a mid-design discovery, not an initial requirement.
SwiftUI's state invalidation and rendering depend on run-loop observers
and CoreAnimation transaction commits; under the current hand-pumped
loop (`untilDate: distantPast` followed by `nanosleep`) they are
starved. SwiftUI is not viable without it.

Decision 6 was chosen against the recommendation in this design process.
The known cost is that render-timing and threading defects surface only
when the whole thing runs. Section "Verification" places an explicit
early checkpoint to offset this.

## §1 Threading model and the core boundary

**Main thread** runs an ordinary AppKit run loop — `[NSApp run]` is
called and stays running. SwiftUI and Metal live here.

**Emulator thread**: one dedicated thread at `.userInteractive` QoS runs
`ProgramMain()` unchanged.

`PROGMAIN.c`, `MINEM68K.c`, `GLOBGLUE.c` and every `*EMDEV.c` are not
modified. The core continues to believe it owns its thread, because on
its own thread it does. Every global the core touches is reached from
exactly one thread.

`WaitForNextTick` keeps only its pacing role. The `nanosleep` and
`ExtraTimeNotOver` logic survive; the `nextEventMatchingMask:` drain and
`ProcessOneSystemEvent` move to the main thread as ordinary responder
methods.

### Cross-thread synchronisation

This section was revised during implementation. The original plan of
four lock-free SPSC channels was wrong for this codebase, and the
reason is worth recording.

`CheckForSavedTasks` (`OSGLUCCO.m:3698`) is called from
`WaitForNextTick`, so after the thread move it runs on the emulator
thread once per tick — and it is full of main-thread-only AppKit:
`MyUpdateRendererGeometry` reads `[MyNSview frame]` and
`backingScaleFactor`, `[[NSScreen mainScreen] frame]` is queried,
`ReCreateMainWindow` creates and destroys an `NSWindow`,
`EnterBackground` and `LeaveBackground` hide and show the cursor, and
`CheckMouseState` reads `[NSEvent mouseLocation]`.

The host/emulator boundary is therefore wide and crossed every tick,
not narrow. Lock-free channels suit a narrow boundary; a wide one
would need a dozen separately marshalled operations, each its own
opportunity for a race.

**Revised design: one coarse emulator lock.**

- A single recursive mutex guards all emulator state.
- The emulator thread holds it while computing a tick and releases it
  while pacing, which is most of every 16.6 ms at ordinary speeds.
- The main thread acquires it to touch emulator state at all: input
  handling, host housekeeping, and snapshotting the frame.
- `CheckForSavedTasks` moves to the main thread, driven by the display
  link callback, whose ~60 Hz cadence matches what it expects.

Consequences, stated plainly:

- The input ring buffer is no longer needed. A main-thread key handler
  takes the lock and calls `Keyboard_UpdateKeyMap2` directly. No event
  structs, no queue, no ownership transfer for disk image paths.
- The framebuffer triple buffer is no longer needed either, because the
  lock already serialises the emulator's conversion into `ScalingBuff`
  against the main thread's upload.
- **At "all out" speed the emulator never sleeps and never yields, so
  the main thread would starve and the UI would stutter.** An explicit
  periodic lock yield is required in that mode. This is the one place
  where the coarse lock costs something real.

### File layout

`src/OSGLUCCO.m` (4,492 lines) is replaced by the following. All names
are 8 uppercase characters, matching the project's existing convention
(`SPFILDEF.i` registers files by bare name; extensions come from flags).

| File | Contents |
|---|---|
| `EMUTHRED.m` | Emulator thread host, pacing, queue drain |
| `XTHRDQUE.h` | Ring buffer and triple buffer primitives |
| `MTLRENDR.m` | Metal renderer, `CAMetalLayer`, frame upload |
| `EVNTINPT.m` | AppKit responder methods → input queue |
| `HOSTFILE.m` | Drives, ROM loading, `NSOpenPanel` |
| `SNDCOREA.m` | CoreAudio, lifted near-verbatim |
| `KEYRMPMC.h` | `Keyboard_RemapMac`, `Keyboard_UpdateKeyMap2`, `DisconnectKeyCodes2` |
| `ROMVALID.h` | `ROM_IsValid`, `Calc_Checksum`, `WaitForRom`, ROM and unsupported disk warnings, `MacMsgOverride` |
| `CCOBRIDG.h` | Obj-C ↔ Swift bridging header |
| `EMUBRIDG.swift` | Observable emulator state, the sole C boundary for Swift |
| `SETTINGS.swift` | Settings window content |
| `ABOUTPNL.swift` | About panel |
| `APPMENUS.swift` | Menu bar construction |

`CONTROLM.h` is deleted. Its cell drawing and ⌃-mode state machine go
away; `KEYRMPMC.h` and `ROMVALID.h` receive the logic that must survive.
`GetCurDrawBuff` is gone: the `SCRNMAPR.h`/`SCRNTRNS.h` instantiations
read `screencomparebuff` directly, since there is no longer an overlay
buffer to choose between.

## §2 Rendering

**Stage 2 is kept; stage 3 is replaced.** The existing pipeline is:

1. Emulator writes the guest framebuffer (1-bit mono or N-bit indexed)
2. `SCRNMAPR.h` — included twice with differing macros
   (`OSGLUCCO.m:1530, 1542`), a C template idiom — converts the dirty
   rect into `ScalingBuff` at 8bpp luminance or 32bpp RGBA via
   `CLUT_final`
3. `glDrawPixels` blits, nearest-neighbour scaled by `glPixelZoom`

The CPU mapper (stage 2) is untouched. Metal replaces presentation only.

Moving the CLUT conversion into a fragment shader — sampling the raw
guest buffer as `r8Uint` against a 256×1 palette texture, deleting
`ScalingBuff` — is attractive and is recorded as follow-up work. It is
excluded from this rewrite because it would mean reimplementing five
tested depth/mode paths inside the same big-bang commit.

**Presentation:**

- A plain `NSView` backed by `CAMetalLayer`, not `MTKView`. `MTKView`
  imposes its own delegate-driven draw loop; a bare layer with explicit
  `nextDrawable` avoids a second cadence to reconcile.
- `CADisplayLink` on the view drives presentation on the main thread —
  the supported replacement for the deprecated `CVDisplayLink`. It draws
  whichever frame the emulator last published.
- Scaling becomes an `MTLSamplerState` with `.nearest` filtering on a
  fullscreen quad. Magnify becomes a vertex/viewport change, retiring
  the `MyWindowScale` arithmetic threaded through the draw path.

**Whole-frame upload, not dirty rects.** The converted buffer at
800×600×4 is 1.92 MB; 60 Hz is ~115 MB/s on unified memory. Tracking
dirty rects across triple-buffer slots requires unioning regions
whenever the renderer skips a produced frame — a reliable source of
intermittent, unreproducible corruption. Dirty rects continue to limit
stage-2 CPU conversion, where they pay for themselves. The GPU upload is
unconditional and whole-frame.

**Shader compiled from a source string.** The vertex/fragment pair is
roughly 20 lines of MSL. A `.metal` file would require teaching
`WRXCDFLS.i` a `sourcecode.metal` file type and adding a Metal compile
build phase to the generated project. `newLibraryWithSource:options:error:`
costs a few milliseconds once at startup and avoids a second generator
change on top of Swift support.

## §3 Native chrome

### Menu bar (`APPMENUS.swift`)

⌃ equivalents throughout, per decision 4.

- **App** — About, Settings… ⌃, , Hide / Hide Others / Show All, Quit ⌃Q
- **File** — Open Disk Image… ⌃O, Eject ▸ (one dynamic item per inserted disk)
- **Machine** — Reset ⌃R, Interrupt ⌃I, Speed ▸ (1×/2×/4×/8×/16×/32×/All Out/Stopped as radio items), Run in Background, Auto-Slow
- **View** — Magnify ⌃M, Enter Full Screen
- **Window**, **Help**

### Fullscreen

`My_HideMenuBar` and `My_ShowMenuBar` are deleted in favour of
`NSWindowStyleMaskFullScreen` and `toggleFullScreen:`. This yields the
green button, Spaces integration, and a menu bar that auto-reveals on
hover. The last point is load-bearing: it is what makes deleting the
overlay safe, because no command becomes unreachable in fullscreen.

### Settings window

SwiftUI's `Settings` scene requires the SwiftUI `App` lifecycle, which
this application does not use — AppKit owns the app. The Settings window
is therefore an `NSWindowController` hosting
`NSHostingView(rootView: SettingsView())`.

Panes: Speed, Display, Input, Disks. Scoped to runtime-adjustable state
only; nothing that implies baked-in configuration (model, RAM,
resolution, colour depth) can be changed.

### State bridge

`EMUBRIDG.swift` is the only place Swift meets C. An `@Observable` class
holds published emulator status, refreshed on the main thread from the
status atomics; its setters enqueue commands onto the ring. SwiftUI binds
to it, and it alone talks to `CCOBRIDG.h`. This chokepoint keeps C types
out of the view layer.

### Alerts

`MacMsg` (`COMOSGLU.h:1231`) already defers: it parks text in
`SavedBriefMsg`/`SavedLongMsg` and sets a flag, drained by
`CheckSavedMacMsg` (`OSGLUCCO.m:2676`). That indirection is kept, so no
caller changes. Presentation moves into the main-thread display callback
because `runModal` may no longer be called from the emulator thread. The
`fatal` flag drives whether the app terminates after dismissal.
`NSRunAlertPanel` becomes `NSAlert`.

### Deprecation sweep

Folded in, since these files are being rewritten regardless. The
build emits 38 warnings, all pre-existing; the deprecations among
them are:

| Site | Deprecated | Replacement |
|---|---|---|
| 2686 | `NSRunAlertPanel` (10.10) | `NSAlert` |
| 2742 | `NSOKButton` (10.10) | `NSModalResponseOK` |
| 1160, 1176 | `convertBaseToScreen:` / `convertScreenToBase:` (10.7) | `convertPointToScreen:` / `convertPointFromScreen:` |
| 2618 | `canDraw` (10.14) | not needed once presentation is display-link driven |
| 2947, 2950, 2958 | `NSFilenamesPboardType`, `NSURLPboardType` (10.14) | `NSPasteboardTypeFileURL` |

Manual retain/release becomes ARC. Note that ARC cannot be enabled
piecemeal in a useful way here: `OSGLUCCO.m` holds 28 explicit
`release` calls plus manual `NSAutoreleasePool` use, which ARC
rejects outright. ARC adoption therefore lands together with the
split of that file, not before it. Until then new files are written
MRR correct, as `MTLRENDR.m` is.

### Localization keeps its format

`INTLCHAR.h` implements a custom substitution format across 11 languages
(for example `kStrNoROMMessage "I can not find the ROM image file
;[^r;{. …"`, where `;[` and `^r` are its own escape syntax). Converting
this to `.strings` catalogs would risk 11 translations for no
user-visible gain, so the format and the `STRCN*.h` files stay.

Their content did change with the overlay's removal. Every string that
only the overlay drew (the Control Mode screens, its About and help
text, the menu titles of the old hand-built menu bar) was deleted, so
each language now defines the same 25 macros: the alert titles and
messages, and `kStrCmdQuit` for the fatal alert's button. The quit
warning and the missing-ROM message were rewritten in every language
to describe the native interface, naming the guest Finder's localized
Special menu and Shut Down item where those are known and the English
names otherwise. The 8x16 glyph bitmaps and drawing-only cells went
from `INTLCHAR.h`, along with the substitution codes that only fed
overlay screens (`^c ^m ^k ^g ^f ^b ^h ^l ^s`).

The native menus themselves are English for now. `NSStringCreateFromSubstCStr`
remains the path by which a translated string reaches AppKit.

## §4 Build generator changes

The Xcode project is a generated artifact. `build.sh:8-14` deletes
`./minivmac*`, `./cfg` and `./build` on every run, so hand-edits to
`minivmac.xcodeproj` are discarded. Xcode is the only supported output
(`setup/GNBLDOPT.i:705-709`); no Makefile is emitted, and the
`rm -rf ./Makefile` at `build.sh:10` is vestigial from upstream, which
supports Makefile output for other platforms. There is therefore only
one build path to keep in sync.

Required changes, all enumerable:

1. **`setup/DFFILDEF.i:40-60`** — add `kCSrcFlagSwift 7` and
   `kCSrcFlgmSwift (1 << kCSrcFlagSwift)`, alongside the existing
   `kCSrcFlagOjbc 6`.
2. **`setup/WRXCDFLS.i:391-402`** — `WriteSrcFileAPBXCDtype` learns to
   emit `sourcecode.swift` in addition to `sourcecode.c.objc` and
   `sourcecode.c.c`.
3. **`setup/WRXCDFLS.i` build settings** (near lines 995-1060) — emit
   `SWIFT_VERSION`, `SWIFT_OBJC_BRIDGING_HEADER`,
   `SWIFT_OBJC_INTERFACE_HEADER_NAME`, `CLANG_ENABLE_MODULES = YES`, and
   `SWIFT_OPTIMIZATION_LEVEL`.
4. **`setup/SPFILDEF.i:176`** — replace the single `OSGLUCCO` entry with
   entries for the new file set. Swift files take
   `kCSrcFlgmSwift | kCSrcFlgmNoHeader`.
5. **`setup/SPOTHRCF.i:71`** — `#define WantOSGLUCCO 1` is replaced by
   per-file guards matching the new layout.
6. **`setup/USFILDEF.i:281-284`** — drop `OpenGL`, add `Metal`,
   `QuartzCore`, and `SwiftUI`. Retire the `UseOpenGLinOSX` switch
   (`GNBLDOPT.i:26-27`, `SPBASDEF.i:37`).
7. **`setup/WRCNFGAP.i:63-67`** — replace `#include <OpenGL/gl.h>` with
   the Metal and QuartzCore umbrella headers.

## Verification

The emulator core is untouched, so correctness rests on the host layer
and the thread boundary.

**Early checkpoint, before the rest of the rewrite is written.** Because
the big-bang approach defers integration risk to the end, the two
questions that could invalidate the design are answered first.

**Checkpoint 1 — Swift in a generated project. Resolved, passed.**
`EMUBRIDG.swift` compiles and links in a project emitted by the
generator. Objective-C reaches Swift through the generated
`minivmac-Swift.h`, and Swift reaches C through `CCOBRIDG.h`. Verified
at runtime: the bridge reported `speed exponent 4`, which is the value
`build.sh` passes as `-speed 4`, so a real emulator global crossed both
directions rather than a stub.

Note for anyone repeating this: the build runs `strip -D -u -r`, so
`nm` shows nothing. Objective-C class metadata survives stripping, so
`strings` or `otool -o` are the checks that work.

**Checkpoint 2 — rendering. Resolved, passed (threading half still
open).** The Metal path replaces fixed-function OpenGL and is verified
by running:

- Monochrome path: Mac II boot screen with the blinking insert-disk
  floppy, dither rendered pixel exact.
- Colour path: System 6.0.8 booted, guest Colour menu present, and the
  rainbow Apple logo renders with correct hues. That logo is the
  deliberate test for the `0xRRGGBB00` byte order; a wrong swizzle
  renders it blue dominant.
- `otool -L` confirms `OpenGL.framework` is gone and `Metal.framework`
  plus `QuartzCore.framework` are linked.

The remaining half of this checkpoint — the emulator on a background
thread publishing frames to a `CADisplayLink` driven layer while
holding 60.14 Hz without tearing or audio drift — is not yet answered.

**Per-area checks:**

| Area | Check |
|---|---|
| Threading | Thread Sanitizer clean across boot, disk insert, reset, speed change, quit |
| Rendering | Frame timing held at 60.14 Hz; visual diff against the OpenGL build at 1× and magnified, mono and colour |
| Input | Every key in `Keyboard_RemapMac` round-trips; ⌘ still reaches the guest; modifier state correct after focus loss |
| Menus | Each item drives the correct command; radio state reflects emulator state after external change |
| Alerts | `MacMsg` fatal and non-fatal paths; no `runModal` from the emulator thread |
| Fullscreen | Menu bar reveals on hover; green button and Spaces behave; magnify interaction correct |
| Generator | `./build.sh` from clean produces a building project; no hand-edits to `.xcodeproj` required |
| Regression | Boot to desktop from a real ROM and disk image; LocalTalk still functions |

## Thread Sanitizer results

Run on 2026-09-17 against the threaded build. There is no TSan option
in the generator; the build is produced by overriding settings on the
command line, so nothing about this diagnostic is baked into `setup/`:

    xcodebuild -project minivmac.xcodeproj -configuration Release \
      OTHER_CFLAGS="-fsanitize=thread -g -fno-omit-frame-pointer" \
      OTHER_LDFLAGS="-fsanitize=thread" \
      OTHER_SWIFT_FLAGS="-sanitize=thread" \
      GCC_OPTIMIZATION_LEVEL=0 GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
      DEPLOYMENT_POSTPROCESSING=NO STRIP_INSTALLED_PRODUCT=NO \
      SEPARATE_STRIP=NO COPY_PHASE_STRIP=NO

Note that `otool -L | grep sanitizer` finds nothing even on a correct
TSan build; the library is `libclang_rt.tsan_osx_dynamic.dylib`, so
grep for `clang_rt.tsan`.

**Found and fixed: one race introduced by the thread move.**
`EmuThread_Start` called `pthread_create` and only then set
`gThreadStarted`, while the new thread was already reading it from
`EmuThread_IsCurrent`. The stored `pthread_t` had the same defect
without being reported, since `pthread_create` may write its handle
after the thread is running. Both are gone: thread identity is now a
`_Thread_local` marker the thread sets on its own entry, the lock is
initialised through `pthread_once` rather than behind a flag read from
two threads, and `gFinished` is `_Atomic` rather than `volatile`,
which orders nothing.

**Found and fixed: the audio boundary was unsynchronised.** The
first run reported every remaining race between emulator sound state
and CoreAudio's render thread (`HALB_IOThread::DispatchPThread`): the
sample stores into `TheSoundBuffer` from `ASC_SubTick`, and the
`volatile` `TheFillOffset`, `MinFilledSoundBuffs` and `cur_audio`
fields. They were pre-existing (before the thread move the same races
ran between the main thread and the render thread), and `volatile`
orders nothing between threads. There was also a logic race: on
overflow `MySound_BeginWrite` rewound `TheWriteOffset` by a block and
rewrote one already published to the render thread.

Fixed entirely in the host, in the sound section of `OSGLUCCO.m`, with
no change to the core (which only writes inside the span it is handed)
and no lock on the render side:

- `TheFillOffset` and `ThePlayOffset` are `_Atomic`. The producer
  publishes the fill offset with release after the block is written and
  converted; the callback loads it with acquire, copies, and publishes
  the play offset with release; `MySound_BeginWrite` loads that with
  acquire.
- Overflow is decided once per block: if no whole block is free, the
  block is written into a private scratch block (the spare `kOneBuffSz`
  at the end of the allocation, never reached by masked ring accesses)
  and dropped on completion, counted in `SoundBlocksDropped`. Published
  samples are never rewritten.
- `MinFilledSoundBuffs` is updated with a CAS minimum in the callback
  and an atomic exchange in `MySound_SecondNotify0`, so pacing is
  unchanged in effect but no minimum is lost.
- `wantplaying`, `HaveStartedPlaying` and `lastv` are `_Atomic`; the
  stop handshake (clear `wantplaying`, wait for `lastv` to ramp to
  centre) is release/acquire.

Re-run on 2026-10-03: zero TSan reports over about three and a half
minutes booting System 6.0.8, with sound stopped and restarted through
`SpeedStopped` and `RunInBackground` while the run was live. In the
ordinary build the ring was checked with a debugger: offsets advance
in lockstep, and with the output unit stopped by hand the producer
dropped 710 blocks into scratch, then recovered without stalling when
the unit restarted. Audio output itself was not listened to.

**Shutdown under TSan**: `kill -TERM` exits promptly (status 143).
A scripted quit with no disk mounted timed out (-1712), but not in the
sound code: `sample` showed the main thread waiting in
`frameTick` → `EmuLock_Acquire` for the whole run, starved by an
emulator thread that at -O0 under TSan cannot keep up with real time
and so barely releases the lock. The ordinary build quits the same way
with status 0. Lock fairness under load is an `EMUTHRED.m` question and
is left open here.

**Not yet exercised:** `EmuLock_Yield`, the "all out" speed path.
Nothing in the run drove the emulator into that mode, so the one place
the coarse lock is known to cost something remains untested.

## Implementation status

As of 2026-09-17. Everything listed as done builds clean and has been
verified by running the app, not only by compiling it.

**Done:**

| Area | Files |
|---|---|
| Swift support in the generator | `DFFILDEF.i`, `USFILDEF.i`, `WRXCDFLS.i`, `SPBASDEF.i`, `GNBLDOPT.i`, `SPFILDEF.i` |
| Swift / Objective-C / C boundary | `EMUCTLAP.h`, `CCOBRIDG.h`, `EMUBRIDG.swift` |
| Metal renderer replacing OpenGL 1.1 | `MTLRENDR.h`, `MTLRENDR.m` |
| Framework swap, config includes | `USFILDEF.i`, `WRCNFGAP.i` |
| Emulator on its own thread, AppKit owns main | `EMUTHRED.h`, `EMUTHRED.m`, `OSGLUCCO.m` |
| Native menu bar, SwiftUI Settings and About | `APPMENUS.swift`, `SETTINGS.swift`, `ABOUTPNL.swift`, `EMUCTLAP.h`, `EMUBRIDG.swift` |
| `CONTROLM.h` split, overlay deleted | `KEYRMPMC.h`, `ROMVALID.h`, `INTLCHAR.h`, `STRCN*.h`, `SPBLDOPT.i`, `SPCNFGAP.i`, `GNBLDOPT.i`, `SPFILDEF.i` |

The thread move is in place and verified. `main` now runs `[NSApp run]`
for the life of the process; `ProgramMain` runs on a thread named
"minivmac emulator". `WaitForNextTick` only paces and releases the
lock while sleeping. Events arrive through a `MyClassApplication`
override of `sendEvent:`, which takes the lock and asks
`ProcessOneSystemEvent` whether the emulator consumed the event,
passing it to `super` when it did not. `CheckForSavedTasks` and
presentation run on the main thread from a `CADisplayLink` taken from
`NSScreen`, so the link survives the window being recreated.

Verified by running: System 6.0.8 boots and renders in colour with the
emulator off the main thread, `sample` shows the main thread idle in
`[NSApp run]` inside `nextEventMatchingMask`, and a scripted quit exits
with status 0 through the full `UnInitOSGLU` path.

Behaviour change worth knowing: quitting is routed through the
emulator, so `applicationShouldTerminate` returns `NSTerminateCancel`
and asks the emulator to stop; the thread then stops the run loop so
`main` can unwind and clean up. A script that sends a `quit` Apple
Event therefore gets back `-128` (cancelled) even though the
application does quit cleanly.

Two bugs were found and fixed during this work, both worth knowing
about because they are easy to reintroduce:

1. `CloseMainWindow` must **not** tear down the renderer.
   `ReCreateMainWindow` disposes the old window by restoring old
   state, calling `CloseMainWindow`, then restoring new state — so at
   that moment the live renderer already belongs to the *new* view.
   Tearing down there blanks the screen after a magnify or fullscreen
   toggle. Teardown is explicit instead, and the recreation failure
   path re-attaches with `MyGetRenderer()`.
2. For a layer-hosting view the layer must be assigned **before**
   `wantsLayer = YES`, or AppKit treats the view as layer-backed and
   contends for layer ownership.

The chrome is in. The menu bar is Apple / Mini vMac / File / Machine /
View / Window, with Control key equivalents because the guest takes
every Command keystroke. Check marks and enablement are answered in
`validateMenuItem` rather than pushed, since the emulator changes that
state on its own; the Eject submenu is rebuilt in `menuNeedsUpdate`
for the same reason. Settings and About are SwiftUI hosted in
`NSHostingView`, because SwiftUI's `Settings` scene needs the SwiftUI
App lifecycle and AppKit owns this application.

`EMUCTLAP.h` grew from the two probe functions into the real runtime
surface: speed, pause, magnify, full screen, background, auto slow,
reset, interrupt, insert, per drive eject, plus capability queries so
the interface does not offer controls for features this build was
generated without. Every function takes the emulator lock itself, so
the Swift side cannot forget to.

Verified by running: the menu bar enumerates correctly through the
accessibility API, and the Settings window renders with live values
read out of the emulator — it showed 16x, which is the `-speed 4` the
build was generated with.

The overlay is gone. `CONTROLM.h`, `ALTKEYSM.h` and `ACTVCODE.h` are
deleted, and with them the overlay's framebuffer copy
(`CntrlDisplayBuff`), which also leaves `ChooseTotMemSize`. What had to
survive was split out: key remapping into `KEYRMPMC.h`, ROM validation
and the startup wait for a ROM into `ROMVALID.h`. Behaviour changes:

- The host Control key now reaches the guest as its Control key. It
  used to map to `CM`, the key that entered Control Mode. Menu key
  equivalents are still matched in `sendEvent:` first, so only
  unclaimed ⌃ chords reach the guest. `-ccs` now plainly exchanges
  Control and Command.
- Removed setuptool options, each of which only configured the
  overlay: the `-km … CM` destination, `-ekt` (emulated Control toggle
  key), `-eck`, `-eci`, `-ecr`, `-iid`, `-akm` (alternate keyboard
  mode), and the upstream licensing features `-dmo` and `-act`. The
  build scripts pass none of them.
- With no ROM, `WaitForRom` raises an ordinary `MacMsg`, presented as
  an `NSAlert`, telling the user to drop a ROM on the window or use
  File ▸ Open Disk Image…, instead of drawing into the guest screen.
  Verified by running a ROM-less copy: the alert appears, and the
  process exits promptly on `kill`.

`EnableDemoMsg` is still emitted, fixed at 0, only because
`WaitForNextTick` tests it with `#if` under `-Wundef`; it can go once
that test is removed.

**Not done.**

| Area | Files |
|---|---|
| Native fullscreen | `OSGLUCCO.m` |
| `NSAlert`, deprecation sweep, ARC | all |
| Backend split | `HOSTFILE.m`, `SNDCOREA.m` |

A copy of `extras/roms/MacII.ROM` sits at the repository root so the
app can be launched for testing. It is ignored by `.gitignore`
(`/*.ROM`).

## Out of scope

- Changing the emulator configuration model (model, RAM, resolution,
  depth remain compile-time via `setuptool`)
- Rewriting localization to `.strings` catalogs
- GPU-side CLUT conversion (recorded as follow-up)
- Any modification to the portable emulator core
- Non-macOS platforms; this fork is Apple Silicon macOS only

## Known risks

1. **Cross-thread input correctness** is the largest. The ring buffer
   and the modifier-state handoff are where defects will concentrate.
2. **Big-bang integration.** Mitigated, not eliminated, by the early
   checkpoint above.
3. **Generator regressions** affect all future builds, not just this
   one. `build.sh` from clean is the gate.
4. **Audio drift** if the emulator thread is descheduled; CoreAudio
   continues on its own render thread and the existing
   `MySound_SecondNotify` pacing assumes the old cadence.
