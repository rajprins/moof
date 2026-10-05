/*
	EMUTHRED.h

	Copyright (C) 2026 Moof contributors

	You can redistribute this file and/or modify it under the terms
	of version 2 of the GNU General Public License as published by
	the Free Software Foundation.  You should have received a copy
	of the license along with this file; see the file COPYING.

	This file is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	license for more details.
*/

/*
	EMUlator THREaD

	Runs the portable emulator loop on its own thread so that AppKit
	keeps the main thread and its run loop, which SwiftUI requires.

	Synchronisation is one coarse recursive lock rather than a set of
	lock free channels. That is a deliberate choice: the boundary
	between the emulator and the host is wide and crossed every tick.
	CheckForSavedTasks alone reads the view frame, the main screen
	bounds, the mouse location, hides the cursor and can recreate the
	window. Marshalling each of those separately would mean a dozen
	hand written hand offs; one lock covers them all.

	The contract:

	  - The emulator thread holds the lock while computing a tick and
	    releases it while pacing to the next one. At ordinary speeds
	    that leaves the lock free for most of every 16.6 ms.

	  - The main thread must hold the lock for any access to emulator
	    state: keyboard and mouse input, host housekeeping, and
	    reading the converted frame.

	  - AppKit must only ever be touched on the main thread. The
	    emulator thread therefore does no drawing and no windowing; it
	    converts pixels and sets flags, and the main thread acts on
	    them.

	At "all out" speed the emulator never pauses to pace, so it must
	yield the lock periodically or the main thread starves and the
	interface stops responding.
*/

#ifndef EMUTHRED_H
#define EMUTHRED_H

#include <stdbool.h>

/*
	Starts the emulator thread. Call once, from the main thread,
	after the window exists. Returns false if the thread could not
	be created.
*/
extern bool EmuThread_Start(void);

/*
	Asks the emulator loop to finish and waits for the thread to
	exit. Safe to call more than once.
*/
extern void EmuThread_Stop(void);

/* True once the emulator loop has returned. */
extern bool EmuThread_HasFinished(void);

/*
	True when called from the emulator thread. WaitForNextTick needs
	this because it is also reached from WaitForRom during startup,
	which runs on the main thread before the emulator thread exists.
	Releasing the lock there would be releasing a mutex this thread
	does not hold.
*/
extern bool EmuThread_IsCurrent(void);

/*
	Implemented by the backend, which owns the flag the emulator loop
	checks. Declared here so that both sides agree on the prototype.
	Call with the emulator lock held.
*/
extern bool EmuThread_RequestStop(void);

/*
	The emulator lock. Recursive, so a main thread path that already
	holds it may call into code that takes it again.
*/
extern void EmuLock_Acquire(void);
extern void EmuLock_Release(void);

/*
	Takes the lock only if it is free, returning whether it did. A
	true result must be paired with EmuLock_Release like any other
	acquisition. For work that can as well happen on the next frame
	as on this one, so that the main thread need not wait behind a
	tick in progress.
*/
extern bool EmuLock_TryAcquire(void);

/*
	Releases the lock, sleeps for the given time, and takes the lock
	again. For the emulator thread only, which holds the lock exactly
	once while running guest code, so that one release frees it.

	This is the only sanctioned way for the emulator thread to pace:
	a sleep taken with the lock held would stall the main thread for
	its whole duration, and the unlock, sleep, relock order is easy
	to get wrong when written out by hand. A non positive time still
	hands the lock over, it just does not linger.
*/
extern void EmuLock_SleepUnlocked(double seconds);

/*
	Called by the emulator thread around the point where it would
	otherwise hold the lock continuously. Releases and immediately
	reacquires, giving the main thread a chance to run. Needed
	because "all out" speed has no pacing sleep. The same thing as
	EmuLock_SleepUnlocked with the shortest pause that works.
*/
extern void EmuLock_Yield(void);

#endif /* EMUTHRED_H */
