/*
	OSGLUCCO.m

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
	Operating System GLUe for mac os CoCOa

	All operating system dependent code for the
	Mac OS Cocoa should go here.

	Originally derived from Cocoa port of SDL Library
	by Sam Lantinga (but little trace of that remains).
*/

#include "OSGCOMUI.h"
#include "OSGCOMUD.h"

#ifdef WantOSGLUCCO

/* --- adapting to API/ABI version differences --- */

/*
	Everything that used to be looked up dynamically through CFBundle
	here -- CFURLCopyResourcePropertyForKey, kCFURLIsAliasFileKey,
	kCFURLIsSymbolicLinkKey, CFURLCreateBookmarkDataFromFile,
	CFURLCreateByResolvingBookmarkData, CGCursorIsVisible and
	SetSystemUIMode -- predates the macOS 11 floor of Apple Silicon,
	so it is now called directly.
*/



/* --- some simple utilities --- */

GLOBALOSGLUPROC MyMoveBytes(anyp srcPtr, anyp destPtr, si5b byteCount)
{
	(void) memcpy((char *)destPtr, (char *)srcPtr, byteCount);
}

/* --- internationalization --- */

#define NeedCell2UnicodeMap 1
#define NeedRequestInsertDisk 1

#include "INTLCHAR.h"

/* --- sending debugging info to file --- */

LOCALVAR NSString *myAppName = nil;
LOCALVAR NSString *MyDataPath = nil;

#if dbglog_HAVE

#define dbglog_ToStdErr 0

#if ! dbglog_ToStdErr
LOCALVAR FILE *dbglog_File = NULL;
#endif

LOCALFUNC blnr dbglog_open0(void)
{
#if dbglog_ToStdErr
	return trueblnr;
#else
	NSString *myLogPath = [MyDataPath
		stringByAppendingPathComponent: @"dbglog.txt"];
	const char *path = [myLogPath fileSystemRepresentation];

	dbglog_File = fopen(path, "w");
	return (NULL != dbglog_File);
#endif
}

LOCALPROC dbglog_write0(char *s, uimr L)
{
#if dbglog_ToStdErr
	(void) fwrite(s, 1, L, stderr);
#else
	if (NULL != dbglog_File) {
		(void) fwrite(s, 1, L, dbglog_File);
	}
#endif
}

LOCALPROC dbglog_close0(void)
{
#if ! dbglog_ToStdErr
	if (NULL != dbglog_File) {
		fclose(dbglog_File);
		dbglog_File = NULL;
	}
#endif
}

#endif

/* --- information about the environment --- */

#define WantColorTransValid 1

#include "COMOSGLU.h"

#include "PBUFSTDC.h"

#include "KEYRMPMC.h"
#include "ROMVALID.h"

/*
	Used to live in the Control Mode overlay, whose speed screen was
	one of its two callers. The Speed menu, through EMUCTLAP.h, is
	the other and keeps it.
*/
LOCALPROC SetSpeedValue(ui3b i)
{
	SpeedValue = i;
}

/* --- swift bridge --- */

#include "EMUCTLAP.h"
#import "MTLRENDR.h"
#import "EMUTHRED.h"
#import "EmuBridge-Swift.h"

/*
	Implementation of the narrow C surface declared in EMUCTLAP.h.

	These live here because the emulator globals they touch are part
	of this translation unit, reached through the unity build
	includes above.

	Each one takes the emulator lock, so the Swift side cannot forget
	to. The lock is recursive, so being called from a main thread
	path that already holds it, such as the display link handler, is
	fine.
*/

bool MNVM_HasMagnify(void)
{
#if EnableMagnify
	return true;
#else
	return false;
#endif
}

bool MNVM_HasFullScreen(void)
{
#if VarFullScreen
	return true;
#else
	return false;
#endif
}

bool MNVM_HasSound(void)
{
#if MySoundEnabled
	return true;
#else
	return false;
#endif
}

int MNVM_GetSpeedValue(void)
{
	int v;

	EmuLock_Acquire();
	v = ((ui3b) -1 == SpeedValue)
		? kMNVMSpeedAllOut
		: (int) SpeedValue;
	EmuLock_Release();

	return v;
}

void MNVM_PostSetSpeedValue(int v)
{
	EmuLock_Acquire();
	SetSpeedValue((kMNVMSpeedAllOut == v) ? (ui3b) -1 : (ui3b) v);
	EmuLock_Release();
}

bool MNVM_GetSpeedStopped(void)
{
	bool v;

	EmuLock_Acquire();
	v = SpeedStopped ? true : false;
	EmuLock_Release();

	return v;
}

void MNVM_PostSetSpeedStopped(bool v)
{
	EmuLock_Acquire();
	SpeedStopped = v ? trueblnr : falseblnr;
	EmuLock_Release();
}

bool MNVM_GetMagnify(void)
{
	bool v = false;

#if EnableMagnify
	EmuLock_Acquire();
	v = WantMagnify ? true : false;
	EmuLock_Release();
#endif

	return v;
}

void MNVM_PostSetMagnify(bool v)
{
#if EnableMagnify
	EmuLock_Acquire();
	WantMagnify = v ? trueblnr : falseblnr;
	EmuLock_Release();
#else
	(void) v;
#endif
}

bool MNVM_GetFullScreen(void)
{
	bool v = false;

#if VarFullScreen
	EmuLock_Acquire();
	v = WantFullScreen ? true : false;
	EmuLock_Release();
#endif

	return v;
}

void MNVM_PostSetFullScreen(bool v)
{
#if VarFullScreen
	EmuLock_Acquire();
	WantFullScreen = v ? trueblnr : falseblnr;
	EmuLock_Release();
#else
	(void) v;
#endif
}

bool MNVM_GetRunInBackground(void)
{
	bool v;

	EmuLock_Acquire();
	v = RunInBackground ? true : false;
	EmuLock_Release();

	return v;
}

void MNVM_PostSetRunInBackground(bool v)
{
	EmuLock_Acquire();
	RunInBackground = v ? trueblnr : falseblnr;
	EmuLock_Release();
}

/*
	Reported the way a person would expect it: on means the emulator
	is allowed to slow down when the guest is idle. The emulator
	stores the inverse.
*/
bool MNVM_GetAutoSlow(void)
{
	bool v;

	EmuLock_Acquire();
	v = WantNotAutoSlow ? false : true;
	EmuLock_Release();

	return v;
}

void MNVM_PostSetAutoSlow(bool v)
{
	EmuLock_Acquire();
	WantNotAutoSlow = v ? falseblnr : trueblnr;
	EmuLock_Release();
}

void MNVM_PostReset(void)
{
	EmuLock_Acquire();
	WantMacReset = trueblnr;
	EmuLock_Release();
}

void MNVM_PostInterrupt(void)
{
	EmuLock_Acquire();
	WantMacInterrupt = trueblnr;
	EmuLock_Release();
}

void MNVM_PostInsertDisk(void)
{
	EmuLock_Acquire();
#if NeedRequestInsertDisk
	RequestInsertDisk = trueblnr;
#endif
	EmuLock_Release();
}

void MNVM_PostQuit(void)
{
	EmuLock_Acquire();
	RequestMacOff = trueblnr;
	EmuLock_Release();
}

int MNVM_GetDriveCount(void)
{
	return (int) NumDrives;
}

bool MNVM_GetDriveInserted(int driveNo)
{
	bool v = false;

	if ((driveNo >= 0) && (driveNo < (int) NumDrives)) {
		EmuLock_Acquire();
		v = vSonyIsInserted((tDrive) driveNo) ? true : false;
		EmuLock_Release();
	}

	return v;
}

bool MNVM_GetAnyDriveInserted(void)
{
	bool v;

	EmuLock_Acquire();
	v = AnyDiskInserted() ? true : false;
	EmuLock_Release();

	return v;
}

/*
	Defined in SONYEMDV.c, a separate translation unit, so declared by
	hand as GLOBGLUE.c does for Sony_SetQuitOnEject. Calling vSonyEject
	directly would close the image while the disk driver still counted
	the drive as mounted.
*/
IMPORTPROC Sony_EjectDriveFromHost(tDrive Drive_No);

void MNVM_PostEjectDrive(int driveNo)
{
	if ((driveNo >= 0) && (driveNo < (int) NumDrives)) {
		EmuLock_Acquire();
		Sony_EjectDriveFromHost((tDrive) driveNo);
		EmuLock_Release();
	}
}

IMPORTFUNC blnr Sony_IsDriveMountedByGuest(tDrive Drive_No);

bool MNVM_GetDriveMountedByGuest(int driveNo)
{
	bool v = false;

	if ((driveNo >= 0) && (driveNo < (int) NumDrives)) {
		EmuLock_Acquire();
		v = Sony_IsDriveMountedByGuest((tDrive) driveNo)
			? true : false;
		EmuLock_Release();
	}

	return v;
}

/* MNVM_CopyDriveName is with the drives, below DriveNames. */

/*
	Asks the emulator loop to leave, using the flag the loop already
	checks rather than introducing a second mechanism. Called by
	EMUTHRED while holding the emulator lock.
*/
bool EmuThread_RequestStop(void)
{
	ForceMacOff = trueblnr;

	return true;
}

#include "CCOTEXT.h"

#include "CCODISKS.h"

#include "CCOCLIP.h"

#if EmLocalTalk
LOCALFUNC blnr EntropyGather(void)
{
	/*
		gather some entropy from several places. the system random
		source below should make these irrelevant, but they cost
		nothing and keep e_p varied even if it were broken.
	*/

	{
		NSTimeInterval v = [NSDate timeIntervalSinceReferenceDate];

		EntropyPoolAddPtr((ui3p)&v, sizeof(v) / sizeof(ui3b));
	}

	{
		NSPoint p = [NSEvent mouseLocation];

		EntropyPoolAddPtr((ui3p)&p, sizeof(p) / sizeof(ui3b));
	}

	{
		uimr t = [[NSProcessInfo processInfo] processIdentifier];

		EntropyPoolAddPtr((ui3p)&t, sizeof(t) / sizeof(ui3b));
	}

	{
		ui5b dat[2];

		/*
			arc4random_buf is in libc on every macOS version and
			cannot fail, unlike opening and reading /dev/urandom,
			which needs a file descriptor and can be refused (for
			instance by a sandbox profile). It draws from the same
			kernel generator.
		*/
		arc4random_buf(dat, sizeof(dat));

#if dbglog_HAVE
		dbglog_writeCStr("dat: ");
		dbglog_writeHex(dat[0]);
		dbglog_writeCStr(" ");
		dbglog_writeHex(dat[1]);
		dbglog_writeReturn();
#endif

		e_p[0] ^= dat[0];
		e_p[1] ^= dat[1];
			/*
				if arc4random_buf is working correctly,
				this should make the previous contents of e_p
				irrelevant. if it is completely broken, like
				returning 0, this will not make e_p any less
				random.
			*/

#if dbglog_HAVE
		dbglog_writeCStr("ep: ");
		dbglog_writeHex(e_p[0]);
		dbglog_writeCStr(" ");
		dbglog_writeHex(e_p[1]);
		dbglog_writeReturn();
#endif
	}

	return trueblnr;
}
#endif

#if EmLocalTalk

#include "LOCALTLK.h"

#endif

#include "CCOINPUT.h"

#include "CCOVIDEO.h"

#include "CCOTIME.h"
	/* includes CCOPRAM.h part way through; see the note there */

#include "CCOSOUND.h"

/* --- video out --- */


/*
	Converts and hands off the changed rectangle, if there is one.
	ScreenClearChanges leaves the rectangle empty, Bottom below Top,
	so a tick in which nothing on the guest screen changed costs
	nothing here and no frame is marked ready.

	This used to be gated on [MyNSview canDraw], which was right for
	a view that drew through drawRect but is wrong for a layer
	hosting Metal view, and is deprecated as of macOS 10.14 for
	exactly that reason. canDraw answers NO while the window is not
	yet visible or is occluded. Since Metal presents through the
	layer rather than through AppKit's drawing machinery, that gate
	simply dropped frames: the window stayed black whenever drawing
	began before it came to the front. MyDrawWithMetal already
	declines to draw when there is no renderer, so no further check
	is needed here.
*/
LOCALPROC MyDrawChangesAndClear(void)
{
	if (ScreenChangedBottom > ScreenChangedTop) {
		MyDrawWithMetal(ScreenChangedTop, ScreenChangedLeft,
			ScreenChangedBottom, ScreenChangedRight);
		ScreenClearChanges();
	}
}

GLOBALOSGLUPROC DoneWithDrawingForTick(void)
{
#if EnableFSMouseMotion
	if (HaveMouseMotion) {
		AutoScrollScreen();
	}
#endif
	MyDrawChangesAndClear();
}

/* --- keyboard input --- */

LOCALPROC DisconnectKeyCodes3(void)
{
	DisconnectKeyCodes2();
	MyMouseButtonSet(falseblnr);
}

#include "CCODIALG.h"

#include "CCOWINDW.h"

LOCALVAR blnr CursorCheckWanted = trueblnr;
LOCALVAR unsigned int CursorCheckCounter = 0;

LOCALPROC MyCheckCursorVisible(void);

LOCALPROC CheckForSavedTasks(void)
{
	if (MyEvtQNeedRecover) {
		MyEvtQNeedRecover = falseblnr;

		/* attempt cleanup, MyEvtQNeedRecover may get set again */
		MyEvtQTryRecoverFromFull();
	}

	if (RequestMacOff) {
		RequestMacOff = falseblnr;
		if (AnyDiskInserted()) {
			MacMsgOverride(kStrQuitWarningTitle,
				kStrQuitWarningMessage);
		} else {
			ForceMacOff = trueblnr;
		}
	}

	if (ForceMacOff) {
		return;
	}

	if (gTrueBackgroundFlag != gBackgroundFlag) {
		gBackgroundFlag = gTrueBackgroundFlag;
		if (gTrueBackgroundFlag) {
			EnterBackground();
		} else {
			LeaveBackground();
		}
		CursorCheckWanted = trueblnr;
	}

	if (EmulationWasInterrupted) {
		EmulationWasInterrupted = falseblnr;

		if (! gTrueBackgroundFlag) {
			CheckMouseState();
		}
	}

#if EnableFSMouseMotion
	if (HaveMouseMotion) {
		MyMouseConstrain();
	}
#endif

#if VarFullScreen
	if (gTrueBackgroundFlag && WantFullScreen) {
		ToggleWantFullScreen();
	}
#endif

	if (WantScreensChangedCheck) {
		WantScreensChangedCheck = falseblnr;

		MyUpdateRendererGeometry();

#if VarFullScreen
		/*
			triggered on enter full screen for some
			reason in OS X 10.11. so check against
			saved rect.
		*/
		if ((WantFullScreen)
			&& (! NSEqualRects(SavedScrnBounds,
				[[NSScreen mainScreen] frame])))
		{
			ToggleWantFullScreen();
		}
#endif
	}

	if (CurSpeedStopped != (SpeedStopped ||
		(gBackgroundFlag && ! RunInBackground)))
	{
		CurSpeedStopped = ! CurSpeedStopped;
		if (CurSpeedStopped) {
			EnterSpeedStopped();
		} else {
			LeaveSpeedStopped();
		}
	}

	/*
		Messages are presented as a native alert rather than by
		entering the overlay's message special mode. This is what
		lets the drawn overlay go: SpclModeMessage and SpclModeNoRom
		are the two non overlay users of the special mode
		framebuffer indirection in GetCurDrawBuff, and this removes
		the first of them.
	*/
	CheckSavedMacMsg(trueblnr);

#if EnableRecreateW
	if (0
#if EnableMagnify
		|| (UseMagnify != WantMagnify)
#endif
#if VarFullScreen
		|| (UseFullScreen != WantFullScreen)
#endif
		)
	{
		ReCreateMainWindow();
	}
#endif

#if MayFullScreen
	if (GrabMachine != (
#if VarFullScreen
		UseFullScreen &&
#endif
		! (gTrueBackgroundFlag || CurSpeedStopped)))
	{
		GrabMachine = ! GrabMachine;
		AdjustMachineGrab();
	}
#endif

#if IncludeSonyNew
	if (vSonyNewDiskWanted) {
#if IncludeSonyNameNew
		if (vSonyNewDiskName != NotAPbuf) {
			NSString *sNewDiskName;
			if (MacRomanFileNameToNSString(vSonyNewDiskName,
				&sNewDiskName))
			{
				MakeNewDisk(vSonyNewDiskSize, sNewDiskName);
			}
			PbufDispose(vSonyNewDiskName);
			vSonyNewDiskName = NotAPbuf;
		} else
#endif
		{
			MakeNewDiskAtDefault(vSonyNewDiskSize);
		}
		vSonyNewDiskWanted = falseblnr;
			/* must be done after may have gotten disk */
	}
#endif

	if (! gTrueBackgroundFlag) {
		if (RequestInsertDisk) {
			RequestInsertDisk = falseblnr;
			InsertADisk0();
		}
	}

	if (HaveCursorHidden != (
#if MayNotFullScreen
		(WantCursorHidden
#if VarFullScreen
			|| UseFullScreen
#endif
		) &&
#endif
		! (gTrueBackgroundFlag || CurSpeedStopped)))
	{
		HaveCursorHidden = ! HaveCursorHidden;
		if (HaveCursorHidden) {
			MyHideCursor();
		} else {
			MyShowCursor();
		}
		CursorCheckWanted = trueblnr;
	}

	/*
		Check if actual cursor visibility is what it should be.
		If move mouse to dock then cursor is made visible, but then
		if move directly to our window, cursor is not hidden again.

		CGCursorIsVisible is a window server round trip, so it is
		not asked every frame: only when the hidden state or the key
		window state has just changed, and otherwise every fifteenth
		frame, which is still a quarter of a second at most for the
		Dock case above to be put right.
	*/
	if (CursorCheckWanted || (0 == (++CursorCheckCounter % 15))) {
		CursorCheckWanted = falseblnr;
		MyCheckCursorVisible();
	}
}

/*
	The CGCursorIsVisible part of CheckForSavedTasks, above.
*/
LOCALPROC MyCheckCursorVisible(void)
{
	/*
		CGCursorIsVisible has been deprecated since 10.9 with no
		replacement, and is kept deliberately. Nothing else reports
		whether the cursor is actually showing: NSCursor only
		counts hide and unhide calls, and that count is exactly what
		the Dock gets out of step with. The alternative would be to
		stop hiding the cursor and instead give the view a blank
		cursor through cursor rects, which AppKit reapplies on every
		entry. That reworks how the cursor is hidden in full screen
		and while grabbing the mouse, and cannot be checked without
		driving the real pointer over the Dock, so it is left for a
		change that can be tested that way. The function still
		works, so only the warning is silenced, here alone.
	*/
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	if (CGCursorIsVisible()) {
		if (HaveCursorHidden) {
			MyHideCursor();
			if (CGCursorIsVisible()) {
				/*
					didn't work, attempt undo so that
					hide cursor count won't get large
				*/
				MyShowCursor();
			}
		}
	} else {
		if (! HaveCursorHidden) {
			MyShowCursor();
			/*
				don't check if worked, assume can't decrement
				hide cursor count below 0
			*/
		}
	}
#pragma clang diagnostic pop
}

/* --- main program flow --- */

GLOBALOSGLUFUNC blnr ExtraTimeNotOver(void)
{
	UpdateTrueEmulatedTime();
	return TrueEmulatedTime == OnTrueTime;
}

#include "CCOEVENT.h"

/*
	Paces the emulator to the next tick.

	This used to do two jobs: pump AppKit events and pace. It now
	only paces. Events are delivered by AppKit on the main thread,
	and the host housekeeping that CheckForSavedTasks performs also
	runs on the main thread, because it touches AppKit.

	The emulator lock is released while sleeping, which is most of
	every tick at ordinary speeds, and that is when the main thread
	gets to run. At "all out" speed there is no sleep, so the lock
	has to be yielded explicitly or the interface would stop
	responding.

	Reached from WaitForRom during startup as well, which runs on the
	main thread before the emulator thread exists, hence the
	EmuThread_IsCurrent guard around every lock operation.
*/

/*
	What WaitForNextTick does instead of sleeping when reached on the
	main thread, which only happens from WaitForRom during startup.

	At that point [NSApp run] has already returned and the frame
	driver has not been started, so nothing else delivers events,
	runs the host housekeeping or presents a frame. A bare sleep here
	left the application unable to accept a dropped ROM, to quit, or
	even to notice a ROM it had loaded: WaitForRom waits for
	SpeedStopped to clear, but this function keeps waiting until
	CheckForSavedTasks updates CurSpeedStopped, and nothing called it.

	There is no emulator thread yet, so the lock is free and is taken
	only by the paths that take it themselves.
*/
LOCALPROC MyIdleOnMainThread(double seconds)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSEvent *event;

	CheckForSavedTasks();
	if (MyUploadPendingFrame()) {
		MyDrawUploadedFrame();
	}

	event = [NSApp nextEventMatchingMask: NSEventMaskAny
		untilDate: [NSDate dateWithTimeIntervalSinceNow: seconds]
		inMode: NSDefaultRunLoopMode
		dequeue: YES];
	if (nil != event) {
		[NSApp sendEvent: event];
	}

	[pool release];
}

/*
	No autorelease pool of its own: the only Objective-C objects
	made on this path are inside MyIdleOnMainThread and
	MyCheckTimeZone, which each have one. Making and draining a pool
	every tick was a measurable share of an idle tick.
*/
GLOBALOSGLUPROC WaitForNextTick(void)
{
	blnr onEmuThread = EmuThread_IsCurrent();
	blnr releasedLock = falseblnr;

label_retry:

	if (ForceMacOff) {
		goto label_exit;
	}

	if (CurSpeedStopped) {
		/*
			No tick runs while stopped, so nothing records new
			changes, and a frame converted before the pause is
			already waiting in ScalingBuff for the main thread to
			present. The one thing left to pick up is a
			ScreenChangedAll from a geometry change while paused,
			so the changed rectangle is converted only when it is
			not empty, which MyDrawChangesAndClear checks for.
			Converting the whole screen every 10 ms, as this used
			to, was most of a paused emulator's CPU time.

			Nothing to compute otherwise. The old code blocked on
			the event queue until something arrived; now it simply
			idles, leaving the lock free so the main thread can act
			on whatever the user does next.
		*/
		MyDrawChangesAndClear();

		if (onEmuThread) {
			EmuLock_SleepUnlocked(0.010);
			releasedLock = trueblnr;
		} else {
			MyIdleOnMainThread(0.010);
		}
		goto label_retry;
	}

	if (ExtraTimeNotOver()) {
		double inTimeout = NextTickChangeTime - LatestTime;

		if (inTimeout > 0.0) {
			if (onEmuThread) {
				EmuLock_SleepUnlocked(inTimeout);
				releasedLock = trueblnr;
			} else {
				MyIdleOnMainThread(inTimeout);
			}
		} else if (onEmuThread) {
			/*
				Behind schedule, or running all out. There is no
				sleep to hide behind, so hand the lock over
				briefly on purpose.
			*/
			EmuLock_Yield();
			releasedLock = trueblnr;
		}
		goto label_retry;
	}

	/*
		A tick that is already due returns straight from the first
		test above without ever releasing the lock. When emulation
		cannot keep up with real time -- a slow host, a debug or
		Thread Sanitizer build -- every tick is already due, so the
		main thread would never get the lock again: no events, no
		frames, and a quit that waits forever. Yield once per tick
		whenever this call has not already let go.
	*/
	if (onEmuThread && ! releasedLock) {
		EmuLock_Yield();
	}

	if (CheckDateTime()) {
#if MySoundEnabled
		MySound_SecondNotify();
#endif
	}

	OnTrueTime = TrueEmulatedTime;

#if dbglog_TimeStuff
	dbglog_writelnNum("WaitForNextTick, OnTrueTime", OnTrueTime);
#endif

label_exit:
	;
}

LOCALFUNC blnr setupWorkingDirectory(void)
{
	NSString *myAppDir;
	NSString *contentsPath;
	NSString *dataPath;
	NSBundle *myBundle = [NSBundle mainBundle];
	NSString *myAppPath = [myBundle bundlePath];

	myAppDir = [myAppPath stringByDeletingLastPathComponent];
	myAppName = [[[myAppPath lastPathComponent]
		stringByDeletingPathExtension] retain];

	MyDataPath = myAppDir;
	if (FindNamedChildDirPath(myAppPath, "Contents", &contentsPath))
	if (FindNamedChildDirPath(contentsPath, "mnvm_dat", &dataPath))
	{
		MyDataPath = dataPath;
	}
	[MyDataPath retain];

	return trueblnr;
}

@interface MyClassApplicationDelegate : NSObject <NSApplicationDelegate>
@end

@implementation MyClassApplicationDelegate

- (BOOL)application:(NSApplication *)theApplication
	openFile:(NSString *)filename
{
	(void) Sony_Insert1a(filename);

	return TRUE;
}

- (void) applicationDidFinishLaunching: (NSNotification *) note
{
	[NSApp stop: nil]; /* stop immediately */

	{
		/*
			doesn't actually stop until an event, so make one.
			(As suggested by Michiel de Hoon in
			http://www.cocoabuilder.com/ post.)
		*/
		NSEvent* event = [NSEvent
			otherEventWithType: NSEventTypeApplicationDefined
			location: NSMakePoint(0, 0)
			modifierFlags: 0
			timestamp: 0.0
			windowNumber: 0
			context: nil
			subtype: 0
			data1: 0
			data2: 0];
		[NSApp postEvent: event atStart: true];
	}
}

- (void)applicationDidChangeScreenParameters:
	(NSNotification *)aNotification
{
	WantScreensChangedCheck = trueblnr;
}

/*
	Quit has to go through the emulator rather than around it, or the
	loop would be killed mid tick and UnInitOSGLU would never run.
	So a quit request asks the emulator to stop and cancels the
	termination; the emulator thread then stops the run loop once it
	has actually left, and main unwinds and cleans up.
*/
- (NSApplicationTerminateReply)applicationShouldTerminate:
	(NSApplication *)sender
{
	(void) sender;

	if (EmuThread_HasFinished()) {
		return NSTerminateNow;
	}

	/*
		Ask, rather than force: quit at once when no disk image is
		inserted, and otherwise warn that the emulated computer
		should be shut down first. Forcing here skipped that warning
		and risked corrupting mounted images. Without a ROM there is
		no emulated computer to shut down, so that case still quits
		straight away.

		This is what CheckForSavedTasks does for RequestMacOff, done
		here directly rather than by setting that flag. The flag is
		only noticed when the display link next fires, and a quit
		request often arrives while the application is in the
		background, which is exactly when the system may be
		throttling it: an Apple Event wakes the application long
		enough to run this, and then nothing ran CheckForSavedTasks,
		so the warning did not appear until something else -- such
		as a second quit request -- woke it again. The alert itself
		is still presented on a later turn of the run loop by
		CheckSavedMacMsg, which a dispatched block guarantees
		regardless of the display link, and which also keeps a
		modal session out of the Apple Event handler.

		A message already on screen or waiting to be shown is left
		alone, so repeating the request does not stack up copies of
		the warning.
	*/
	EmuLock_Acquire();
	if (! ROM_loaded) {
		(void) EmuThread_RequestStop();
	} else if (! AnyDiskInserted()) {
		ForceMacOff = trueblnr;
	} else if ((nullpr == SavedBriefMsg) && ! PresentingMacMsg) {
		MacMsgOverride(kStrQuitWarningTitle, kStrQuitWarningMessage);
		CheckSavedMacMsg(trueblnr);
	}
	EmuLock_Release();

	return NSTerminateCancel;
}

@end

/*
	Drives the host side of each frame from the main thread: the
	housekeeping that CheckForSavedTasks performs, which touches
	AppKit and so cannot run on the emulator thread, and then
	presentation of whatever frame the emulator has converted.

	A display link is used rather than a timer so that presentation
	is aligned to the refresh the window is actually on.
*/

@interface MyClassFrameDriver : NSObject
- (void)frameTick:(id)sender;
@end

@implementation MyClassFrameDriver

/*
	How many frames in a row the lock may be found busy before this
	thread blocks for it. At ordinary speed the lock is free for most
	of each tick, so this is rarely reached, but at "all out" speed
	the emulator holds it almost continuously, and without a bound
	the housekeeping in CheckForSavedTasks could go unrun.
*/
#define kFrameTickMaxSkips 8

LOCALVAR int FrameTickSkips = 0;

- (void)frameTick:(id)sender
{
	blnr haveFrame;

	(void) sender;

	/*
		If the emulator thread is in the middle of a tick, waiting
		for it would stall the main thread for the rest of that
		tick. Nothing done here is urgent: the frame can be drawn on
		the next refresh, and the housekeeping checks flags that
		stay set. So the frame is skipped when the lock is busy, up
		to a limit.
	*/
	if (! EmuLock_TryAcquire()) {
		if (++FrameTickSkips < kFrameTickMaxSkips) {
			return;
		}
		EmuLock_Acquire();
	}
	FrameTickSkips = 0;

	CheckForSavedTasks();
	haveFrame = MyUploadPendingFrame();

	EmuLock_Release();

	/*
		GPU work after the lock is let go, so the emulator thread is
		not held up by it. The texture is this thread's own once the
		upload has returned.
	*/
	if (haveFrame) {
		MyDrawUploadedFrame();
	}
}

@end

LOCALVAR MyClassFrameDriver *MyFrameDriver = nil;
LOCALVAR CADisplayLink *MyFrameLink = nil;

LOCALFUNC blnr MyStartFrameDriver(void)
{
	if (nil != MyFrameLink) {
		return trueblnr;
	}

	MyFrameDriver = [[MyClassFrameDriver alloc] init];

	/*
		Taken from the screen rather than the view, so that it
		survives the window being recreated on a magnify or full
		screen toggle.
	*/
	MyFrameLink = [[[NSScreen mainScreen]
		displayLinkWithTarget: MyFrameDriver
		selector: @selector(frameTick:)] retain];

	if (nil == MyFrameLink) {
		NSLog(@"could not create display link");
		return falseblnr;
	}

	[MyFrameLink addToRunLoop: [NSRunLoop mainRunLoop]
		forMode: NSRunLoopCommonModes];

	return trueblnr;
}

LOCALPROC MyStopFrameDriver(void)
{
	if (nil != MyFrameLink) {
		[MyFrameLink invalidate];
		[MyFrameLink release];
		MyFrameLink = nil;
	}
	if (nil != MyFrameDriver) {
		[MyFrameDriver release];
		MyFrameDriver = nil;
	}
}

LOCALVAR MyClassApplicationDelegate *MyApplicationDelegate = nil;

LOCALFUNC blnr InitCocoaStuff(void)
{
	NSApplication *MyNSApp = [MyClassApplication sharedApplication];
		/*
			in Xcode 6.2, MyNSApp isn't the same as NSApp,
			breaks NSApp setDelegate
		*/

	/*
		The menu bar is built in Swift, in APPMENUS.swift. What used
		to be here was a three item stub -- application, File with
		one Open item, and Special whose only entry dropped into the
		character cell overlay -- because almost every command lived
		in that overlay rather than in the menu bar.
	*/
	[MNVMMenuController installMainMenu];

	MyApplicationDelegate = [[MyClassApplicationDelegate alloc] init];
	[MyNSApp setDelegate: MyApplicationDelegate];

	[MyNSApp run];
		/*
			our applicationDidFinishLaunching forces immediate
			halt. finishLaunching would do instead, but then after
			a Hide command, activating from the Dock did not bring
			the window forward (as noted by Hugues De Keyzer on the
			SDL forums).
		*/

	return trueblnr;
}

LOCALPROC UnInitCocoaStuff(void)
{
	if (nil != MyApplicationDelegate) {
		[MyApplicationDelegate release];
	}
	if (nil != myAppName) {
		[myAppName release];
	}
	if (nil != MyDataPath) {
		[MyDataPath release];
	}
}

/* --- platform independent code can be thought of as going here --- */

#include "PROGMAIN.h"

LOCALPROC ZapOSGLUVars(void)
{
	InitDrives();
	ZapWinStateVars();
#if MySoundEnabled
	ZapAudioVars();
#endif
}

LOCALPROC ReserveAllocAll(void)
{
#if dbglog_HAVE
	dbglog_ReserveAlloc();
#endif
	ReserveAllocOneBlock(&ROM, kROM_Size, 5, falseblnr);

	ReserveAllocOneBlock(&screencomparebuff,
		vMacScreenNumBytes, 5, trueblnr);

	ReserveAllocOneBlock(&ScalingBuff, vMacScreenNumPixels
#if 0 != vMacScreenDepth
		* 4
#endif
		, 5, falseblnr);
	ReserveAllocOneBlock(&CLUT_final, CLUT_finalsz, 5, falseblnr);

#if MySoundEnabled
	ReserveAllocOneBlock((ui3p *)&TheSoundBuffer,
		dbhBufferSize, 5, falseblnr);
#endif

	EmulationReserveAlloc();
}

LOCALFUNC blnr AllocMyMemory(void)
{
	uimr n;
	blnr IsOk = falseblnr;

	ReserveAllocOffset = 0;
	ReserveAllocBigBlock = nullpr;
	ReserveAllocAll();
	n = ReserveAllocOffset;
	ReserveAllocBigBlock = (ui3p)calloc(1, n);
	if (NULL == ReserveAllocBigBlock) {
		MacMsg(kStrOutOfMemTitle, kStrOutOfMemMessage, trueblnr);
	} else {
		ReserveAllocOffset = 0;
		ReserveAllocAll();
		if (n != ReserveAllocOffset) {
			/* oops, program error */
		} else {
			IsOk = trueblnr;
		}
	}

	return IsOk;
}

LOCALPROC UnallocMyMemory(void)
{
	if (nullpr != ReserveAllocBigBlock) {
		free((char *) ReserveAllocBigBlock);
	}
}

LOCALFUNC blnr InitOSGLU(void)
{
	blnr IsOk = falseblnr;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	InitKeyCodes();
		/*
			Was the whole of Screen_Init, which it had nothing to do
			with. Order does not matter: it only zeroes the key map,
			which nothing reads before the first event.
		*/

	if (AllocMyMemory())
	if (setupWorkingDirectory())
#if dbglog_HAVE
	if (dbglog_open())
#endif
#if MySoundEnabled
	if (MySound_Init())
		/* takes a while to stabilize, do as soon as possible */
#endif
	if (LoadMacRom())
	if (LoadInitialImages())
	if (InitCocoaStuff())
		/*
			Can get openFile call backs here
			for initial files.
			So must load ROM, disk1.dsk, etc first.
		*/
	if (InitLocationDat())
	if (CreateMainWindow())
#if EmLocalTalk
	if (EntropyGather())
	if (InitLocalTalk())
#endif
	if (WaitForRom())
	{
		IsOk = trueblnr;
	}

	[pool release];

	return IsOk;
}

LOCALPROC UnInitOSGLU(void)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

#if EmLocalTalk
	UnInitLocalTalk();
#endif
#if MayFullScreen
	UngrabMachine();
#endif
#if MySoundEnabled
	MySound_Stop();
#endif
#if MySoundEnabled
	MySound_UnInit();
#endif
#if IncludePbufs
	UnInitPbufs();
#endif
	UnInitDrives();
	UnInitLocationDat();

	ForceShowCursor();

#if dbglog_HAVE
	dbglog_close();
#endif

	CheckSavedMacMsg(falseblnr);

	MyCloseRenderer();
	CloseMainWindow();

#if MayFullScreen
	My_ShowMenuBar();
#endif

	UnInitCocoaStuff();

	UnallocMyMemory();

	[pool release];
}

int main(int argc, char **argv)
{
	(void) argc;
	(void) argv;

	ZapOSGLUVars();

	if (InitOSGLU()) {
		if (MyStartFrameDriver())
		if (EmuThread_Start())
		{
			/*
				The main thread now belongs to AppKit for the rest
				of the run. The emulator loop, which used to live
				here, runs on its own thread.
			*/
			[NSApp run];
		}
	}

	EmuThread_Stop();
	MyStopFrameDriver();
	UnInitOSGLU();

	return 0;
}

#endif /* WantOSGLUCCO */
