/*
	CCOTEXT.h

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
	TEXT translation for the Cocoa backend

	Conversion between the emulator's Mac Roman strings, Pbufs and
	NSString.

	Not a header in the usual sense: this is a fragment of
	OSGLUCCO.m, #included by it exactly once, in place, so that the
	backend stays a single translation unit. LOCALVAR and LOCALPROC
	are file static and the order of inclusion matters.
*/

/* --- text translation --- */

/*
	The emulator's own strings are in its cell encoding, which
	ClStrFromSubstCStr produces from a C string with substitutions.
	The result is autoreleased, hence no "Create" in the name; every
	caller runs inside a pool.
*/
LOCALFUNC NSString * NSStringFromSubstCStr(char *s)
{
	int i;
	int L;
	ui3b ps[ClStrMaxLength];
	unichar x[ClStrMaxLength];

	ClStrFromSubstCStr(&L, ps, s);

	for (i = 0; i < L; ++i) {
		x[i] = Cell2UnicodeMap[ps[i]];
	}

	return [NSString stringWithCharacters: x length: L];
}

#if IncludeSonyNameNew
/*
	A Mac Roman file name from the guest, made safe for the host
	file system: path separators and shell-ish punctuation become
	dashes, as do control characters and a leading dot. Bytes with
	the high bit set are left alone, since they are ordinary Mac
	Roman letters.

	The copy is handed to the NSData, which frees it on release;
	the Pbuf itself is not consumed. The result is autoreleased.
*/
LOCALFUNC blnr MacRomanFileNameToNSString(tPbuf i, NSString **r)
{
	ui5b L = PbufSize[i];
	const ui3b *src = (const ui3b *) PbufDat[i];
	ui3b *p = (ui3b *) malloc(L);
	ui5b j;
	NSData *d;

	if (NULL == p) {
		return falseblnr;
	}

	for (j = 0; j < L; ++j) {
		ui3b x = src[j];

		if ((x < 32)
			|| ('/' == x) || ('<' == x) || ('>' == x)
			|| ('|' == x) || (':' == x))
		{
			x = '-';
		}
		p[j] = x;
	}
	if ((L > 0) && ('.' == p[0])) {
		p[0] = '-';
	}

	d = [[NSData alloc] initWithBytesNoCopy: p length: L];
	*r = [[[NSString alloc]
		initWithData: d encoding: NSMacOSRomanStringEncoding]
		autorelease];
	[d release];

	return trueblnr;
}
#endif

#if IncludeSonyGetName || IncludeHostTextClipExchange
/*
	The reverse direction: an NSString into a new Pbuf as Mac Roman
	with Mac line ends. dataUsingEncoding returns an autoreleased
	object, so the caller must have a pool in place; vSonyGetName
	and HTCEimport both do.

	PbufNewFromPtr takes ownership of the buffer and frees it if no
	Pbuf slot is free, so nothing here needs cleaning up on failure.
*/
LOCALFUNC tMacErr NSStringToRomanPbuf(NSString *string, tPbuf *r)
{
	NSData *d0 = [string dataUsingEncoding: NSMacOSRomanStringEncoding
		allowLossyConversion: YES];
	const ui3b *s = (const ui3b *) [d0 bytes];
	NSUInteger L = [d0 length];
	ui3b *p;
	NSUInteger j;

	if ((NULL == s) || (L > (NSUInteger) (ui5b) -1)) {
		/* a Pbuf's size is 32 bits */
		return mnvm_miscErr;
	}

	p = (ui3b *) malloc(L);
	if (NULL == p) {
		return mnvm_miscErr;
	}

	for (j = 0; j < L; ++j) {
		p[j] = (10 == s[j]) ? 13 : s[j];
	}

	return PbufNewFromPtr(p, (ui5b) L, r);
}
#endif
