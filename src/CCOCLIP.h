/*
	CCOCLIP.h

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
	CLIPboard for the Cocoa backend

	Host text clip exchange with NSPasteboard, run on the main
	thread from the emulator thread.

	Not a header in the usual sense: this is a fragment of
	OSGLUCCO.m, #included by it exactly once, in place, so that the
	backend stays a single translation unit. LOCALVAR and LOCALPROC
	are file static and the order of inclusion matters.
*/

#if IncludeHostTextClipExchange
/*
	Runs a block on the main thread and waits for it.

	The host text clip exchange is reached from a guest extension
	call, so on the emulator thread, but NSPasteboard belongs to the
	main thread. dispatch_sync alone would deadlock: the emulator
	thread holds the emulator lock, and the main thread may be
	blocked waiting for exactly that lock in the frame driver or in
	sendEvent:. So the lock is released across the wait, as
	EmuLock_Yield does. The emulator thread holds it exactly once
	while running guest code, so one release frees it.

	The main thread may therefore run its usual lock holding work
	while the guest is in the middle of this call. None of that work
	touches the Pbuf being exchanged, which the caller has already
	taken ownership of or not yet created.
*/
LOCALPROC MyRunOnMainThread(void (^block)(void))
{
	if ([NSThread isMainThread]) {
		block();
	} else {
		EmuLock_Release();
		dispatch_sync(dispatch_get_main_queue(), block);
		EmuLock_Acquire();
	}
}
#endif

#if IncludeHostTextClipExchange
GLOBALOSGLUFUNC tMacErr HTCEexport(tPbuf i)
{
	void *Buffer;
	ui5r L;
	tMacErr err = mnvm_miscErr;

	PbufKillToPtr(&Buffer, &L, i);

	if (L > 0) {
		int j;
		ui3b *p = (ui3b *)Buffer;

		for (j = L; --j >= 0; ) {
			ui3b v = *p;
			if (13 == v) {
				*p = 10;
			}
			++p;
		}
	}

	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSData *d = [[NSData alloc]
			initWithBytesNoCopy: Buffer length: L];
		/* NSData *d = [NSData dataWithBytes: Buffer length: L]; */
		NSString *ss = [[[NSString alloc]
			initWithData:d encoding:NSMacOSRomanStringEncoding]
			autorelease];
		__block BOOL wrote = NO;

		MyRunOnMainThread(^{
			NSPasteboard *pasteboard =
				[NSPasteboard generalPasteboard];
			NSArray *newTypes =
				[NSArray arrayWithObject: NSPasteboardTypeString];

			(void) [pasteboard declareTypes: newTypes owner: nil];
			wrote = [pasteboard setString: ss
				forType: NSPasteboardTypeString];
		});

		if (wrote) {
			err = mnvm_noErr;
		}

		[d release];

		[pool release];
	}

	return err;
}
#endif

#if IncludeHostTextClipExchange
GLOBALOSGLUFUNC tMacErr HTCEimport(tPbuf *r)
{
	tMacErr err = mnvm_miscErr;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	__block NSString *string = nil;

	/*
		Only the pasteboard read happens on the main thread. The
		string is copied out so that it outlives that thread's
		autorelease pool, and the conversion into a Pbuf stays here,
		since Pbufs are emulator state.
	*/
	MyRunOnMainThread(^{
		NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
		NSArray *supportedTypes = [NSArray
			arrayWithObject: NSPasteboardTypeString];

		if (nil != [pasteboard availableTypeFromArray: supportedTypes]) {
			string = [[pasteboard
				stringForType: NSPasteboardTypeString] copy];
		}
	});

	if (nil != string) {
		err = NSStringToRomanPbuf(string, r);
		[string release];
	}

	[pool release];

	return err;
}
#endif
