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

LOCALPROC UniCharStrFromSubstCStr(int *L, unichar *x, char *s)
{
	int i;
	int L0;
	ui3b ps[ClStrMaxLength];

	ClStrFromSubstCStr(&L0, ps, s);

	for (i = 0; i < L0; ++i) {
		x[i] = Cell2UnicodeMap[ps[i]];
	}

	*L = L0;
}

LOCALFUNC NSString * NSStringCreateFromSubstCStr(char *s)
{
	int L;
	unichar x[ClStrMaxLength];

	UniCharStrFromSubstCStr(&L, x, s);

	return [NSString stringWithCharacters:x length:L];
}

#if IncludeSonyNameNew
LOCALFUNC blnr MacRomanFileNameToNSString(tPbuf i,
	NSString **r)
{
	ui3p p;
	void *Buffer = PbufDat[i];
	ui5b L = PbufSize[i];

	p = (ui3p)malloc(L /* + 1 */);
	if (p != NULL) {
		NSData *d;
		ui3b *p0 = (ui3b *)Buffer;
		ui3b *p1 = (ui3b *)p;

		if (L > 0) {
			ui5b j = L;

			do {
				ui3b x = *p0++;
				if (x < 32) {
					x = '-';
				} else if (x >= 128) {
				} else {
					switch (x) {
						case '/':
						case '<':
						case '>':
						case '|':
						case ':':
							x = '-';
						default:
							break;
					}
				}
				*p1++ = x;
			} while (--j > 0);

			if ('.' == p[0]) {
				p[0] = '-';
			}
		}

		d = [[NSData alloc] initWithBytesNoCopy:p length:L];

		*r = [[[NSString alloc]
			initWithData:d encoding:NSMacOSRomanStringEncoding]
			autorelease];

		[d release];

		return trueblnr;
	}

	return falseblnr;
}
#endif

#if IncludeSonyGetName || IncludeHostTextClipExchange
/*
	The NSData is autoreleased; both callers, vSonyGetName and
	HTCEimport, have a pool in place.
*/
LOCALFUNC tMacErr NSStringToRomanPbuf(NSString *string, tPbuf *r)
{
	tMacErr v = mnvm_miscErr;
	NSData *d0 = [string dataUsingEncoding: NSMacOSRomanStringEncoding
		allowLossyConversion: YES];
	const void *s = [d0 bytes];
	NSUInteger L = [d0 length];

	if ((NULL == s) || (L > (NSUInteger)(ui5b) -1)) {
		/* a Pbuf's size is 32 bits */
		v = mnvm_miscErr;
	} else {
		ui3p p = (ui3p)malloc(L);

		if (NULL == p) {
			v = mnvm_miscErr;
		} else {
			/* memcpy((char *)p, s, L); */
			ui3b *p0 = (ui3b *)s;
			ui3b *p1 = (ui3b *)p;
			NSUInteger i;

			for (i = L; i > 0; --i) {
				ui3b v = *p0++;
				if (10 == v) {
					v = 13;
				}
				*p1++ = v;
			}

			v = PbufNewFromPtr(p, (ui5b) L, r);
		}
	}

	return v;
}
#endif
