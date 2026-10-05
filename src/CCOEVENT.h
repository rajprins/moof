/*
	CCOEVENT.h

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
	EVENTs for the Cocoa backend

	Translation of AppKit events into emulator input, and the
	NSApplication subclass that routes them.

	Not a header in the usual sense: this is a fragment of
	OSGLUCCO.m, #included by it exactly once, in place, so that the
	backend stays a single translation unit. LOCALVAR and LOCALPROC
	are file static and the order of inclusion matters.
*/

LOCALPROC ProcessEventModifiers(NSEvent *event)
{
	NSUInteger newMods = [event modifierFlags];

	MyUpdateKeyboardModifiers(newMods);
}

LOCALPROC ProcessEventLocation(NSEvent *event)
{
	NSPoint p = [event locationInWindow];
	NSWindow *w = [event window];

	if (w != MyWindow) {
		if (nil != w) {
			p = [w convertPointToScreen: p];
		}
		p = [MyWindow convertPointFromScreen: p];
	}
	p = [MyNSview convertPoint: p fromView: nil];
	p.y = [MyNSview frame].size.height - p.y;
	MousePositionNotify((int) p.x, (int) p.y);
}

LOCALPROC ProcessKeyEvent(blnr down, NSEvent *event)
{
	ui3r scancode = [event keyCode];

	ProcessEventModifiers(event);
	Keyboard_UpdateKeyMap(Keyboard_RemapMac(scancode), down);
}

/*
	Handles one event, returning whether the emulator consumed it.

	Previously this was driven by the hand written event pump in
	WaitForNextTick and passed unwanted events on with
	[NSApp sendEvent:]. It is now called from MyClassApplication's
	sendEvent: override on the main thread, so declining an event is
	expressed by returning false and letting NSApplication have it.

	The caller holds the emulator lock.
*/
LOCALFUNC blnr ProcessOneSystemEvent(NSEvent *event)
{
	blnr consumed = trueblnr;

	switch ([event type]) {
		case NSEventTypeLeftMouseDown:
		case NSEventTypeRightMouseDown:
		case NSEventTypeOtherMouseDown:
			ProcessEventLocation(event);
			ProcessEventModifiers(event);
			if (([event window] == MyWindow)
				&& (! gTrueBackgroundFlag)
#if MayNotFullScreen
				&& (WantCursorHidden
#if VarFullScreen
				|| UseFullScreen
#endif
				)
#endif
				)
			{
				MyMouseButtonSet(trueblnr);
			} else {
				/* doesn't belong to us */
				consumed = falseblnr;
			}
			break;

		case NSEventTypeLeftMouseUp:
		case NSEventTypeRightMouseUp:
		case NSEventTypeOtherMouseUp:
			ProcessEventLocation(event);
			ProcessEventModifiers(event);
			if (! MyMouseButtonState) {
				/* doesn't belong to us */
				consumed = falseblnr;
			} else {
				MyMouseButtonSet(falseblnr);
			}
			break;

		case NSEventTypeMouseMoved:
			{
				ProcessEventLocation(event);
				ProcessEventModifiers(event);
			}
			break;
		case NSEventTypeLeftMouseDragged:
		case NSEventTypeRightMouseDragged:
		case NSEventTypeOtherMouseDragged:
			if (! MyMouseButtonState) {
				/* doesn't belong to us ? */
				consumed = falseblnr;
			} else {
				ProcessEventLocation(event);
				ProcessEventModifiers(event);
			}
			break;
		case NSEventTypeKeyUp:
			ProcessKeyEvent(falseblnr, event);
			break;
		case NSEventTypeKeyDown:
			ProcessKeyEvent(trueblnr, event);
			break;
		case NSEventTypeFlagsChanged:
			ProcessEventModifiers(event);
			break;
		/* case NSScrollWheel: */
		/* case NSSystemDefined: */
		/* case NSAppKitDefined: */
		/* case NSEventTypeApplicationDefined: */
		/* case NSPeriodic: */
		/* case NSCursorUpdate: */
		default:
			consumed = falseblnr;
	}

	return consumed;
}

/*
	NSApplication subclass so that events reach the emulator on the
	main thread through the ordinary AppKit path, instead of being
	pulled out of the queue by a loop of our own.
*/

@interface MyClassApplication : NSApplication
@end

@implementation MyClassApplication

- (void)sendEvent:(NSEvent *)event
{
	blnr consumed;

	/*
		Menu key equivalents have to be offered before the emulator
		sees the event, because ProcessOneSystemEvent consumes every
		key down and NSApplication would otherwise never get the
		chance to match one.

		Only Control combinations are offered. That is not a
		shortcut taken for convenience: the emulated Macintosh must
		receive every Command keystroke, so Command must never be
		matched against the host menu bar, however tempting it is to
		just hand the event to performKeyEquivalent: unconditionally.

		If no menu item matches a Control combination, the event
		still falls through to the guest, so Control chords the host
		does not claim are not swallowed.
	*/
	NSEventType type = [event type];

	if (NSEventTypeKeyDown == type) {
		if (0 != ([event modifierFlags] & NSEventModifierFlagControl)) {
			if ([[self mainMenu] performKeyEquivalent: event]) {
				return;
			}
		}
	}

	/*
		Only events the emulator could want are offered to it, and
		only those cost a trip through the emulator lock. Key events
		have no window of their own worth checking, since the
		emulator wants them whenever it is frontmost, and
		ProcessOneSystemEvent sorts out the rest. Mouse events are
		for the emulator only when they are in its window; a drag of
		the title bar, a click in a Settings window or a menu
		tracking event goes straight to AppKit.

		Events with no window at all are left to AppKit as well.
		The one case where the emulator used to see such an event
		was a mouse up after a drag that began inside the window,
		which it already lets through when it has no button down.
	*/
	switch (type) {
		case NSEventTypeKeyDown:
		case NSEventTypeKeyUp:
		case NSEventTypeFlagsChanged:
			break;
		default:
			if ([event window] != MyWindow) {
				[super sendEvent: event];
				return;
			}
			break;
	}

	EmuLock_Acquire();
	consumed = ProcessOneSystemEvent(event);
	EmuLock_Release();

	if (! consumed) {
		[super sendEvent: event];
	}
}

@end
