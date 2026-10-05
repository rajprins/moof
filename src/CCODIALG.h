/*
	CCODIALG.h

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
	DIALoGs for the Cocoa backend

	Presenting MacMsg as an NSAlert, hiding and showing the menu bar
	in full screen, and the open panel for inserting a disk. The save
	panel for a new disk image is in CCOWINDW.h, after the window
	code it follows in the original order.

	Not a header in the usual sense: this is a fragment of
	OSGLUCCO.m, #included by it exactly once, in place, so that the
	backend stays a single translation unit. LOCALVAR and LOCALPROC
	are file static and the order of inclusion matters.
*/

/* --- basic dialogs --- */

/*
	Presents a pending MacMsg natively.

	MacMsg itself is unchanged: it parks the strings in
	SavedBriefMsg and SavedLongMsg and sets SavedFatalMsg, so none of
	its callers across the emulator need to know anything about how
	the message is shown. Only the presentation moves here, from
	NSRunAlertPanel, deprecated since macOS 10.10, to NSAlert.

	This must run on the main thread, which it now does: the display
	link handler drives CheckForSavedTasks, and UnInitOSGLU runs on
	the main thread too.

	runModal spins a nested run loop, so the display link keeps
	firing and re-enters CheckForSavedTasks while the alert is up.
	The guard below stops that turning into a stack of alerts. The
	emulator thread meanwhile blocks on the emulator lock, which the
	frame driver is holding, so emulation pauses while the message is
	on screen. That is the wanted behaviour, and it is what the drawn
	overlay effectively did too.
*/

LOCALVAR blnr PresentingMacMsg = falseblnr;

LOCALPROC MyPresentMacMsg(NSString *briefMsg0, NSString *longMsg0,
	blnr fatal)
{
	NSAlert *alert = [[NSAlert alloc] init];

	[alert setAlertStyle: fatal
		? NSAlertStyleCritical
		: NSAlertStyleWarning];
	[alert setMessageText: briefMsg0];
	[alert setInformativeText: longMsg0];

	if (fatal) {
		[alert addButtonWithTitle:
			NSStringCreateFromSubstCStr(kStrCmdQuit)];
	}

	(void) [alert runModal];

	[alert release];

	EmuLock_Acquire();
	PresentingMacMsg = falseblnr;
	if (fatal) {
		ForceMacOff = trueblnr;
	}
	EmuLock_Release();
}

/*
	Deferred is the normal case. It is false only at teardown, when
	main is about to return and the main queue will never be drained
	again, so a deferred alert -- typically the fatal one explaining
	why startup failed -- would simply never appear.
*/
LOCALPROC CheckSavedMacMsg(blnr deferred)
{
	if ((nullpr != SavedBriefMsg) && ! PresentingMacMsg) {
		blnr fatal = SavedFatalMsg;
		NSString *briefMsg0 =
			NSStringCreateFromSubstCStr(SavedBriefMsg);
		NSString *longMsg0 =
			NSStringCreateFromSubstCStr(SavedLongMsg);

		/*
			Claim the message now, under the lock, so that the
			next tick does not queue it a second time.
		*/
		PresentingMacMsg = trueblnr;
		SavedBriefMsg = nullpr;

		/*
			Presentation is deliberately deferred to a later turn
			of the run loop rather than done here.

			This is reached from the display link callback with
			the emulator lock held. Running a modal session from
			inside a run loop source callback does not present
			reliably, and holding the lock across it would pin the
			emulator thread behind an alert. Both problems go away
			by letting the current callback finish first.

			The block retains the two strings when dispatch copies
			it, which is what keeps them alive; this file is
			compiled without ARC but captured object variables are
			still retained by a copied block.
		*/
		if (deferred) {
			dispatch_async(dispatch_get_main_queue(), ^{
				MyPresentMacMsg(briefMsg0, longMsg0, fatal);
			});
		} else {
			MyPresentMacMsg(briefMsg0, longMsg0, fatal);
		}
	}
}

/* --- hide/show menubar --- */

#if MayFullScreen
LOCALPROC My_HideMenuBar(void)
{
	[NSApp setPresentationOptions:
		NSApplicationPresentationHideDock
		| NSApplicationPresentationHideMenuBar
#if GrabKeysFullScreen
		| NSApplicationPresentationDisableProcessSwitching
#if GrabKeysMaxFullScreen /* dangerous !! */
		| NSApplicationPresentationDisableForceQuit
		| NSApplicationPresentationDisableSessionTermination
#endif
#endif
		];
}
#endif

#if MayFullScreen
LOCALPROC My_ShowMenuBar(void)
{
	[NSApp setPresentationOptions:
		NSApplicationPresentationDefault];
}
#endif

/* --- event handling for main window --- */

LOCALPROC MyBeginDialog(void)
{
	DisconnectKeyCodes3();
	ForceShowCursor();
}

LOCALPROC MyEndDialog(void)
{
	[MyWindow makeKeyWindow];
	EmulationWasInterrupted = trueblnr;
}

LOCALPROC InsertADisk0(void)
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	[panel setAllowsMultipleSelection: YES];

	MyBeginDialog();

	if (NSModalResponseOK == [panel runModal]) {
		NSUInteger i;
		NSArray *a = [panel URLs];
		NSUInteger n = [a count];

		for (i = 0; i < n; ++i) {
			NSURL *fileURL = [a objectAtIndex: i];
			NSString* filePath = [fileURL path];
			(void) Sony_Insert1a(filePath);
		}
	}

	MyEndDialog();
}
