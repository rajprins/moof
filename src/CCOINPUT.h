/*
	CCOINPUT.h

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
	INPUT for the Cocoa backend

	The window and view globals, cursor hiding and warping, the
	keyboard modifier map, and mouse position mapping.

	Not a header in the usual sense: this is a fragment of
	OSGLUCCO.m, #included by it exactly once, in place, so that the
	backend stays a single translation unit. LOCALVAR and LOCALPROC
	are file static and the order of inclusion matters.
*/

LOCALVAR NSWindow *MyWindow = nil;
LOCALVAR NSView *MyNSview = nil;

LOCALVAR blnr HaveRenderer = falseblnr;


LOCALPROC MyHideCursor(void)
{
	[NSCursor hide];
}

LOCALPROC MyShowCursor(void)
{
	if (nil != MyWindow) {
		[MyWindow invalidateCursorRectsForView:
			MyNSview];
	}
	[NSCursor unhide];
}

#if EnableMoveMouse
LOCALFUNC CGPoint MyViewPointToCG(NSPoint *p)
{
	CGPoint cgp;

	*p = [MyNSview convertPoint: *p toView: nil];
	p->y = [MyNSview frame].size.height - p->y;
	*p = [MyWindow convertPointToScreen: *p];

	cgp.x = p->x;
	cgp.y = CGDisplayPixelsHigh(kCGDirectMainDisplay)
		- p->y;

	return cgp;
}
#endif

LOCALPROC MyGetMouseLocation(NSPoint *p)
{
	/* incorrect while window is being dragged */

	*p = [NSEvent mouseLocation]; /* global coordinates */
	if (nil != MyWindow) {
		*p = [MyWindow convertPointFromScreen: *p];
	}
	*p = [MyNSview convertPoint: *p fromView: nil];
	p->y = [MyNSview frame].size.height - p->y;
}

/* --- keyboard --- */

LOCALVAR NSUInteger MyCurrentMods = 0;

/*
	Apple documentation says:
	"The lower 16 bits of the modifier flags are reserved
	for device-dependent bits."

	observed to be:
*/
#define My_NSLShiftKeyMask   0x0002
#define My_NSRShiftKeyMask   0x0004
#define My_NSLControlKeyMask 0x0001
#define My_NSRControlKeyMask 0x2000
#define My_NSLCommandKeyMask 0x0008
#define My_NSRCommandKeyMask 0x0010
#define My_NSLOptionKeyMask  0x0020
#define My_NSROptionKeyMask  0x0040
/*
	Avoid using the above unless it is
	really needed.
*/

LOCALPROC MyUpdateKeyboardModifiers(NSUInteger newMods)
{
	NSUInteger changeMask = MyCurrentMods ^ newMods;

	if (0 != changeMask) {
		if (0 != (changeMask & NSEventModifierFlagCapsLock)) {
			Keyboard_UpdateKeyMap(MKC_formac_CapsLock,
				0 != (newMods & NSEventModifierFlagCapsLock));
		}

#if MKC_formac_RShift == MKC_formac_Shift
		if (0 != (changeMask & NSEventModifierFlagShift)) {
			Keyboard_UpdateKeyMap(MKC_formac_Shift,
				0 != (newMods & NSEventModifierFlagShift));
		}
#else
		if (0 != (changeMask & My_NSLShiftKeyMask)) {
			Keyboard_UpdateKeyMap(MKC_formac_Shift,
				0 != (newMods & My_NSLShiftKeyMask));
		}
		if (0 != (changeMask & My_NSRShiftKeyMask)) {
			Keyboard_UpdateKeyMap(MKC_formac_RShift,
				0 != (newMods & My_NSRShiftKeyMask));
		}
#endif

#if MKC_formac_RControl == MKC_formac_Control
		if (0 != (changeMask & NSEventModifierFlagControl)) {
			Keyboard_UpdateKeyMap(MKC_formac_Control,
				0 != (newMods & NSEventModifierFlagControl));
		}
#else
		if (0 != (changeMask & My_NSLControlKeyMask)) {
			Keyboard_UpdateKeyMap(MKC_formac_Control,
				0 != (newMods & My_NSLControlKeyMask));
		}
		if (0 != (changeMask & My_NSRControlKeyMask)) {
			Keyboard_UpdateKeyMap(MKC_formac_RControl,
				0 != (newMods & My_NSRControlKeyMask));
		}
#endif

#if MKC_formac_RCommand == MKC_formac_Command
		if (0 != (changeMask & NSEventModifierFlagCommand)) {
			Keyboard_UpdateKeyMap(MKC_formac_Command,
				0 != (newMods & NSEventModifierFlagCommand));
		}
#else
		if (0 != (changeMask & My_NSLCommandKeyMask)) {
			Keyboard_UpdateKeyMap(MKC_formac_Command,
				0 != (newMods & My_NSLCommandKeyMask));
		}
		if (0 != (changeMask & My_NSRCommandKeyMask)) {
			Keyboard_UpdateKeyMap(MKC_formac_RCommand,
				0 != (newMods & My_NSRCommandKeyMask));
		}
#endif

#if MKC_formac_ROption == MKC_formac_Option
		if (0 != (changeMask & NSEventModifierFlagOption)) {
			Keyboard_UpdateKeyMap(MKC_formac_Option,
				0 != (newMods & NSEventModifierFlagOption));
		}
#else
		if (0 != (changeMask & My_NSLOptionKeyMask)) {
			Keyboard_UpdateKeyMap(MKC_formac_Option,
				0 != (newMods & My_NSLOptionKeyMask));
		}
		if (0 != (changeMask & My_NSROptionKeyMask)) {
			Keyboard_UpdateKeyMap(MKC_formac_ROption,
				0 != (newMods & My_NSROptionKeyMask));
		}
#endif

		MyCurrentMods = newMods;
	}
}

/* --- mouse --- */

/* cursor hiding */

LOCALVAR blnr WantCursorHidden = falseblnr;

#if MayFullScreen
LOCALVAR short hOffset;
	/* number of pixels to left of drawing area in window */
LOCALVAR short vOffset;
	/* number of pixels above drawing area in window */
#endif

#if MayFullScreen
LOCALVAR blnr GrabMachine = falseblnr;
#endif

#if VarFullScreen
LOCALVAR blnr UseFullScreen = (0 != WantInitFullScreen);
#endif

#if EnableMagnify
LOCALVAR blnr UseMagnify = (0 != WantInitMagnify);
#endif

LOCALVAR blnr gBackgroundFlag = falseblnr;
LOCALVAR blnr CurSpeedStopped = trueblnr;

LOCALVAR blnr HaveCursorHidden = falseblnr;

LOCALPROC ForceShowCursor(void)
{
	if (HaveCursorHidden) {
		HaveCursorHidden = falseblnr;
		MyShowCursor();
	}
}

/* cursor moving */

#if EnableMoveMouse
LOCALFUNC blnr MyMoveMouse(si4b h, si4b v)
{
	NSPoint p;
	CGPoint cgp;

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		h -= ViewHStart;
		v -= ViewVStart;
	}
#endif

#if EnableMagnify
	if (UseMagnify) {
		h *= MyWindowScale;
		v *= MyWindowScale;
	}
#endif

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		h += hOffset;
		v += vOffset;
	}
#endif

	p = NSMakePoint(h, v);
	cgp = MyViewPointToCG(&p);

	/*
		this is the magic call that fixes cursor "freezing"
		after warp
	*/
	CGAssociateMouseAndMouseCursorPosition(0);
	CGWarpMouseCursorPosition(cgp);
	CGAssociateMouseAndMouseCursorPosition(1);

	return trueblnr;
}
#endif

#if EnableFSMouseMotion
LOCALPROC AdjustMouseMotionGrab(void)
{
#if MayFullScreen
	if (GrabMachine) {
		/*
			if magnification changes, need to reset,
			even if HaveMouseMotion already true
		*/
		if (MyMoveMouse(ViewHStart + (ViewHSize / 2),
			ViewVStart + (ViewVSize / 2)))
		{
			SavedMouseH = ViewHStart + (ViewHSize / 2);
			SavedMouseV = ViewVStart + (ViewVSize / 2);
			HaveMouseMotion = trueblnr;
		}
	} else
#endif
	{
		if (HaveMouseMotion) {
			(void) MyMoveMouse(CurMouseH, CurMouseV);
			HaveMouseMotion = falseblnr;
		}
	}
}
#endif

#if EnableFSMouseMotion
LOCALPROC MyMouseConstrain(void)
{
	si4b shiftdh;
	si4b shiftdv;

	if (SavedMouseH < ViewHStart + (ViewHSize / 4)) {
		shiftdh = ViewHSize / 2;
	} else if (SavedMouseH > ViewHStart + ViewHSize - (ViewHSize / 4)) {
		shiftdh = - ViewHSize / 2;
	} else {
		shiftdh = 0;
	}
	if (SavedMouseV < ViewVStart + (ViewVSize / 4)) {
		shiftdv = ViewVSize / 2;
	} else if (SavedMouseV > ViewVStart + ViewVSize - (ViewVSize / 4)) {
		shiftdv = - ViewVSize / 2;
	} else {
		shiftdv = 0;
	}
	if ((shiftdh != 0) || (shiftdv != 0)) {
		SavedMouseH += shiftdh;
		SavedMouseV += shiftdv;
		if (! MyMoveMouse(SavedMouseH, SavedMouseV)) {
			HaveMouseMotion = falseblnr;
		}
	}
}
#endif

/* cursor state */

LOCALPROC MousePositionNotify(int NewMousePosh, int NewMousePosv)
{
	blnr ShouldHaveCursorHidden = trueblnr;

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		NewMousePosh -= hOffset;
		NewMousePosv -= vOffset;
	}
#endif

#if EnableMagnify
	if (UseMagnify) {
		NewMousePosh /= MyWindowScale;
		NewMousePosv /= MyWindowScale;
	}
#endif

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		NewMousePosh += ViewHStart;
		NewMousePosv += ViewVStart;
	}
#endif

#if EnableFSMouseMotion
	if (HaveMouseMotion) {
		MyMousePositionSetDelta(NewMousePosh - SavedMouseH,
			NewMousePosv - SavedMouseV);
		SavedMouseH = NewMousePosh;
		SavedMouseV = NewMousePosv;
	} else
#endif
	{
		if (NewMousePosh < 0) {
			NewMousePosh = 0;
			ShouldHaveCursorHidden = falseblnr;
		} else if (NewMousePosh >= vMacScreenWidth) {
			NewMousePosh = vMacScreenWidth - 1;
			ShouldHaveCursorHidden = falseblnr;
		}
		if (NewMousePosv < 0) {
			NewMousePosv = 0;
			ShouldHaveCursorHidden = falseblnr;
		} else if (NewMousePosv >= vMacScreenHeight) {
			NewMousePosv = vMacScreenHeight - 1;
			ShouldHaveCursorHidden = falseblnr;
		}

#if VarFullScreen
		if (UseFullScreen)
#endif
#if MayFullScreen
		{
			ShouldHaveCursorHidden = trueblnr;
		}
#endif

		/* if (ShouldHaveCursorHidden || CurMouseButton) */
		/*
			for a game like arkanoid, would like mouse to still
			move even when outside window in one direction
		*/
		MyMousePositionSet(NewMousePosh, NewMousePosv);
	}

	WantCursorHidden = ShouldHaveCursorHidden;
}

LOCALPROC CheckMouseState(void)
{
	/*
		incorrect while window is being dragged
		so only call when needed.
	*/
	NSPoint p;

	MyGetMouseLocation(&p);
	MousePositionNotify((int) p.x, (int) p.y);
}

LOCALVAR blnr gTrueBackgroundFlag = falseblnr;
