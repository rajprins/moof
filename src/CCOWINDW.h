/*
	CCOWINDW.h

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
	WINDoW for the Cocoa backend

	The Metal renderer's attachment to the view, the window, view
	and window delegate classes, window creation and recreation on a
	magnify or full screen toggle, the background and speed stopped
	transitions, and the save panel for a new disk image.

	Not a header in the usual sense: this is a fragment of
	OSGLUCCO.m, #included by it exactly once, in place, so that the
	backend stays a single translation unit. LOCALVAR and LOCALPROC
	are file static and the order of inclusion matters.
*/

/* --- main window creation and disposal --- */

#if MayFullScreen
LOCALPROC AdjustMachineGrab(void)
{
#if EnableFSMouseMotion
	AdjustMouseMotionGrab();
#endif
}
#endif

#if MayFullScreen
LOCALPROC UngrabMachine(void)
{
	GrabMachine = falseblnr;
	AdjustMachineGrab();
}
#endif

/*
	Resizes the drawable. The magnification factor does not appear
	here: an integral magnify simply makes the view larger, and the
	nearest neighbour sampler then reproduces each guest pixel as an
	exact block. The backing scale factor is passed through so that
	the result stays pixel exact on a Retina display, which the
	OpenGL path gave up on by asking for a non best resolution
	surface.
*/
LOCALPROC MyAdjustRendererForSize(int h, int v)
{
	double backingScale = 1.0;

	if (nil != MyWindow) {
		backingScale = [MyWindow backingScaleFactor];
	}

	MTLRenderer_Resize(h, v, backingScale);

	ScreenChangedAll();
}

LOCALVAR blnr WantScreensChangedCheck = falseblnr;

LOCALPROC MyUpdateRendererGeometry(void)
{
	if (HaveRenderer && (nil != MyNSview)) {
		NSRect r = [MyNSview frame];

		MyAdjustRendererForSize(r.size.width, r.size.height);
	}
}

LOCALPROC MyCloseRenderer(void)
{
	if (HaveRenderer) {
		MTLRenderer_UnInit();
		HaveRenderer = falseblnr;
	}
}

LOCALFUNC blnr MyGetRenderer(void)
{
	blnr v = falseblnr;

	if (! HaveRenderer) {
		NSRect NewWinRect = [MyNSview frame];

		if (! MTLRenderer_Init(MyNSview,
			vMacScreenWidth, vMacScreenHeight))
		{
#if dbglog_HAVE
			dbglog_writeln("Could not init Metal renderer");
#endif
			goto label_exit;
		}

		HaveRenderer = trueblnr;

		MyAdjustRendererForSize(NewWinRect.size.width,
			NewWinRect.size.height);

#if 0 != vMacScreenDepth
		ColorModeWorks = trueblnr;
#endif
	}
	v = trueblnr;

label_exit:
	return v;
}

/* Subclass of NSWindow to fix genie effect and support resize events */
@interface MyClassWindow : NSWindow
@end

@implementation MyClassWindow

#if MayFullScreen
- (BOOL)canBecomeKeyWindow
{
	return
#if VarFullScreen
		(! UseFullScreen) ? [super canBecomeKeyWindow] :
#endif
		YES;
}
#endif

#if MayFullScreen
- (BOOL)canBecomeMainWindow
{
	return
#if VarFullScreen
		(! UseFullScreen) ? [super canBecomeMainWindow] :
#endif
		YES;
}
#endif

#if MayFullScreen
- (NSRect)constrainFrameRect:(NSRect)frameRect
	toScreen:(NSScreen *)screen
{
#if VarFullScreen
	if (! UseFullScreen) {
		return [super constrainFrameRect:frameRect toScreen:screen];
	} else
#endif
	{
		return frameRect;
	}
}
#endif

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	/* NSPasteboard *pboard = [sender draggingPasteboard]; */
	NSDragOperation sourceDragMask =
		[sender draggingSourceOperationMask];
	NSDragOperation v = NSDragOperationNone;

	if (0 != (sourceDragMask & NSDragOperationGeneric)) {
		return NSDragOperationGeneric;
	}

	return v;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	/* remove hilighting */
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	BOOL v = NO;
	NSPasteboard *pboard = [sender draggingPasteboard];
	/*
		NSDragOperation sourceDragMask =
			[sender draggingSourceOperationMask];
	*/

	/*
		One pasteboard item per dropped file, each a file URL. This
		replaces the single NSFilenamesPboardType property list, and
		the NSURLPboardType fallback, both deprecated since 10.14.
		Restricting the read to file URLs keeps web links out, as the
		old fallback did by way of [fileURL path]. Aliases are still
		resolved by Sony_ResolveInsert, since a file URL to an alias
		file names the alias, not its target.
	*/
	NSArray *fileURLs = [pboard
		readObjectsForClasses: [NSArray arrayWithObject: [NSURL class]]
		options: [NSDictionary
			dictionaryWithObject: [NSNumber numberWithBool: YES]
			forKey: NSPasteboardURLReadingFileURLsOnlyKey]];
	NSUInteger i;
	NSUInteger n = [fileURLs count];

	for (i = 0; i < n; ++i) {
		NSURL *fileURL = [fileURLs objectAtIndex: i];
		Sony_ResolveInsert([fileURL path]);
	}
	if (n > 0) {
		v = YES;
	}

	if (v && gTrueBackgroundFlag) {
		MyUpdateKeyboardModifiers([NSEvent modifierFlags]);

		[NSApp activateIgnoringOtherApps: YES];
	}

	return v;
}

- (void) concludeDragOperation:(id <NSDraggingInfo>)the_sender
{
}

@end

@interface MyClassWindowDelegate : NSObject <NSWindowDelegate>
@end

@implementation MyClassWindowDelegate

- (BOOL)windowShouldClose:(id)sender
{
	RequestMacOff = trueblnr;
	return NO;
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	gTrueBackgroundFlag = falseblnr;
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
	gTrueBackgroundFlag = trueblnr;
}

@end

@interface MyClassView : NSView
@end

@implementation MyClassView

- (void)resetCursorRects
{
	[self addCursorRect: [self visibleRect]
		cursor: [NSCursor arrowCursor]];
}

- (BOOL)isOpaque
{
	return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
	/*
		Called upon makeKeyAndOrderFront. Create our
		OpenGL context here, because can't do so
		before makeKeyAndOrderFront.
		And if create after then our content won't
		be drawn initially, resulting in flicker.

		AppKit calls this whenever it likes, and MyDrawWithMetal
		writes ScalingBuff and reads the guest framebuffer, so the
		emulator lock is taken. It is recursive, which matters
		because this is also reached from ReCreateMainWindow inside
		the frame driver, where the lock is already held.
	*/
	EmuLock_Acquire();
	if (MyGetRenderer()) {
		MyDrawWithMetal(0, 0, vMacScreenHeight, vMacScreenWidth);
			/*
				The whole screen rather than dirtyRect: drawRect is
				called very rarely, and the whole converted buffer
				is uploaded anyway.
			*/
	}
	EmuLock_Release();
}

@end



LOCALVAR MyClassWindowDelegate *MyWinDelegate = nil;

LOCALPROC CloseMainWindow(void)
{
	if (nil != MyWinDelegate) {
		[MyWinDelegate release];
		MyWinDelegate = nil;
	}

	if (nil != MyWindow) {
		[MyWindow close];
		MyWindow = nil;
	}

	if (nil != MyNSview) {
		[MyNSview release];
		MyNSview = nil;
	}

	/*
		The renderer is deliberately not torn down here.
		ReCreateMainWindow disposes of the old window by restoring
		the old state, calling this, and then restoring the new
		state, so at this point the live renderer already belongs
		to the newly created view. Tearing it down here would
		destroy the new renderer rather than the old one, leaving a
		blank screen after a magnify or full screen toggle.

		Teardown is therefore explicit: before recreation in
		ReCreateMainWindow, and at shutdown in UnInitCocoaStuff.
	*/
}

LOCALPROC MySetWindowTitle(void)
{
	[MyWindow setTitle: myAppName];
}

enum {
	kMagStateNormal,
#if EnableMagnify
	kMagStateMagnify,
#endif
	kNumMagStates
};

#define kMagStateAuto kNumMagStates

#if MayNotFullScreen
LOCALVAR int CurWinIndx;
LOCALVAR blnr HavePositionWins[kNumMagStates];
LOCALVAR NSPoint WinPositionWins[kNumMagStates];
#endif

LOCALVAR NSRect SavedScrnBounds;

LOCALFUNC blnr CreateMainWindow(void)
{
	unsigned int style;
	NSRect MainScrnBounds;
	NSRect AllScrnBounds;
	NSRect NewWinRect;
	NSPoint botleftPos;
	int NewWindowHeight = vMacScreenHeight;
	int NewWindowWidth = vMacScreenWidth;
	blnr v = falseblnr;

#if VarFullScreen
	if (UseFullScreen) {
		My_HideMenuBar();
	} else {
		My_ShowMenuBar();
	}
#else
#if MayFullScreen
	My_HideMenuBar();
#endif
#endif

	MainScrnBounds = [[NSScreen mainScreen] frame];
	SavedScrnBounds = MainScrnBounds;
	{
		NSUInteger i;
		NSArray *screens = [NSScreen screens];
		NSUInteger n = [screens count];

		AllScrnBounds = MainScrnBounds;
		for (i = 0; i < n; ++i) {
			AllScrnBounds = NSUnionRect(AllScrnBounds,
				[[screens objectAtIndex:i] frame]);
		}
	}

#if EnableMagnify
	if (UseMagnify) {
		NewWindowHeight *= MyWindowScale;
		NewWindowWidth *= MyWindowScale;
	}
#endif

	botleftPos.x = MainScrnBounds.origin.x
		+ floor((MainScrnBounds.size.width
			- NewWindowWidth) / 2);
	botleftPos.y = MainScrnBounds.origin.y
		+ floor((MainScrnBounds.size.height
			- NewWindowHeight) / 2);
	if (botleftPos.x < MainScrnBounds.origin.x) {
		botleftPos.x = MainScrnBounds.origin.x;
	}
	if (botleftPos.y < MainScrnBounds.origin.y) {
		botleftPos.y = MainScrnBounds.origin.y;
	}

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		ViewHSize = MainScrnBounds.size.width;
		ViewVSize = MainScrnBounds.size.height;
#if EnableMagnify
		if (UseMagnify) {
			ViewHSize /= MyWindowScale;
			ViewVSize /= MyWindowScale;
		}
#endif
		if (ViewHSize >= vMacScreenWidth) {
			ViewHStart = 0;
			ViewHSize = vMacScreenWidth;
		} else {
			ViewHSize &= ~ 1;
		}
		if (ViewVSize >= vMacScreenHeight) {
			ViewVStart = 0;
			ViewVSize = vMacScreenHeight;
		} else {
			ViewVSize &= ~ 1;
		}
	}
#endif


#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		NewWinRect = AllScrnBounds;

		/*
			Pixels to the left of and above the drawing area in the
			borderless window that covers every screen. The window
			is in AppKit's bottom up coordinates, so the vertical
			offset is measured from the top edge of the union.
		*/
		hOffset = botleftPos.x - AllScrnBounds.origin.x;
		vOffset = AllScrnBounds.size.height
			- ((botleftPos.y - AllScrnBounds.origin.y)
				+ ((NewWindowHeight < MainScrnBounds.size.height)
					? NewWindowHeight : MainScrnBounds.size.height));

		style = NSWindowStyleMaskBorderless;
	}
#endif
#if VarFullScreen
	else
#endif
#if MayNotFullScreen
	{
		int WinIndx;

#if EnableMagnify
		if (UseMagnify) {
			WinIndx = kMagStateMagnify;
		} else
#endif
		{
			WinIndx = kMagStateNormal;
		}

		if (! HavePositionWins[WinIndx]) {
			WinPositionWins[WinIndx].x = botleftPos.x;
			WinPositionWins[WinIndx].y = botleftPos.y;
			HavePositionWins[WinIndx] = trueblnr;
			NewWinRect = NSMakeRect(botleftPos.x, botleftPos.y,
				NewWindowWidth, NewWindowHeight);
		} else {
			NewWinRect = NSMakeRect(WinPositionWins[WinIndx].x,
				WinPositionWins[WinIndx].y,
				NewWindowWidth, NewWindowHeight);
		}

		style = NSWindowStyleMaskTitled
			| NSWindowStyleMaskMiniaturizable
			| NSWindowStyleMaskClosable;

		CurWinIndx = WinIndx;
	}
#endif

	/* Manually create a window, avoids having a nib file resource */
	MyWindow = [[MyClassWindow alloc]
		initWithContentRect: NewWinRect
		styleMask: style
		backing: NSBackingStoreBuffered
		defer: YES];

	if (nil == MyWindow) {
#if dbglog_HAVE
		dbglog_writeln("Could not create the Cocoa window");
#endif
		goto label_exit;
	}

	/* [MyWindow setReleasedWhenClosed: YES]; */
		/*
			no need to set current_video as it's the
			default for NSWindows
		*/
	MySetWindowTitle();
	[MyWindow setAcceptsMouseMovedEvents: YES];
	[MyWindow setViewsNeedDisplay: NO];

	[MyWindow registerForDraggedTypes:
		[NSArray arrayWithObject: NSPasteboardTypeFileURL]];

	MyWinDelegate = [[MyClassWindowDelegate alloc] init];
	if (nil == MyWinDelegate) {
#if dbglog_HAVE
		dbglog_writeln("Could not create MyWinDelegate");
#endif
		goto label_exit;
	}
	[MyWindow setDelegate: MyWinDelegate];

	MyNSview = [[MyClassView alloc] init];
	if (nil == MyNSview) {
#if dbglog_HAVE
		dbglog_writeln("Could not create MyNSview");
#endif
		goto label_exit;
	}

	/*
		found in SDL 2.0.12:
		"Note: as of the macOS 10.15 SDK, this defaults to YES
		instead of NO when the NSHighResolutionCapable boolean
		is set in Info.plist."
	*/
	[MyWindow setContentView: MyNSview];

	[MyWindow makeKeyAndOrderFront: nil];

	/*
		just in case drawRect didn't get called
		during makeKeyAndOrderFront
	*/
	if (! MyGetRenderer()) {
#if dbglog_HAVE
		dbglog_writeln("Could not MyGetRenderer");
#endif
		goto label_exit;
	}


	v = trueblnr;

label_exit:

	return v;
}

#if EnableRecreateW
LOCALPROC ZapMyWState(void)
{
	MyWindow = nil;
	MyNSview = nil;
	MyWinDelegate = nil;
}
#endif

#if EnableRecreateW
struct MyWState {
#if MayFullScreen
	ui4r f_ViewHSize;
	ui4r f_ViewVSize;
	ui4r f_ViewHStart;
	ui4r f_ViewVStart;
	short f_hOffset;
	short f_vOffset;
#endif
#if VarFullScreen
	blnr f_UseFullScreen;
#endif
#if EnableMagnify
	blnr f_UseMagnify;
#endif
#if MayNotFullScreen
	int f_CurWinIndx;
#endif
	NSWindow *f_MyWindow;
	NSView *f_MyNSview;
	MyClassWindowDelegate *f_MyWinDelegate;
};
typedef struct MyWState MyWState;
#endif

#if EnableRecreateW
LOCALPROC GetMyWState(MyWState *r)
{
#if MayFullScreen
	r->f_ViewHSize = ViewHSize;
	r->f_ViewVSize = ViewVSize;
	r->f_ViewHStart = ViewHStart;
	r->f_ViewVStart = ViewVStart;
	r->f_hOffset = hOffset;
	r->f_vOffset = vOffset;
#endif
#if VarFullScreen
	r->f_UseFullScreen = UseFullScreen;
#endif
#if EnableMagnify
	r->f_UseMagnify = UseMagnify;
#endif
#if MayNotFullScreen
	r->f_CurWinIndx = CurWinIndx;
#endif
	r->f_MyWindow = MyWindow;
	r->f_MyNSview = MyNSview;
	r->f_MyWinDelegate = MyWinDelegate;
}
#endif

#if EnableRecreateW
LOCALPROC SetMyWState(MyWState *r)
{
#if MayFullScreen
	ViewHSize = r->f_ViewHSize;
	ViewVSize = r->f_ViewVSize;
	ViewHStart = r->f_ViewHStart;
	ViewVStart = r->f_ViewVStart;
	hOffset = r->f_hOffset;
	vOffset = r->f_vOffset;
#endif
#if VarFullScreen
	UseFullScreen = r->f_UseFullScreen;
#endif
#if EnableMagnify
	UseMagnify = r->f_UseMagnify;
#endif
#if MayNotFullScreen
	CurWinIndx = r->f_CurWinIndx;
#endif
	MyWindow = r->f_MyWindow;
	MyNSview = r->f_MyNSview;
	MyWinDelegate = r->f_MyWinDelegate;
}
#endif

#if EnableRecreateW
LOCALPROC ReCreateMainWindow(void)
{
	MyWState old_state;
	MyWState new_state;
	blnr HadCursorHidden = HaveCursorHidden;

#if VarFullScreen
	if (! UseFullScreen)
#endif
#if MayNotFullScreen
	{
		/* save old position */
		NSRect r =
			[NSWindow contentRectForFrameRect: [MyWindow frame]
				styleMask: [MyWindow styleMask]];
		WinPositionWins[CurWinIndx] = r.origin;
	}
#endif

#if MayFullScreen
	if (GrabMachine) {
		GrabMachine = falseblnr;
		UngrabMachine();
	}
#endif

	MyCloseRenderer();

	GetMyWState(&old_state);

	ZapMyWState();

#if EnableMagnify
	UseMagnify = WantMagnify;
#endif
#if VarFullScreen
	UseFullScreen = WantFullScreen;
#endif

	if (! CreateMainWindow()) {
		CloseMainWindow();
		SetMyWState(&old_state);

		/*
			The renderer was torn down above in anticipation of a
			new view. Since the new window could not be made, it
			has to be re-attached to the restored old view.
		*/
		(void) MyGetRenderer();

#if VarFullScreen
		if (UseFullScreen) {
			My_HideMenuBar();
		} else {
			My_ShowMenuBar();
		}
#endif

		/* avoid retry */
#if VarFullScreen
		WantFullScreen = UseFullScreen;
#endif
#if EnableMagnify
		WantMagnify = UseMagnify;
#endif

	} else {
		GetMyWState(&new_state);
		SetMyWState(&old_state);
		CloseMainWindow();
		SetMyWState(&new_state);

		if (HadCursorHidden) {
			(void) MyMoveMouse(CurMouseH, CurMouseV);
		}
	}
}
#endif

#if VarFullScreen && EnableMagnify
enum {
	kWinStateWindowed,
#if EnableMagnify
	kWinStateFullScreen,
#endif
	kNumWinStates
};
#endif

#if VarFullScreen && EnableMagnify
LOCALVAR int WinMagStates[kNumWinStates];
#endif

LOCALPROC ZapWinStateVars(void)
{
#if MayNotFullScreen
	{
		int i;

		for (i = 0; i < kNumMagStates; ++i) {
			HavePositionWins[i] = falseblnr;
		}
	}
#endif
#if VarFullScreen && EnableMagnify
	{
		int i;

		for (i = 0; i < kNumWinStates; ++i) {
			WinMagStates[i] = kMagStateAuto;
		}
	}
#endif
}

#if VarFullScreen
LOCALPROC ToggleWantFullScreen(void)
{
	WantFullScreen = ! WantFullScreen;

#if EnableMagnify
	{
		int OldWinState =
			UseFullScreen ? kWinStateFullScreen : kWinStateWindowed;
		int OldMagState =
			UseMagnify ? kMagStateMagnify : kMagStateNormal;
		int NewWinState =
			WantFullScreen ? kWinStateFullScreen : kWinStateWindowed;
		int NewMagState = WinMagStates[NewWinState];

		WinMagStates[OldWinState] = OldMagState;
		if (kMagStateAuto != NewMagState) {
			WantMagnify = (kMagStateMagnify == NewMagState);
		} else {
			WantMagnify = falseblnr;
			if (WantFullScreen) {
				NSRect MainScrnBounds = [[NSScreen mainScreen] frame];

				if ((MainScrnBounds.size.width
						>= vMacScreenWidth * MyWindowScale)
					&& (MainScrnBounds.size.height
						>= vMacScreenHeight * MyWindowScale)
					)
				{
					WantMagnify = trueblnr;
				}
			}
		}
	}
#endif
}
#endif

/* --- SavedTasks --- */

LOCALPROC LeaveBackground(void)
{
	EmulationWasInterrupted = trueblnr;
}

LOCALPROC EnterBackground(void)
{
	DisconnectKeyCodes3();

	ForceShowCursor();
}

LOCALPROC LeaveSpeedStopped(void)
{
#if MySoundEnabled
	MySound_Start();
#endif

	StartUpTimeAdjust();
}

LOCALPROC EnterSpeedStopped(void)
{
#if MySoundEnabled
	MySound_Stop();
#endif
}

#if IncludeSonyNew && ! SaveDialogEnable
LOCALFUNC blnr FindOrMakeNamedChildDirPath(NSString *parentPath,
	char *ChildName, NSString **childPath)
{
	NSString *r;
	BOOL isDir;
	Boolean isDirectory;
	NSFileManager *fm = [NSFileManager defaultManager];
	blnr v = falseblnr;

	if (FindNamedChildPath(parentPath, ChildName, &r)) {
		if ([fm fileExistsAtPath:r isDirectory: &isDir])
		{
			if (isDir) {
				*childPath = r;
				v = trueblnr;
			} else {
				NSString *RslvPath = MyResolveAlias(r, &isDirectory);
				if (nil != RslvPath) {
					if (isDirectory) {
						*childPath = RslvPath;
						v = trueblnr;
					}
				}
			}
		} else {
			if ([fm
				createDirectoryAtPath:r
				withIntermediateDirectories:NO
				attributes:nil
				error:nil])
			{
				*childPath = r;
				v = trueblnr;
			}
		}
	}

	return v;
}
#endif

#if IncludeSonyNew
LOCALPROC MakeNewDisk(ui5b L, NSString *drivename)
{
#if SaveDialogEnable
	NSInteger result = NSModalResponseCancel;
	NSSavePanel *panel = [NSSavePanel savePanel];

	MyBeginDialog();

	[panel setNameFieldStringValue: drivename];

	result = [panel runModal];

	MyEndDialog();

	if (NSModalResponseOK == result) {
		NSString* filePath = [[panel URL] path];
		MakeNewDisk0(L, filePath);
	}
#else /* SaveDialogEnable */
	NSString *sPath;

	if (FindOrMakeNamedChildDirPath(MyDataPath, "out", &sPath)) {
		NSString *filePath =
			[sPath stringByAppendingPathComponent: drivename];
		MakeNewDisk0(L, filePath);
	}
#endif /* SaveDialogEnable */
}
#endif

#if IncludeSonyNew
LOCALPROC MakeNewDiskAtDefault(ui5b L)
{
	MakeNewDisk(L, @"untitled.dsk");
}
#endif
