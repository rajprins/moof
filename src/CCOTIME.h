/*
	CCOTIME.h

	Copyright (C) 2012 Paul C. Pratt, SDL by Sam Lantinga and others

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
	TIME for the Cocoa backend

	The monotonic tick clock that paces emulation, then (after
	CCOPRAM.h, which it includes) the wall clock and time zone the
	guest clock needs.

	Not a header in the usual sense: this is a fragment of
	OSGLUCCO.m, #included by it exactly once, in place, so that the
	backend stays a single translation unit. LOCALVAR and LOCALPROC
	are file static and the order of inclusion matters.
*/

/* --- time, date, location --- */

#define dbglog_TimeStuff (0 && dbglog_HAVE)

LOCALVAR ui5b TrueEmulatedTime = 0;

/*
	Two clocks. Pacing uses the monotonic clock, in seconds since an
	arbitrary origin: it is a single kernel call with no Foundation
	object behind it, and it is read on every subtick, so that is
	the one that has to be cheap. It also never jumps when the user
	or NTP adjusts the clock, which the wall clock did. The guest's
	own clock needs the wall clock, which CheckDateTime reads once
	per tick into LatestWallTime.
*/
LOCALVAR double LatestTime;
LOCALVAR double NextTickChangeTime;
LOCALVAR NSTimeInterval LatestWallTime;

#define MyTickDuration (1.0 / 60.14742)

LOCALVAR ui5b NewMacDateInSeconds;

LOCALVAR blnr EmulationWasInterrupted = falseblnr;

LOCALFUNC double MyMonotonicSeconds(void)
{
	return (double)clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
		* (1.0 / 1000000000.0);
}

LOCALPROC UpdateTrueEmulatedTime(void)
{
	double TimeDiff;

	LatestTime = MyMonotonicSeconds();
	TimeDiff = LatestTime - NextTickChangeTime;

	if (TimeDiff >= 0.0) {
		if (TimeDiff > 16 * MyTickDuration) {
			/* emulation interrupted, forget it */
			++TrueEmulatedTime;
			NextTickChangeTime = LatestTime + MyTickDuration;

			EmulationWasInterrupted = trueblnr;
#if dbglog_TimeStuff
			dbglog_writelnNum("emulation interrupted",
				TrueEmulatedTime);
#endif
		} else {
			do {
				++TrueEmulatedTime;
				TimeDiff -= MyTickDuration;
				NextTickChangeTime += MyTickDuration;
			} while (TimeDiff >= 0.0);
		}
	} else if (TimeDiff < (-16 * MyTickDuration)) {
		/*
			Far ahead of schedule. The monotonic clock does not go
			back, so this can only follow MySound_SecondNotify0
			pushing NextTickChangeTime forward many times; treat it
			as the old "clock set back" case and resynchronise.
		*/
#if dbglog_TimeStuff
		dbglog_writeln("clock set back");
#endif

		NextTickChangeTime = LatestTime + MyTickDuration;
	}
}


LOCALVAR ui5b MyDateDelta;

/*
	The wall clock code below calls into the PRAM persistence, which
	in turn needs MyDateDelta from above, so the PRAM fragment is
	included here, between the two halves, to keep the declarations
	in their original order.
*/

#include "CCOPRAM.h"

/* --- wall clock and time zone --- */

/* --- date and time zone --- */

/*
	The host time zone is not fixed for the life of the process: it
	changes twice a year for daylight saving, and whenever the user
	travels or picks another zone. Both have to reach the guest, or
	its clock ends up an hour out until the next launch.

	A change of zone is announced, by
	NSSystemTimeZoneDidChangeNotification on the main thread, which
	sets this flag. A daylight saving transition is not announced at
	all, so the offset is also rechecked once a minute.
*/
LOCALVAR blnr MyTimeZoneCheckWanted = falseblnr;
LOCALVAR ui5b MyTimeZoneCheckMinute = 0;
LOCALVAR id MyTimeZoneObserver = nil;

LOCALPROC MySetTimeZoneDat(void)
{
	NSTimeZone *MyZone = [NSTimeZone localTimeZone];
	ui5b TzOffSet = (ui5b)[MyZone secondsFromGMT];

	/* seconds from 1904 to 2001, the NSDate reference date */
	MyDateDelta = TzOffSet - 1233815296;

#if AutoTimeZone
	CurMacDelta = (TzOffSet & 0x00FFFFFF)
		| (([MyZone isDaylightSavingTime] ? 0x80 : 0) << 24);
#endif
}

/*
	Runs with the emulator lock held, on whichever thread is running
	WaitForNextTick.
*/
LOCALPROC MyCheckTimeZone(void)
{
	ui5b OldDateDelta = MyDateDelta;
#if AutoTimeZone
	ui5b OldMacDelta = CurMacDelta;
#endif
	/* NSTimeZone localTimeZone is autoreleased. */
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	MySetTimeZoneDat();

	[pool release];

	if ((OldDateDelta != MyDateDelta)
#if AutoTimeZone
		|| (OldMacDelta != CurMacDelta)
#endif
		)
	{
		if (MyPRAMActive) {
			EmPRAM_TimeZoneChanged();
		}
	}
}

/*
	Once per tick, not per subtick: this is the one wall clock read
	in the loop. CFAbsoluteTimeGetCurrent counts from the same 2001
	reference date as NSDate and creates no object.
*/
LOCALFUNC blnr CheckDateTime(void)
{
	ui5b NewMinute;

	LatestWallTime = CFAbsoluteTimeGetCurrent();
	NewMinute = ((ui5b)LatestWallTime) / 60;

	if ((! MyPRAMActive) && EmuThread_IsCurrent()) {
		MyPRAM_Restore();
	}

	if (MyTimeZoneCheckWanted || (NewMinute != MyTimeZoneCheckMinute)) {
		MyTimeZoneCheckWanted = falseblnr;
		MyTimeZoneCheckMinute = NewMinute;
		MyCheckTimeZone();
	}

	NewMacDateInSeconds = ((ui5b)LatestWallTime) + MyDateDelta;
	if (CurMacDateInSeconds != NewMacDateInSeconds) {
		CurMacDateInSeconds = NewMacDateInSeconds;
		MyPRAM_SaveIfChanged();
		return trueblnr;
	} else {
		return falseblnr;
	}
}

LOCALPROC StartUpTimeAdjust(void)
{
	LatestTime = MyMonotonicSeconds();
	NextTickChangeTime = LatestTime;
}

LOCALFUNC blnr InitLocationDat(void)
{
	/*
		CurMacLatitude and CurMacLongitude stay 0. macOS gives no
		coordinates without Core Location, which would mean asking
		for location permission just to fill in the Map control
		panel, so the guest's default location is left alone.
	*/

	MySetTimeZoneDat();
	LatestWallTime = CFAbsoluteTimeGetCurrent();
	MyTimeZoneCheckMinute = ((ui5b)LatestWallTime) / 60;
	NewMacDateInSeconds = ((ui5b)LatestWallTime) + MyDateDelta;
	CurMacDateInSeconds = NewMacDateInSeconds;
	StartUpTimeAdjust();

	/*
		NSTimeZone caches the system zone, so the cache is dropped
		before the emulator thread is asked to look again.
	*/
	MyTimeZoneObserver = [[[NSNotificationCenter defaultCenter]
		addObserverForName: NSSystemTimeZoneDidChangeNotification
		object: nil
		queue: [NSOperationQueue mainQueue]
		usingBlock: ^(NSNotification *note) {
			(void) note;
			EmuLock_Acquire();
			[NSTimeZone resetSystemTimeZone];
			MyTimeZoneCheckWanted = trueblnr;
			EmuLock_Release();
		}] retain];

	MyPRAM_Init();

	return trueblnr;
}

/*
	The one teardown call for this section, from UnInitOSGLU, after
	the emulator thread has stopped: saves the PRAM a last time and
	stops listening for zone changes.
*/
LOCALPROC UnInitLocationDat(void)
{
	MyPRAM_UnInit();

	if (nil != MyTimeZoneObserver) {
		[[NSNotificationCenter defaultCenter]
			removeObserver: MyTimeZoneObserver];
		[MyTimeZoneObserver release];
		MyTimeZoneObserver = nil;
	}
}
