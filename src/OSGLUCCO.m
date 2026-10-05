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


#ifndef WantGraphicsSwitching
#define WantGraphicsSwitching 0
#endif

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

/*
	Implementation of the narrow C surface declared in EMUCTLAP.h.
	It lives here because SpeedValue and SetSpeedValue are part of
	this translation unit, reached through the unity build includes
	above.
*/

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

#if 0
		*p1 = 0;
		*r = [NSString stringWithCString:(char *)p
			encoding:NSMacOSRomanStringEncoding];
			/* only as of OS X 10.4 */
		free(p);
#endif

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
LOCALFUNC tMacErr NSStringToRomanPbuf(NSString *string, tPbuf *r)
{
	tMacErr v = mnvm_miscErr;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#if 0
	const char *s = [s0
		cStringUsingEncoding: NSMacOSRomanStringEncoding];
	ui5r L = strlen(s);
		/* only as of OS X 10.4 */
#endif
#if 0
	NSData *d0 = [string dataUsingEncoding: NSMacOSRomanStringEncoding];
#endif
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

	[pool release];

	return v;
}
#endif

/* --- drives --- */

LOCALFUNC blnr FindNamedChildPath(NSString *parentPath,
	char *ChildName, NSString **childPath)
{
	blnr v = falseblnr;

#if 0
	NSString *ss = [NSString stringWithCString:s
		encoding:NSASCIIStringEncoding];
		/* only as of OS X 10.4 */
#endif
#if 0
	NSData *d = [NSData dataWithBytes: ChildName
		length: strlen(ChildName)];
	NSString *ss = [[[NSString alloc]
		initWithData:d encoding:NSASCIIStringEncoding]
		autorelease];
#endif
	NSString *ss = NSStringCreateFromSubstCStr(ChildName);
	if (nil != ss) {
		NSString *r = [parentPath stringByAppendingPathComponent: ss];
		if (nil != r) {
			*childPath = r;
			v = trueblnr;
		}
	}

	return v;
}

LOCALFUNC NSString *MyResolveAlias(NSString *filePath,
	Boolean *targetIsFolder)
{
	NSString *resolvedPath = nil;
	CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
		(CFStringRef)filePath, kCFURLPOSIXPathStyle, NO);


	if (url != NULL) {
		BOOL isDir;
		Boolean isStale;
		CFBooleanRef is_alias_file = NULL;
		CFBooleanRef is_symbolic_link = NULL;
		CFDataRef bookmark = NULL;
		CFURLRef resolvedurl = NULL;

		if (CFURLCopyResourcePropertyForKey(url,
			kCFURLIsAliasFileKey, &is_alias_file, NULL))
		if (CFBooleanGetValue(is_alias_file))
		if (CFURLCopyResourcePropertyForKey(url,
			kCFURLIsSymbolicLinkKey, &is_symbolic_link, NULL))
		if (! CFBooleanGetValue(is_symbolic_link))
		if (NULL != (bookmark = CFURLCreateBookmarkDataFromFile(
			kCFAllocatorDefault, url, NULL)))
		if (NULL != (resolvedurl =
			CFURLCreateByResolvingBookmarkData(
				kCFAllocatorDefault,
				bookmark,
				0 /* CFURLBookmarkResolutionOptions options */,
				NULL /* relativeToURL */,
				NULL /* resourcePropertiesToInclude */,
				&isStale,
				NULL /* error */)))
		if (nil != (resolvedPath =
			(NSString *)CFURLCopyFileSystemPath(
				resolvedurl, kCFURLPOSIXPathStyle)))
		{
			if ([[NSFileManager defaultManager]
				fileExistsAtPath: resolvedPath isDirectory: &isDir])
			{
				*targetIsFolder = isDir;
			} else
			{
				*targetIsFolder = FALSE;
			}

			[resolvedPath autorelease];
		}

		if (NULL != resolvedurl) {
			CFRelease(resolvedurl);
		}
		if (NULL != bookmark) {
			CFRelease(bookmark);
		}
		if (NULL != is_alias_file) {
			CFRelease(is_alias_file);
		}
		if (NULL != is_symbolic_link) {
			CFRelease(is_symbolic_link);
		}

		CFRelease(url);
	}

	return resolvedPath;
}

LOCALFUNC blnr FindNamedChildDirPath(NSString *parentPath,
	char *ChildName, NSString **childPath)
{
	NSString *r;
	BOOL isDir;
	Boolean isDirectory;
	blnr v = falseblnr;

	if (FindNamedChildPath(parentPath, ChildName, &r))
	if ([[NSFileManager defaultManager]
		fileExistsAtPath:r isDirectory: &isDir])
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
	}

	return v;
}

LOCALFUNC blnr FindNamedChildFilePath(NSString *parentPath,
	char *ChildName, NSString **childPath)
{
	NSString *r;
	BOOL isDir;
	Boolean isDirectory;
	blnr v = falseblnr;

	if (FindNamedChildPath(parentPath, ChildName, &r))
	if ([[NSFileManager defaultManager]
		fileExistsAtPath:r isDirectory: &isDir])
	{
		if (! isDir) {
			NSString *RslvPath = MyResolveAlias(r, &isDirectory);
			if (nil != RslvPath) {
				if (! isDirectory) {
					*childPath = RslvPath;
					v = trueblnr;
				}
			} else {
				*childPath = r;
				v = trueblnr;
			}
		}
	}

	return v;
}


#define NotAfileRef NULL

LOCALVAR FILE *Drives[NumDrives]; /* open disk image files */
#if IncludeSonyGetName || IncludeSonyNew
LOCALVAR NSString *DriveNames[NumDrives];
#endif

LOCALPROC InitDrives(void)
{
	/*
		This isn't really needed, Drives[i] and DriveNames[i]
		need not have valid values when not vSonyIsInserted[i].
	*/
	tDrive i;

	for (i = 0; i < NumDrives; ++i) {
		Drives[i] = NotAfileRef;
#if IncludeSonyGetName || IncludeSonyNew
		DriveNames[i] = nil;
#endif
	}
}

GLOBALOSGLUFUNC tMacErr vSonyTransfer(blnr IsWrite, ui3p Buffer,
	tDrive Drive_No, ui5r Sony_Start, ui5r Sony_Count,
	ui5r *Sony_ActCount)
{
	tMacErr err = mnvm_miscErr;
	FILE *refnum = Drives[Drive_No];
	ui5r NewSony_Count = 0;

	if (0 == fseek(refnum, Sony_Start, SEEK_SET)) {
		if (IsWrite) {
			NewSony_Count = (ui5r)fwrite(Buffer, 1, Sony_Count, refnum);
		} else {
			NewSony_Count = (ui5r)fread(Buffer, 1, Sony_Count, refnum);
		}

		if (NewSony_Count == Sony_Count) {
			err = mnvm_noErr;
		} else if ((! IsWrite) && feof(refnum) && ! ferror(refnum)) {
			/*
				Read ran past the end of the image. That is
				eofErr, as the File Manager would report it, not
				a failure of the host file.
			*/
			err = mnvm_eofErr;
		}
		clearerr(refnum);
	}

	if (nullpr != Sony_ActCount) {
		*Sony_ActCount = NewSony_Count;
	}

	return err;
}

GLOBALOSGLUFUNC tMacErr vSonyGetSize(tDrive Drive_No, ui5r *Sony_Count)
{
	tMacErr err = mnvm_miscErr;
	FILE *refnum = Drives[Drive_No];
	long v;

	if (0 == fseek(refnum, 0, SEEK_END)) {
		v = ftell(refnum);
		/*
			ui5r is 32 bits, so an image of 4 GiB or more would be
			reported at its size modulo 2^32. Refuse it instead of
			mounting a disk of the wrong size.
		*/
		if ((v >= 0) && (v == (long)(ui5r)v)) {
			*Sony_Count = (ui5r)v;
			err = mnvm_noErr;
		}
	}

	return err; /*& figure out what really to return &*/
}

#ifndef HaveAdvisoryLocks
#define HaveAdvisoryLocks 1
#endif

/*
	What is the difference between fcntl(fd, F_SETLK ...
	and flock(fd ... ?
*/

#if HaveAdvisoryLocks
LOCALFUNC blnr MyLockFile(FILE *refnum)
{
	blnr IsOk = falseblnr;

#if 0
	struct flock fl;
	int fd = fileno(refnum);

	fl.l_start = 0; /* starting offset */
	fl.l_len = 0; /* len = 0 means until end of file */
	/* fl.pid_t l_pid; */ /* lock owner, don't need to set */
	fl.l_type = F_WRLCK; /* lock type: read/write, etc. */
	fl.l_whence = SEEK_SET; /* type of l_start */
	if (-1 == fcntl(fd, F_SETLK, &fl)) {
		MacMsg(kStrImageInUseTitle, kStrImageInUseMessage,
			falseblnr);
	} else {
		IsOk = trueblnr;
	}
#else
	int fd = fileno(refnum);

	if (-1 == flock(fd, LOCK_EX | LOCK_NB)) {
		if (EWOULDBLOCK == errno) {
			/* already locked */
			MacMsg(kStrImageInUseTitle, kStrImageInUseMessage,
				falseblnr);
		} else
		{
			/*
				Failed for other reasons, such as unsupported
				for this volume.
				Don't prevent opening.
			*/
			IsOk = trueblnr;
		}
	} else {
		IsOk = trueblnr;
	}
#endif

	return IsOk;
}
#endif

#if HaveAdvisoryLocks
LOCALPROC MyUnlockFile(FILE *refnum)
{
#if 0
	struct flock fl;
	int fd = fileno(refnum);

	fl.l_start = 0; /* starting offset */
	fl.l_len = 0; /* len = 0 means until end of file */
	/* fl.pid_t l_pid; */ /* lock owner, don't need to set */
	fl.l_type = F_UNLCK;     /* lock type: read/write, etc. */
	fl.l_whence = SEEK_SET;   /* type of l_start */
	if (-1 == fcntl(fd, F_SETLK, &fl)) {
		/* an error occurred */
	}
#else
	int fd = fileno(refnum);

	if (-1 == flock(fd, LOCK_UN)) {
	}
#endif
}
#endif

LOCALFUNC tMacErr vSonyEject0(tDrive Drive_No, blnr deleteit)
{
	FILE *refnum = Drives[Drive_No];

	DiskEjectedNotify(Drive_No);

#if HaveAdvisoryLocks
	MyUnlockFile(refnum);
#endif

	fclose(refnum);
	Drives[Drive_No] = NotAfileRef; /* not really needed */

#if IncludeSonyGetName || IncludeSonyNew
	{
		NSString *filePath = DriveNames[Drive_No];
		if (NULL != filePath) {
			if (deleteit) {
				NSAutoreleasePool *pool =
					[[NSAutoreleasePool alloc] init];
				const char *s = [filePath fileSystemRepresentation];
				remove(s);
				[pool release];
			}
			[filePath release];
			DriveNames[Drive_No] = NULL; /* not really needed */
		}
	}
#endif

	return mnvm_noErr;
}

GLOBALOSGLUFUNC tMacErr vSonyEject(tDrive Drive_No)
{
	return vSonyEject0(Drive_No, falseblnr);
}

#if IncludeSonyNew
GLOBALOSGLUFUNC tMacErr vSonyEjectDelete(tDrive Drive_No)
{
	return vSonyEject0(Drive_No, trueblnr);
}
#endif

LOCALPROC UnInitDrives(void)
{
	tDrive i;

	for (i = 0; i < NumDrives; ++i) {
		if (vSonyIsInserted(i)) {
			(void) vSonyEject(i);
		}
	}
}

#if IncludeSonyGetName
GLOBALOSGLUFUNC tMacErr vSonyGetName(tDrive Drive_No, tPbuf *r)
{
	tMacErr v = mnvm_miscErr;
	NSString *filePath = DriveNames[Drive_No];
	if (NULL != filePath) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSString *s0 = [filePath lastPathComponent];
		v = NSStringToRomanPbuf(s0, r);

		[pool release];
	}

	return v;
}
#endif

/*
	Part of EMUCTLAP, kept here because DriveNames is defined just
	above. Copies rather than handing out the NSString, both to keep
	the interface plain C and because the drive may be ejected, and
	the string released, as soon as the lock is let go.
*/
bool MNVM_CopyDriveName(int driveNo, char *buf, int bufSize)
{
	bool v = false;

#if IncludeSonyGetName || IncludeSonyNew
	if ((driveNo >= 0) && (driveNo < (int) NumDrives)
		&& (nullpr != buf) && (bufSize > 0))
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

		EmuLock_Acquire();
		if (vSonyIsInserted((tDrive) driveNo)) {
			NSString *filePath = DriveNames[driveNo];

			if (nil != filePath) {
				v = [[filePath lastPathComponent]
					getCString: buf
					maxLength: (NSUInteger) bufSize
					encoding: NSUTF8StringEncoding] ? true : false;
			}
		}
		EmuLock_Release();

		[pool release];
	}
#else
	(void) driveNo;
	(void) buf;
	(void) bufSize;
#endif

	return v;
}

LOCALFUNC blnr Sony_Insert0(FILE *refnum, blnr locked,
	NSString *filePath)
{
	tDrive Drive_No;
	blnr IsOk = falseblnr;

	if (! FirstFreeDisk(&Drive_No)) {
		MacMsg(kStrTooManyImagesTitle, kStrTooManyImagesMessage,
			falseblnr);
	} else {
		/* printf("Sony_Insert0 %d\n", (int)Drive_No); */

#if HaveAdvisoryLocks
		if (locked || MyLockFile(refnum))
#endif
		{
			Drives[Drive_No] = refnum;
			DiskInsertNotify(Drive_No, locked);

#if IncludeSonyGetName || IncludeSonyNew
			DriveNames[Drive_No] = [filePath retain];
#endif

			IsOk = trueblnr;
		}
	}

	if (! IsOk) {
		fclose(refnum);
	}

	return IsOk;
}

LOCALFUNC blnr Sony_Insert1(NSString *filePath, blnr silentfail)
{
	/* const char *drivepath = [filePath UTF8String]; */
	const char *drivepath = [filePath fileSystemRepresentation];
	blnr locked = falseblnr;
	/* printf("Sony_Insert1 %s\n", drivepath); */
	FILE *refnum = fopen(drivepath, "rb+");
	if (NULL == refnum) {
		locked = trueblnr;
		refnum = fopen(drivepath, "rb");
	}
	if (NULL == refnum) {
		if (! silentfail) {
			MacMsg(kStrOpenFailTitle, kStrOpenFailMessage, falseblnr);
		}
	} else {
		return Sony_Insert0(refnum, locked, filePath);
	}
	return falseblnr;
}

LOCALFUNC blnr Sony_Insert2(char *s)
{
	NSString *sPath;

	if (! FindNamedChildFilePath(MyDataPath, s, &sPath)) {
		return falseblnr;
	} else {
		return Sony_Insert1(sPath, trueblnr);
	}
}

LOCALFUNC tMacErr LoadMacRomPath(NSString *RomPath)
{
	FILE *ROM_File;
	size_t File_Size;
	tMacErr err = mnvm_fnfErr;
	const char *path = [RomPath fileSystemRepresentation];

	ROM_File = fopen(path, "rb");
	if (NULL != ROM_File) {
		File_Size = fread(ROM, 1, kROM_Size, ROM_File);
		if (kROM_Size != File_Size) {
			if (feof(ROM_File)) {
				MacMsgOverride(kStrShortROMTitle,
					kStrShortROMMessage);
				err = mnvm_eofErr;
			} else {
				MacMsgOverride(kStrNoReadROMTitle,
					kStrNoReadROMMessage);
				err = mnvm_miscErr;
			}
		} else {
			err = ROM_IsValid();
		}
		fclose(ROM_File);
	}

	return err;
}

LOCALFUNC blnr Sony_Insert1a(NSString *filePath)
{
	blnr v;

	if (! ROM_loaded) {
		v = (mnvm_noErr == LoadMacRomPath(filePath));
	} else {
		v = Sony_Insert1(filePath, falseblnr);
	}

	return v;
}

LOCALPROC Sony_ResolveInsert(NSString *filePath)
{
	Boolean isDirectory;
	NSString *RslvPath = MyResolveAlias(filePath, &isDirectory);
	if (nil != RslvPath) {
		if (! isDirectory) {
			(void) Sony_Insert1a(RslvPath);
		}
	} else {
		(void) Sony_Insert1a(filePath);
	}
}

LOCALFUNC blnr Sony_InsertIth(int i)
{
	blnr v;

	if ((i > 9) || ! FirstFreeDisk(nullpr)) {
		v = falseblnr;
	} else {
		char s[] = "disk?.dsk";

		s[4] = '0' + i;

		v = Sony_Insert2(s);
	}

	return v;
}

LOCALFUNC blnr LoadInitialImages(void)
{
	if (! AnyDiskInserted()) {
		int i;

		for (i = 1; Sony_InsertIth(i); ++i) {
			/* stop on first error (including file not found) */
		}
	}

	return trueblnr;
}

#if IncludeSonyNew
LOCALFUNC blnr WriteZero(FILE *refnum, ui5b L)
{
#define ZeroBufferSize 2048
	ui5b i;
	ui3b buffer[ZeroBufferSize];

	memset(&buffer, 0, ZeroBufferSize);

	while (L > 0) {
		i = (L > ZeroBufferSize) ? ZeroBufferSize : L;
		if (fwrite(buffer, 1, i, refnum) != i) {
			return falseblnr;
		}
		L -= i;
	}
	return trueblnr;
}
#endif

#if IncludeSonyNew
LOCALPROC MakeNewDisk0(ui5b L, NSString *sPath)
{
	blnr IsOk = falseblnr;
	const char *drivepath = [sPath fileSystemRepresentation];
	FILE *refnum = fopen(drivepath, "wb+");
	if (NULL == refnum) {
		MacMsg(kStrOpenFailTitle, kStrOpenFailMessage, falseblnr);
	} else {
		if (WriteZero(refnum, L)) {
			IsOk = Sony_Insert0(refnum, falseblnr, sPath);
			refnum = NULL;
		}
		if (refnum != NULL) {
			fclose(refnum);
		}
		if (! IsOk) {
			(void) remove(drivepath);
		}
	}
}
#endif

/* --- ROM --- */

LOCALFUNC tMacErr LoadMacRomFrom(NSString *parentPath)
{
	NSString *RomPath;
	tMacErr err = mnvm_fnfErr;

	if (FindNamedChildFilePath(parentPath, RomFileName, &RomPath)) {
		err = LoadMacRomPath(RomPath);
	}

	return err;
}

LOCALFUNC tMacErr LoadMacRomFromAppDir(void)
{
	return LoadMacRomFrom(MyDataPath);
}

LOCALFUNC tMacErr LoadMacRomFromPrefDir(void)
{
	NSString *PrefsPath;
	NSString *GryphelPath;
	NSString *RomsPath;
	tMacErr err = mnvm_fnfErr;
	NSArray *paths = NSSearchPathForDirectoriesInDomains(
		NSLibraryDirectory, NSUserDomainMask, YES);
	if ((nil != paths) && ([paths count] > 0))
	{
		NSString *LibPath = [paths objectAtIndex:0];
		if (FindNamedChildDirPath(LibPath, "Preferences", &PrefsPath))
		if (FindNamedChildDirPath(PrefsPath, "Gryphel", &GryphelPath))
		if (FindNamedChildDirPath(GryphelPath, "mnvm_rom", &RomsPath))
		{
			err = LoadMacRomFrom(RomsPath);
		}
	}

	return err;
}

LOCALFUNC tMacErr LoadMacRomFromGlobalDir(void)
{
	NSString *GryphelPath;
	NSString *RomsPath;
	tMacErr err = mnvm_fnfErr;
	NSArray *paths = NSSearchPathForDirectoriesInDomains(
		NSApplicationSupportDirectory, NSLocalDomainMask, NO);
	if ((nil != paths) && ([paths count] > 0))
	{
		NSString *LibPath = [paths objectAtIndex:0];
		if (FindNamedChildDirPath(LibPath, "Gryphel", &GryphelPath))
		if (FindNamedChildDirPath(GryphelPath, "mnvm_rom", &RomsPath))
		{
			err = LoadMacRomFrom(RomsPath);
		}
	}

	return err;
}

LOCALFUNC blnr LoadMacRom(void)
{
	tMacErr err;

	if (mnvm_fnfErr == (err = LoadMacRomFromAppDir()))
	if (mnvm_fnfErr == (err = LoadMacRomFromPrefDir()))
	if (mnvm_fnfErr == (err = LoadMacRomFromGlobalDir()))
	{
	}

	(void) err; /* ignore any errors */
	return trueblnr; /* keep launching Moof, regardless */
}


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


LOCALVAR NSWindow *MyWindow = nil;
LOCALVAR NSView *MyNSview = nil;

LOCALVAR blnr HaveRenderer = falseblnr;
LOCALVAR short GLhOffset;
LOCALVAR short GLvOffset;
	/*
		Offsets of the upper left point of the drawing area. These
		no longer take part in drawing, since the Metal renderer
		expresses position through texture coordinates, but hOffset
		and vOffset are still derived from them for full screen
		positioning and mouse mapping.
	*/


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
#if 0
	[cursor->nscursor performSelectorOnMainThread: @selector(set)
		withObject: nil waitUntilDone: NO];
#endif
#if 0
	[[NSCursor arrowCursor] set];
#endif
	[NSCursor unhide];
}

#if EnableMoveMouse
LOCALFUNC CGPoint QZ_PrivateSDLToCG(NSPoint *p)
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

LOCALPROC QZ_GetMouseLocation(NSPoint *p)
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
			Keyboard_UpdateKeyMap2(MKC_formac_CapsLock,
				0 != (newMods & NSEventModifierFlagCapsLock));
		}

#if MKC_formac_RShift == MKC_formac_Shift
		if (0 != (changeMask & NSEventModifierFlagShift)) {
			Keyboard_UpdateKeyMap2(MKC_formac_Shift,
				0 != (newMods & NSEventModifierFlagShift));
		}
#else
		if (0 != (changeMask & My_NSLShiftKeyMask)) {
			Keyboard_UpdateKeyMap2(MKC_formac_Shift,
				0 != (newMods & My_NSLShiftKeyMask));
		}
		if (0 != (changeMask & My_NSRShiftKeyMask)) {
			Keyboard_UpdateKeyMap2(MKC_formac_RShift,
				0 != (newMods & My_NSRShiftKeyMask));
		}
#endif

#if MKC_formac_RControl == MKC_formac_Control
		if (0 != (changeMask & NSEventModifierFlagControl)) {
			Keyboard_UpdateKeyMap2(MKC_formac_Control,
				0 != (newMods & NSEventModifierFlagControl));
		}
#else
		if (0 != (changeMask & My_NSLControlKeyMask)) {
			Keyboard_UpdateKeyMap2(MKC_formac_Control,
				0 != (newMods & My_NSLControlKeyMask));
		}
		if (0 != (changeMask & My_NSRControlKeyMask)) {
			Keyboard_UpdateKeyMap2(MKC_formac_RControl,
				0 != (newMods & My_NSRControlKeyMask));
		}
#endif

#if MKC_formac_RCommand == MKC_formac_Command
		if (0 != (changeMask & NSEventModifierFlagCommand)) {
			Keyboard_UpdateKeyMap2(MKC_formac_Command,
				0 != (newMods & NSEventModifierFlagCommand));
		}
#else
		if (0 != (changeMask & My_NSLCommandKeyMask)) {
			Keyboard_UpdateKeyMap2(MKC_formac_Command,
				0 != (newMods & My_NSLCommandKeyMask));
		}
		if (0 != (changeMask & My_NSRCommandKeyMask)) {
			Keyboard_UpdateKeyMap2(MKC_formac_RCommand,
				0 != (newMods & My_NSRCommandKeyMask));
		}
#endif

#if MKC_formac_ROption == MKC_formac_Option
		if (0 != (changeMask & NSEventModifierFlagOption)) {
			Keyboard_UpdateKeyMap2(MKC_formac_Option,
				0 != (newMods & NSEventModifierFlagOption));
		}
#else
		if (0 != (changeMask & My_NSLOptionKeyMask)) {
			Keyboard_UpdateKeyMap2(MKC_formac_Option,
				0 != (newMods & My_NSLOptionKeyMask));
		}
		if (0 != (changeMask & My_NSROptionKeyMask)) {
			Keyboard_UpdateKeyMap2(MKC_formac_ROption,
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

#if EnableMagnify
#define MaxScale MyWindowScale
#else
#define MaxScale 1
#endif

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
	cgp = QZ_PrivateSDLToCG(&p);

	/*
		this is the magic call that fixes cursor "freezing"
		after warp
	*/
	CGAssociateMouseAndMouseCursorPosition(0);
	CGWarpMouseCursorPosition(cgp);
	CGAssociateMouseAndMouseCursorPosition(1);

#if 0
	if (noErr != CGSetLocalEventsSuppressionInterval(0.0)) {
		/* don't use MacMsg which can call MyMoveMouse */
	}
	if (noErr != CGWarpMouseCursorPosition(cgp)) {
		/* don't use MacMsg which can call MyMoveMouse */
	}
#endif

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

	QZ_GetMouseLocation(&p);
	MousePositionNotify((int) p.x, (int) p.y);
}

LOCALVAR blnr gTrueBackgroundFlag = falseblnr;


LOCALVAR ui3p ScalingBuff = nullpr;

/* Frame handed from the emulating thread to the main thread. */
LOCALVAR blnr FrameIsReady = falseblnr;
LOCALVAR blnr FrameIsColor = falseblnr;
LOCALVAR int FrameSrcX = 0;
LOCALVAR int FrameSrcY = 0;
LOCALVAR int FrameSrcW = 0;
LOCALVAR int FrameSrcH = 0;

LOCALVAR ui3p CLUT_final;

#define CLUT_finalsz1 (256 * 8)

#if (0 != vMacScreenDepth) && (vMacScreenDepth < 4)

#define CLUT_finalClrSz (256 << (5 - vMacScreenDepth))

#define CLUT_finalsz ((CLUT_finalClrSz > CLUT_finalsz1) \
	? CLUT_finalClrSz : CLUT_finalsz1)

#else
#define CLUT_finalsz CLUT_finalsz1
#endif


#define ScrnMapr_DoMap UpdateBWLuminanceCopy
#define ScrnMapr_Src screencomparebuff
#define ScrnMapr_Dst ScalingBuff
#define ScrnMapr_SrcDepth 0
#define ScrnMapr_DstDepth 3
#define ScrnMapr_Map CLUT_final

#include "SCRNMAPR.h"


#if (0 != vMacScreenDepth) && (vMacScreenDepth < 4)

#define ScrnMapr_DoMap UpdateMappedColorCopy
#define ScrnMapr_Src screencomparebuff
#define ScrnMapr_Dst ScalingBuff
#define ScrnMapr_SrcDepth vMacScreenDepth
#define ScrnMapr_DstDepth 5
#define ScrnMapr_Map CLUT_final

#include "SCRNMAPR.h"

#endif

#if vMacScreenDepth >= 4

#define ScrnTrns_DoTrans UpdateTransColorCopy
#define ScrnTrns_Src screencomparebuff
#define ScrnTrns_Dst ScalingBuff
#define ScrnTrns_SrcDepth vMacScreenDepth
#define ScrnTrns_DstDepth 5
#define ScrnTrns_DstZLo 1

#include "SCRNTRNS.h"

#endif

LOCALPROC UpdateLuminanceCopy(si4b top, si4b left,
	si4b bottom, si4b right)
{
	int i;

#if 0 != vMacScreenDepth
	if (UseColorMode) {

#if vMacScreenDepth < 4

		if (! ColorTransValid) {
			int j;
			int k;
			ui5p p4;

			p4 = (ui5p)CLUT_final;
			for (i = 0; i < 256; ++i) {
				for (k = 1 << (3 - vMacScreenDepth); --k >= 0; ) {
					j = (i >> (k << vMacScreenDepth)) & (CLUT_size - 1);
					*p4++ = (((ui5b)CLUT_reds[j] & 0xFF00) << 16)
						| (((ui5b)CLUT_greens[j] & 0xFF00) << 8)
						| ((ui5b)CLUT_blues[j] & 0xFF00);
				}
			}
			ColorTransValid = trueblnr;
		}

		UpdateMappedColorCopy(top, left, bottom, right);

#else
		UpdateTransColorCopy(top, left, bottom, right);
#endif

	} else
#endif
	{
		if (! ColorTransValid) {
			int k;
			ui3p p4 = (ui3p)CLUT_final;

			for (i = 0; i < 256; ++i) {
				for (k = 8; --k >= 0; ) {
					*p4++ = ((i >> k) & 0x01) - 1;
				}
			}
			ColorTransValid = trueblnr;
		}

		UpdateBWLuminanceCopy(top, left, bottom, right);
	}
}

/*
	Converts the changed region into ScalingBuff and presents the
	frame.

	Where the OpenGL path computed a raster position and blitted just
	the changed rectangle, the renderer is handed the whole frame plus
	the rectangle that should be visible, and the sampler does the
	scaling. Full screen panning and magnification are therefore no
	longer expressed here at all.

	The whole buffer is uploaded, so every pixel of ScalingBuff has
	to have been converted at least once before the first partial
	update. That holds because drawRect performs the first draw with
	the full screen rectangle.
*/
LOCALPROC MyDrawWithMetal(ui4r top, ui4r left, ui4r bottom, ui4r right)
{
	int srcX = 0;
	int srcY = 0;
	int srcW = vMacScreenWidth;
	int srcH = vMacScreenHeight;

	if (! HaveRenderer) {
		goto label_exit;
	}

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		if (top < ViewVStart) {
			top = ViewVStart;
		}
		if (left < ViewHStart) {
			left = ViewHStart;
		}
		if (bottom > ViewVStart + ViewVSize) {
			bottom = ViewVStart + ViewVSize;
		}
		if (right > ViewHStart + ViewHSize) {
			right = ViewHStart + ViewHSize;
		}

		if ((top >= bottom) || (left >= right)) {
			goto label_exit;
		}

		srcX = ViewHStart;
		srcY = ViewVStart;
		srcW = ViewHSize;
		srcH = ViewVSize;
	}
#endif

	UpdateLuminanceCopy(top, left, bottom, right);

	/*
		Conversion happens on whichever thread is emulating, but
		presentation must not: it reads the layer, whose geometry
		belongs to AppKit. So the converted frame is recorded here
		and MyUploadPendingFrame copies it out from the display link
		on the main thread. The emulator lock covers ScalingBuff, so
		the two never overlap.
	*/
	FrameSrcX = srcX;
	FrameSrcY = srcY;
	FrameSrcW = srcW;
	FrameSrcH = srcH;
#if 0 != vMacScreenDepth
	FrameIsColor = UseColorMode ? trueblnr : falseblnr;
#else
	FrameIsColor = falseblnr;
#endif
	FrameIsReady = trueblnr;

label_exit:
	;
}

/*
	Copies whatever the emulator last converted into the renderer's
	texture. Main thread only, with the emulator lock held by the
	caller: FrameIsReady and ScalingBuff belong to the lock. Returns
	whether there is now something for MyDrawUploadedFrame to draw.

	Only the copy happens under the lock. Taking a drawable can wait
	on the compositor, and encoding and committing are GPU side
	work; none of that needs emulator state, so the caller releases
	the lock first and then calls MyDrawUploadedFrame. The emulator
	thread can therefore run its next tick while the frame is being
	drawn, instead of waiting behind the GPU.
*/
LOCALFUNC blnr MyUploadPendingFrame(void)
{
	if (FrameIsReady) {
		FrameIsReady = falseblnr;

		MTLRenderer_Upload(ScalingBuff,
			FrameIsColor ? true : false,
			FrameSrcX, FrameSrcY, FrameSrcW, FrameSrcH);

		return trueblnr;
	}

	return falseblnr;
}

/*
	Draws the frame MyUploadPendingFrame last copied. Main thread
	only, without the emulator lock.
*/
LOCALPROC MyDrawUploadedFrame(void)
{
	MTLRenderer_Draw();
}


/* --- time, date, location --- */

#define dbglog_TimeStuff (0 && dbglog_HAVE)

LOCALVAR ui5b TrueEmulatedTime = 0;

LOCALVAR NSTimeInterval LatestTime;
LOCALVAR NSTimeInterval NextTickChangeTime;

#define MyTickDuration (1.0 / 60.14742)

LOCALVAR ui5b NewMacDateInSeconds;

LOCALVAR blnr EmulationWasInterrupted = falseblnr;

LOCALPROC UpdateTrueEmulatedTime(void)
{
	NSTimeInterval TimeDiff;

	LatestTime = [NSDate timeIntervalSinceReferenceDate];
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
#if 0 && dbglog_TimeStuff
				dbglog_writeln("got next tick");
#endif
				++TrueEmulatedTime;
				TimeDiff -= MyTickDuration;
				NextTickChangeTime += MyTickDuration;
			} while (TimeDiff >= 0.0);
		}
	} else if (TimeDiff < (-16 * MyTickDuration)) {
		/* clock set back, reset */
#if dbglog_TimeStuff
		dbglog_writeln("clock set back");
#endif

		NextTickChangeTime = LatestTime + MyTickDuration;
	}
}


LOCALVAR ui5b MyDateDelta;

/* --- parameter RAM persistence --- */

/*
	The guest's parameter RAM is kept in a file between runs, so that
	what is set in the Control Panel survives quitting. Without this
	every launch started from the defaults RTC_Init builds.

	The core exposes only a few calls for this, exported by whichever
	of RTCEMDEV.c or PMUEMDEV.c holds the PRAM for the emulated
	model; they are separate translation units, so declared here by
	hand, as Sony_EjectDriveFromHost is below.

	There is one file per emulated model, since the layouts differ,
	in Application Support. It starts with a header naming the model
	and size, and identifying the defaults of the build that wrote
	it; a file that does not match in every respect is ignored and
	the defaults are used, which is what happened before.

	Nothing that comes from the host is restored from the file: the
	clock is not part of the PRAM array at all, and the time zone and
	LocalTalk node hint are rewritten by the core after a restore.
*/

IMPORTFUNC ui5r EmPRAM_Size(void);
IMPORTFUNC ui5r EmPRAM_Model(void);
IMPORTFUNC ui5r EmPRAM_DefaultsId(void);
IMPORTPROC EmPRAM_Read(ui3p Buffer);
IMPORTPROC EmPRAM_Write(ui3p Buffer);
IMPORTPROC EmPRAM_TimeZoneChanged(void);

#define kMyPRAMMaxSize 256
#define kMyPRAMMagic 0x4D6F5052 /* 'MoPR' */
#define kMyPRAMFormat 1
#define kMyPRAMHeaderSize 20
	/* magic, format, model, size, defaults id; big endian */

LOCALVAR char *MyPRAMFilePath = nullpr;
LOCALVAR char *MyPRAMTempPath = nullpr;

/* What was read at launch, if the header was acceptable. */
LOCALVAR blnr MyPRAMHaveFileDat = falseblnr;
LOCALVAR ui5r MyPRAMFileDefaultsId;
LOCALVAR ui3b MyPRAMFileDat[kMyPRAMMaxSize];

/*
	Set once the emulator has initialised its PRAM and the saved copy
	has been applied. Until then there is nothing worth saving, and
	the core must not be written to.
*/
LOCALVAR blnr MyPRAMActive = falseblnr;

/* What the file holds now, to tell whether it needs rewriting. */
LOCALVAR blnr MyPRAMFileCurrent = falseblnr;
LOCALVAR ui3b MyPRAMFileShadow[kMyPRAMMaxSize];

/*
	Indexed by the kEmMd_ values in GLOBGLUE.h, which this
	translation unit cannot see.
*/
LOCALVAR const char *MyPRAMModelNames[] = {
	"MacTwig43", "MacTwiggy", "Mac128K", "Mac512Ke", "MacKanji",
	"MacPlus", "MacSE", "MacSEFDHD", "MacClassic", "MacPB100",
	"MacII", "MacIIx"
};

LOCALFUNC char *MyCStrCopy(const char *s)
{
	size_t n = strlen(s) + 1;
	char *p = (char *)malloc(n);

	if (nullpr != p) {
		memcpy(p, s, n);
	}

	return p;
}

/*
	Called on the main thread while starting up, before the emulator
	thread exists. Reads the file now so that the emulator thread
	never has to touch Foundation for it.
*/
LOCALPROC MyPRAM_Init(void)
{
	ui5r model = EmPRAM_Model();
	ui5r size = EmPRAM_Size();
	NSString *name;
	NSURL *dirURL;
	NSString *path;
	FILE *f;

	if (size > kMyPRAMMaxSize) {
		return;
	}

	dirURL = [[NSFileManager defaultManager]
		URLForDirectory: NSApplicationSupportDirectory
		inDomain: NSUserDomainMask
		appropriateForURL: nil
		create: YES
		error: NULL];
	if (nil == dirURL) {
		return;
	}
	dirURL = [dirURL URLByAppendingPathComponent: @kStrAppName
		isDirectory: YES];
	if (! [[NSFileManager defaultManager]
		createDirectoryAtURL: dirURL
		withIntermediateDirectories: YES
		attributes: nil
		error: NULL])
	{
		return;
	}

	if (model < sizeof(MyPRAMModelNames) / sizeof(char *)) {
		name = [NSString stringWithFormat: @"%s.pram",
			MyPRAMModelNames[model]];
	} else {
		name = [NSString stringWithFormat: @"Model%u.pram",
			(unsigned) model];
	}
	path = [[dirURL URLByAppendingPathComponent: name
		isDirectory: NO] path];

	MyPRAMFilePath = MyCStrCopy([path fileSystemRepresentation]);
	/*
		Named per process, so two copies of the application running
		the same model cannot write into each other's temporary
		file. Between them the last to save wins, which is the best
		a single file can do.
	*/
	MyPRAMTempPath = MyCStrCopy([[path
		stringByAppendingFormat: @".%d.tmp", (int) getpid()]
		fileSystemRepresentation]);
	if ((nullpr == MyPRAMFilePath) || (nullpr == MyPRAMTempPath)) {
		return;
	}

	f = fopen(MyPRAMFilePath, "rb");
	if (NULL != f) {
		ui3b header[kMyPRAMHeaderSize];

		if ((kMyPRAMHeaderSize
				== fread(header, 1, kMyPRAMHeaderSize, f))
			&& (size == fread(MyPRAMFileDat, 1, size, f))
			&& (EOF == fgetc(f))
			&& (kMyPRAMMagic == do_get_mem_long(&header[0]))
			&& (kMyPRAMFormat == do_get_mem_long(&header[4]))
			&& (model == do_get_mem_long(&header[8]))
			&& (size == do_get_mem_long(&header[12])))
		{
			MyPRAMFileDefaultsId = do_get_mem_long(&header[16]);
			MyPRAMHaveFileDat = trueblnr;
		}
		fclose(f);
	}
}

/*
	Writes to a temporary file and renames it over the old one, so a
	crash part way through leaves the previous copy rather than a
	truncated one.
*/
LOCALFUNC blnr MyPRAM_WriteFile(ui3p Dat)
{
	ui3b header[kMyPRAMHeaderSize];
	ui5r size = EmPRAM_Size();
	FILE *f;
	blnr IsOk = falseblnr;

	if ((nullpr == MyPRAMFilePath) || (nullpr == MyPRAMTempPath)) {
		return falseblnr;
	}

	do_put_mem_long(&header[0], kMyPRAMMagic);
	do_put_mem_long(&header[4], kMyPRAMFormat);
	do_put_mem_long(&header[8], EmPRAM_Model());
	do_put_mem_long(&header[12], size);
	do_put_mem_long(&header[16], EmPRAM_DefaultsId());

	f = fopen(MyPRAMTempPath, "wb");
	if (NULL != f) {
		if ((kMyPRAMHeaderSize
				== fwrite(header, 1, kMyPRAMHeaderSize, f))
			&& (size == fwrite(Dat, 1, size, f)))
		{
			IsOk = trueblnr;
		}
		if (0 != fclose(f)) {
			IsOk = falseblnr;
		}
		if (IsOk) {
			IsOk = (0 == rename(MyPRAMTempPath, MyPRAMFilePath));
		} else {
			(void) remove(MyPRAMTempPath);
		}
	}

	return IsOk;
}

/*
	Saves the PRAM if it differs from what the file holds. Cheap when
	nothing changed: one small copy and compare. Called once a second
	on the emulator thread, so a crash loses at most a second of
	changes, and once more at shutdown. Plain stdio from the
	emulator thread is fine here; it never runs on the audio thread.
*/
LOCALPROC MyPRAM_SaveIfChanged(void)
{
	ui3b Dat[kMyPRAMMaxSize];
	ui5r size = EmPRAM_Size();

	if ((! MyPRAMActive) || (nullpr == MyPRAMFilePath)) {
		return;
	}

	EmPRAM_Read(Dat);
	if ((! MyPRAMFileCurrent)
		|| (0 != memcmp(Dat, MyPRAMFileShadow, size)))
	{
		if (MyPRAM_WriteFile(Dat)) {
			memcpy(MyPRAMFileShadow, Dat, size);
			MyPRAMFileCurrent = trueblnr;
		}
	}
}

/*
	Applies the saved PRAM. Must run after RTC_Init has built the
	defaults, which replaces anything written earlier, and before the
	guest executes its first instruction, which reads PRAM almost at
	once. CheckDateTime is the hook for that: WaitForNextTick calls
	it on the emulator thread before every batch of ticks, the first
	time just after InitEmulation returns.
*/
LOCALPROC MyPRAM_Restore(void)
{
	ui5r size = EmPRAM_Size();

	if (MyPRAMHaveFileDat
		&& (EmPRAM_DefaultsId() == MyPRAMFileDefaultsId))
	{
		EmPRAM_Write(MyPRAMFileDat);
		memcpy(MyPRAMFileShadow, MyPRAMFileDat, size);
		MyPRAMFileCurrent = trueblnr;
	}

	MyPRAMActive = trueblnr;
}

LOCALPROC MyPRAM_UnInit(void)
{
	MyPRAM_SaveIfChanged();
	MyPRAMActive = falseblnr;

	if (nullpr != MyPRAMFilePath) {
		free(MyPRAMFilePath);
		MyPRAMFilePath = nullpr;
	}
	if (nullpr != MyPRAMTempPath) {
		free(MyPRAMTempPath);
		MyPRAMTempPath = nullpr;
	}
}

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

	MySetTimeZoneDat();

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

LOCALFUNC blnr CheckDateTime(void)
{
	ui5b NewMinute = ((ui5b)LatestTime) / 60;

	if ((! MyPRAMActive) && EmuThread_IsCurrent()) {
		MyPRAM_Restore();
	}

	if (MyTimeZoneCheckWanted || (NewMinute != MyTimeZoneCheckMinute)) {
		MyTimeZoneCheckWanted = falseblnr;
		MyTimeZoneCheckMinute = NewMinute;
		MyCheckTimeZone();
	}

	NewMacDateInSeconds = ((ui5b)LatestTime) + MyDateDelta;
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
	LatestTime = [NSDate timeIntervalSinceReferenceDate];
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
	LatestTime = [NSDate timeIntervalSinceReferenceDate];
	MyTimeZoneCheckMinute = ((ui5b)LatestTime) / 60;
	NewMacDateInSeconds = ((ui5b)LatestTime) + MyDateDelta;
	CurMacDateInSeconds = NewMacDateInSeconds;

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

/* --- sound --- */

#if MySoundEnabled

#define kLn2SoundBuffers 4 /* kSoundBuffers must be a power of two */
#define kSoundBuffers (1 << kLn2SoundBuffers)
#define kSoundBuffMask (kSoundBuffers - 1)

#define DesiredMinFilledSoundBuffs 3
	/*
		if too big then sound lags behind emulation.
		if too small then sound will have pauses.
	*/

#define kLnOneBuffLen 9
#define kLnAllBuffLen (kLn2SoundBuffers + kLnOneBuffLen)
#define kOneBuffLen (1UL << kLnOneBuffLen)
#define kAllBuffLen (1UL << kLnAllBuffLen)
#define kLnOneBuffSz (kLnOneBuffLen + kLn2SoundSampSz - 3)
#define kLnAllBuffSz (kLnAllBuffLen + kLn2SoundSampSz - 3)
#define kOneBuffSz (1UL << kLnOneBuffSz)
#define kAllBuffSz (1UL << kLnAllBuffSz)
#define kOneBuffMask (kOneBuffLen - 1)
#define kAllBuffMask (kAllBuffLen - 1)
#define dbhBufferSize (kAllBuffSz + kOneBuffSz)

#define dbglog_SoundStuff (0 && dbglog_HAVE)
#define dbglog_SoundBuffStats (0 && dbglog_HAVE)

/*
	The sample ring is a single producer, single consumer queue
	between two threads that must never wait for each other. The
	producer is the emulator thread, which calls MySound_BeginWrite
	and MySound_EndWrite sixteen times a tick from ASC_SubTick or
	MacSound_SubTick while holding the emulator lock. The consumer is
	CoreAudio's realtime render thread, in my_audio_callback, which
	must never take that lock: a render thread blocked behind the
	emulator is a dropout, and a priority inversion on top.

	So the boundary is two free running offsets and nothing else.
	TheFillOffset is written only by the producer, ThePlayOffset only
	by the consumer, and each is read by the other side. Samples in
	[ThePlayOffset, TheFillOffset) belong to the consumer; everything
	else in the ring belongs to the producer. They were `volatile`,
	which stops the compiler caching them but orders nothing: the
	render thread could see a new fill offset before the samples it
	covers. Now they are _Atomic, published with release once the
	block is fully written and converted, and loaded with acquire by
	the other side before it touches the samples the offset covers.

	The offsets are 16 bits and wrap; kAllBuffLen divides 65536, so
	their difference is always the number of samples between them.
*/

#include <stdatomic.h>

LOCALVAR tpSoundSamp TheSoundBuffer = nullpr;
static _Atomic ui4b ThePlayOffset;
static _Atomic ui4b TheFillOffset;
static _Atomic ui4b MinFilledSoundBuffs;
#if dbglog_SoundBuffStats
LOCALVAR ui4b MaxFilledSoundBuffs;
#endif
LOCALVAR ui4b TheWriteOffset;

/*
	Overflow. When the render thread falls behind (it is stopped, or
	the emulator is running faster than real time) there may be no
	free block to write into. The old answer was to rewind
	TheWriteOffset by a block and overwrite the newest one — but that
	block had already been published, so the producer was rewriting
	samples the render thread was entitled to be reading.

	Instead the decision is made once per block, at its first sample:
	if a whole block is free in the ring the block is written there,
	and since the consumer only ever frees space that decision cannot
	become wrong part way through. Otherwise the whole block goes to a
	private scratch block and is thrown away when it is complete. The
	core only writes inside the span it is handed (the volume and
	invert passes step back within it, never before it), so a span
	from scratch is indistinguishable to it.

	The scratch block is the spare kOneBuffSz at the end of the
	allocation (dbhBufferSize); the ring never reaches it because
	every ring access is masked with kAllBuffMask.
*/
LOCALVAR blnr SoundDroppingBlock = falseblnr;
LOCALVAR ui4b SoundDropOffset;
LOCALVAR ui5b SoundBlocksDropped = 0;

LOCALPROC MySound_Start0(void)
{
	/*
		Reset variables. The render callback is not running here:
		MySound_Start stops the unit, if a fade out still had it
		running, before calling this, and starts it only after.
	*/
	atomic_store_explicit(&ThePlayOffset, 0, memory_order_relaxed);
	atomic_store_explicit(&TheFillOffset, 0, memory_order_relaxed);
	TheWriteOffset = 0;
	SoundDroppingBlock = falseblnr;
	SoundDropOffset = 0;
	atomic_store_explicit(&MinFilledSoundBuffs, kSoundBuffers + 1,
		memory_order_relaxed);
#if dbglog_SoundBuffStats
	MaxFilledSoundBuffs = 0;
#endif
}

GLOBALOSGLUFUNC tpSoundSamp MySound_BeginWrite(ui4r n, ui4r *actL)
{
	ui4b BlockOffset = TheWriteOffset & kOneBuffMask;
	ui4b WriteBuffContig = kOneBuffLen - BlockOffset;

	if (WriteBuffContig < n) {
		n = WriteBuffContig;
	}

	if (0 == BlockOffset && ! SoundDroppingBlock) {
		/*
			Acquire pairs with the release in my_audio_callback:
			once the play offset says a block is free, the render
			thread has finished reading it.
		*/
		ui4b PlayOffset = atomic_load_explicit(&ThePlayOffset,
			memory_order_acquire);
		ui4b ToFillLen = kAllBuffLen - (ui4b)(TheWriteOffset - PlayOffset);

		if (ToFillLen < kOneBuffLen) {
#if dbglog_SoundStuff
			dbglog_writeln("sound buffer over flow");
#endif
			SoundDroppingBlock = trueblnr;
			SoundDropOffset = 0;
		}
	}

	if (SoundDroppingBlock) {
		if (n > kOneBuffLen - SoundDropOffset) {
			n = kOneBuffLen - SoundDropOffset;
		}
		*actL = n;
		return TheSoundBuffer + kAllBuffLen + SoundDropOffset;
	}

	*actL = n;
	return TheSoundBuffer + (TheWriteOffset & kAllBuffMask);
}

#if 4 == kLn2SoundSampSz
LOCALPROC ConvertSoundBlockToNative(tpSoundSamp p)
{
	int i;

	for (i = kOneBuffLen; --i >= 0; ) {
		*p++ -= 0x8000;
	}
}
#else
#define ConvertSoundBlockToNative(p)
#endif

LOCALPROC MySound_WroteABlock(void)
{
#if (4 == kLn2SoundSampSz)
	ui4b PrevWriteOffset = TheWriteOffset - kOneBuffLen;
	tpSoundSamp p = TheSoundBuffer + (PrevWriteOffset & kAllBuffMask);
#endif

#if dbglog_SoundStuff
	dbglog_writeln("enter MySound_WroteABlock");
#endif

	ConvertSoundBlockToNative(p);

	/*
		Release: the samples just written and converted must be
		visible to the render thread before the offset that hands
		them over.
	*/
	atomic_store_explicit(&TheFillOffset, TheWriteOffset,
		memory_order_release);

#if dbglog_SoundBuffStats
	{
		ui4b ToPlayLen = TheWriteOffset
			- atomic_load_explicit(&ThePlayOffset,
				memory_order_relaxed);
		ui4b ToPlayBuffs = ToPlayLen >> kLnOneBuffLen;

		if (ToPlayBuffs > MaxFilledSoundBuffs) {
			MaxFilledSoundBuffs = ToPlayBuffs;
		}
	}
#endif
}

LOCALFUNC blnr MySound_EndWrite0(ui4r actL)
{
	blnr v;

	if (SoundDroppingBlock) {
		/*
			Nothing in the ring changes, so there is nothing to
			publish; the write offset stays put and the next block
			gets a fresh chance at the ring.
		*/
		SoundDropOffset += actL;
		if (SoundDropOffset >= kOneBuffLen) {
			SoundDroppingBlock = falseblnr;
			SoundDropOffset = 0;
			++SoundBlocksDropped;
		}
		return falseblnr;
	}

	TheWriteOffset += actL;

	if (0 != (TheWriteOffset & kOneBuffMask)) {
		v = falseblnr;
	} else {
		/* just finished a block */

		MySound_WroteABlock();

		v = trueblnr;
	}

	return v;
}

LOCALPROC MySound_SecondNotify0(void)
{
	/*
		The render thread lowers MinFilledSoundBuffs towards the
		least the ring held during this second; this thread reads it
		and starts a new second. An exchange does both at once, so a
		minimum the callback records in between is never lost.
		Relaxed is enough: it is a statistic, not a guard on memory.
	*/
	ui4b MinFilled = atomic_exchange_explicit(&MinFilledSoundBuffs,
		kSoundBuffers + 1, memory_order_relaxed);

	if (MinFilled <= kSoundBuffers) {
		if (MinFilled > DesiredMinFilledSoundBuffs) {
#if dbglog_SoundStuff
			dbglog_writeln("MinFilledSoundBuffs too high");
#endif
			NextTickChangeTime += MyTickDuration;
		} else if (MinFilled < DesiredMinFilledSoundBuffs) {
#if dbglog_SoundStuff
			dbglog_writeln("MinFilledSoundBuffs too low");
#endif
			++TrueEmulatedTime;
		}
#if dbglog_SoundBuffStats
		dbglog_writelnNum("MinFilledSoundBuffs", MinFilled);
		dbglog_writelnNum("MaxFilledSoundBuffs",
			MaxFilledSoundBuffs);
		dbglog_writelnNum("SoundBlocksDropped", SoundBlocksDropped);
		MaxFilledSoundBuffs = 0;
#endif
	}
}

typedef ui4r trSoundTemp;

#define kCenterTempSound 0x8000

#define AudioStepVal 0x0040

#if 3 == kLn2SoundSampSz
#define ConvertTempSoundSampleFromNative(v) ((v) << 8)
#elif 4 == kLn2SoundSampSz
#define ConvertTempSoundSampleFromNative(v) ((v) + kCenterSound)
#else
#error "unsupported kLn2SoundSampSz"
#endif

#if 3 == kLn2SoundSampSz
#define ConvertTempSoundSampleToNative(v) ((v) >> 8)
#elif 4 == kLn2SoundSampSz
#define ConvertTempSoundSampleToNative(v) ((v) - kCenterSound)
#else
#error "unsupported kLn2SoundSampSz"
#endif

LOCALPROC SoundRampTo(trSoundTemp *last_val, trSoundTemp dst_val,
	tpSoundSamp *stream, int *len)
{
	trSoundTemp diff;
	tpSoundSamp p = *stream;
	int n = *len;
	trSoundTemp v1 = *last_val;

	while ((v1 != dst_val) && (0 != n)) {
		if (v1 > dst_val) {
			diff = v1 - dst_val;
			if (diff > AudioStepVal) {
				v1 -= AudioStepVal;
			} else {
				v1 = dst_val;
			}
		} else {
			diff = dst_val - v1;
			if (diff > AudioStepVal) {
				v1 += AudioStepVal;
			} else {
				v1 = dst_val;
			}
		}

		--n;
		*p++ = ConvertTempSoundSampleToNative(v1);
	}

	*stream = p;
	*len = n;
	*last_val = v1;
}

/*
	Of the fields shared with the render thread, wantplaying is the
	emulator's request to start or stop and lastv is the callback's
	report of where the output level has got to. When wantplaying is
	cleared the callback ramps the output to the centre value, so the
	stop fades rather than clicks, and once it gets there it sets
	RampDone. Release on each store and acquire on each cross thread
	load make that handshake an ordered one. HaveStartedPlaying is
	reset by MySound_Start while the unit is stopped and otherwise
	belongs to the callback, but it is atomic too so that no field
	here is shared without being.

	UnitRunning is main thread and emulator thread state, under the
	emulator lock: whether AudioOutputUnitStart has been called
	without a matching AudioOutputUnitStop yet. StopQueued says a
	block that will do that stop is waiting on the main queue.
*/
struct MySoundR {
	tpSoundSamp fTheSoundBuffer;
	_Atomic ui4b (*fPlayOffset);
	_Atomic ui4b (*fFillOffset);
	_Atomic ui4b (*fMinFilledSoundBuffs);

	_Atomic trSoundTemp lastv;

	blnr enabled;
	blnr UnitRunning;
	blnr StopQueued;
	_Atomic blnr wantplaying;
	_Atomic blnr HaveStartedPlaying;
	_Atomic blnr RampDone;

	AudioUnit outputAudioUnit;
};
typedef struct MySoundR MySoundR;

LOCALPROC my_audio_callback(void *udata, void *stream, int len)
{
	ui4b ToPlayLen;
	ui4b FilledSoundBuffs;
	int i;
	MySoundR *datp = (MySoundR *)udata;
	tpSoundSamp CurSoundBuffer = datp->fTheSoundBuffer;
	/* This thread is the only writer of the play offset and lastv. */
	ui4b CurPlayOffset = atomic_load_explicit(datp->fPlayOffset,
		memory_order_relaxed);
	trSoundTemp v1 = atomic_load_explicit(&datp->lastv,
		memory_order_relaxed);
	ui4b MinFilled;
	tpSoundSamp dst = (tpSoundSamp)stream;

#if kLn2SoundSampSz > 3
	len >>= (kLn2SoundSampSz - 3);
#endif

#if dbglog_SoundStuff
	dbglog_writeln("Enter my_audio_callback");
	dbglog_writelnNum("len", len);
#endif

label_retry:
	/*
		Acquire pairs with the release in MySound_WroteABlock: every
		sample below the fill offset is fully written before it is
		read here.
	*/
	ToPlayLen = atomic_load_explicit(datp->fFillOffset,
		memory_order_acquire) - CurPlayOffset;
	FilledSoundBuffs = ToPlayLen >> kLnOneBuffLen;

	if (! atomic_load_explicit(&datp->wantplaying,
		memory_order_acquire))
	{
#if dbglog_SoundStuff
		dbglog_writeln("playing end transistion");
#endif

		SoundRampTo(&v1, kCenterTempSound, &dst, &len);

		if (kCenterTempSound == v1) {
			/*
				The fade out is complete. Release pairs with the
				acquire in MySound_StopUnitIfRampDone, which may
				now stop the unit without a click.
			*/
			atomic_store_explicit(&datp->RampDone, trueblnr,
				memory_order_release);
		}

		ToPlayLen = 0;
	} else if (! atomic_load_explicit(&datp->HaveStartedPlaying,
		memory_order_relaxed))
	{
#if dbglog_SoundStuff
		dbglog_writeln("playing start block");
#endif

		if ((ToPlayLen >> kLnOneBuffLen) < 8) {
			ToPlayLen = 0;
		} else {
			tpSoundSamp p = datp->fTheSoundBuffer
				+ (CurPlayOffset & kAllBuffMask);
			trSoundTemp v2 = ConvertTempSoundSampleFromNative(*p);

#if dbglog_SoundStuff
			dbglog_writeln("have enough samples to start");
#endif

			SoundRampTo(&v1, v2, &dst, &len);

			if (v1 == v2) {
#if dbglog_SoundStuff
				dbglog_writeln("finished start transition");
#endif

				atomic_store_explicit(&datp->HaveStartedPlaying,
					trueblnr, memory_order_relaxed);
			}
		}
	}

	if (0 == len) {
		/* done */

		/*
			Atomic minimum: MySound_SecondNotify0 may exchange in a
			fresh value between the load and the store, and a plain
			store would overwrite it with a stale minimum.
		*/
		MinFilled = atomic_load_explicit(datp->fMinFilledSoundBuffs,
			memory_order_relaxed);
		while ((FilledSoundBuffs < MinFilled)
			&& ! atomic_compare_exchange_weak_explicit(
				datp->fMinFilledSoundBuffs, &MinFilled,
				FilledSoundBuffs,
				memory_order_relaxed, memory_order_relaxed))
		{
		}
	} else if (0 == ToPlayLen) {

#if dbglog_SoundStuff
		dbglog_writeln("under run");
#endif

		for (i = 0; i < len; ++i) {
			*dst++ = ConvertTempSoundSampleToNative(v1);
		}
		/* zero is the least possible, so a plain store is a minimum */
		atomic_store_explicit(datp->fMinFilledSoundBuffs, 0,
			memory_order_relaxed);
	} else {
		ui4b PlayBuffContig = kAllBuffLen
			- (CurPlayOffset & kAllBuffMask);
		tpSoundSamp p = CurSoundBuffer
			+ (CurPlayOffset & kAllBuffMask);

		if (ToPlayLen > PlayBuffContig) {
			ToPlayLen = PlayBuffContig;
		}
		if (ToPlayLen > len) {
			ToPlayLen = len;
		}

		for (i = 0; i < ToPlayLen; ++i) {
			*dst++ = *p++;
		}
		v1 = ConvertTempSoundSampleFromNative(p[-1]);

		CurPlayOffset += ToPlayLen;
		len -= ToPlayLen;

		/*
			Release: the copy out of the ring is complete before the
			producer, loading this with acquire, may reuse the space.
		*/
		atomic_store_explicit(datp->fPlayOffset, CurPlayOffset,
			memory_order_release);

		goto label_retry;
	}

	atomic_store_explicit(&datp->lastv, v1, memory_order_release);
}

LOCALFUNC OSStatus audioCallback(
	void                       *inRefCon,
	AudioUnitRenderActionFlags *ioActionFlags,
	const AudioTimeStamp       *inTimeStamp,
	UInt32                     inBusNumber,
	UInt32                     inNumberFrames,
	AudioBufferList            *ioData)
{
	AudioBuffer *abuf;
	UInt32 i;
	UInt32 n = ioData->mNumberBuffers;

#if dbglog_SoundStuff
	dbglog_writeln("Enter audioCallback");
	dbglog_writelnNum("mNumberBuffers", n);
#endif

	for (i = 0; i < n; i++) {
		abuf = &ioData->mBuffers[i];
		my_audio_callback(inRefCon,
			abuf->mData, abuf->mDataByteSize);
	}

	return 0;
}

LOCALVAR MySoundR cur_audio;

LOCALPROC ZapAudioVars(void)
{
	memset(&cur_audio, 0, sizeof(MySoundR));
}

/*
	Stops the audio unit now. Emulator lock held.
*/
LOCALPROC MySound_StopUnit(void)
{
	if (cur_audio.UnitRunning) {
		OSStatus result;

		cur_audio.UnitRunning = falseblnr;

		if (noErr != (result = AudioOutputUnitStop(
			cur_audio.outputAudioUnit)))
		{
#if dbglog_HAVE
			dbglog_writeln("AudioOutputUnitStop fails");
#endif
		}

		(void) result; /* ignore any errors */
	}
}

/*
	Runs on the main queue some time after MySound_Stop. Stops the
	unit once the render callback has faded the output to the
	centre, or gives up waiting after about half a second, as the
	old code did. Checks that a stop is still wanted, since a
	MySound_Start may have come and gone in between.
*/
LOCALPROC MySound_StopUnitIfRampDone(void);

LOCALPROC MySound_QueueStopCheck(void)
{
	cur_audio.StopQueued = trueblnr;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
			10 * NSEC_PER_MSEC),
		dispatch_get_main_queue(), ^{
			MySound_StopUnitIfRampDone();
		});
}

LOCALVAR int MySoundStopRetries = 0;

LOCALPROC MySound_StopUnitIfRampDone(void)
{
	EmuLock_Acquire();

	cur_audio.StopQueued = falseblnr;

	if (cur_audio.UnitRunning
		&& ! atomic_load_explicit(&cur_audio.wantplaying,
			memory_order_relaxed))
	{
		/* Acquire pairs with the release in my_audio_callback. */
		if (atomic_load_explicit(&cur_audio.RampDone,
			memory_order_acquire))
		{
#if dbglog_SoundStuff
			dbglog_writeln("reached kCenterTempSound");
#endif
			MySound_StopUnit();
		} else if (++MySoundStopRetries >= 50) {
#if dbglog_SoundStuff
			dbglog_writeln("retry limit reached");
#endif
			MySound_StopUnit();
		} else {
			MySound_QueueStopCheck();
		}
	}

	EmuLock_Release();
}

/*
	Asks for sound to stop and returns at once. The render callback
	fades the output to the centre on its own, and the unit is
	stopped later from the main queue. This used to sleep in 10 ms
	steps, up to half a second, waiting for the fade, with the
	emulator lock held throughout; a pause therefore froze the
	interface for as long as the fade took.

	At teardown there is no later: MySound_UnInit stops the unit
	itself, and the queued block, if it ever runs, finds nothing to
	do.
*/
LOCALPROC MySound_Stop(void)
{
#if dbglog_SoundStuff
	dbglog_writeln("enter MySound_Stop");
#endif

	if (atomic_load_explicit(&cur_audio.wantplaying,
		memory_order_relaxed))
	{
		atomic_store_explicit(&cur_audio.RampDone, falseblnr,
			memory_order_relaxed);
		atomic_store_explicit(&cur_audio.wantplaying, falseblnr,
			memory_order_release);

		MySoundStopRetries = 0;
		if (! cur_audio.StopQueued) {
			MySound_QueueStopCheck();
		}
	}

#if dbglog_SoundStuff
	dbglog_writeln("leave MySound_Stop");
#endif
}

LOCALPROC MySound_Start(void)
{
	if ((! atomic_load_explicit(&cur_audio.wantplaying,
		memory_order_relaxed)) && cur_audio.enabled)
	{
		OSStatus result;

#if dbglog_SoundStuff
		dbglog_writeln("enter MySound_Start");
#endif

		/*
			A stop may still be fading out: MySound_Stop returns
			before the unit is stopped. The ring is about to be
			reset, which the callback must not be reading through,
			so the unit is stopped here first and started afresh.
			Any check still queued finds UnitRunning and
			wantplaying both saying there is nothing to do.
		*/
		MySound_StopUnit();

		MySound_Start0();
		atomic_store_explicit(&cur_audio.lastv, kCenterTempSound,
			memory_order_relaxed);
		atomic_store_explicit(&cur_audio.HaveStartedPlaying, falseblnr,
			memory_order_relaxed);
		atomic_store_explicit(&cur_audio.RampDone, falseblnr,
			memory_order_relaxed);
		/* Release publishes the resets above to the render thread. */
		atomic_store_explicit(&cur_audio.wantplaying, trueblnr,
			memory_order_release);

		if (noErr != (result = AudioOutputUnitStart(
			cur_audio.outputAudioUnit)))
		{
#if dbglog_HAVE
			dbglog_writeln("AudioOutputUnitStart fails");
#endif
			atomic_store_explicit(&cur_audio.wantplaying, falseblnr,
				memory_order_relaxed);
		} else {
			cur_audio.UnitRunning = trueblnr;
		}

#if dbglog_SoundStuff
		dbglog_writeln("leave MySound_Start");
#endif

		(void) result; /* ignore any errors */
	}
}

#ifndef UseAudioComp
#define UseAudioComp 1
#endif

LOCALPROC MySound_UnInit(void)
{
	if (cur_audio.enabled) {
		OSStatus result;
		struct AURenderCallbackStruct callback;

		cur_audio.enabled = falseblnr;

		/*
			MySound_Stop, called just before this, only asks; the
			unit is still running until the fade completes. Nothing
			will run the queued stop after main returns, so stop it
			here, before the callback is removed and the unit
			disposed of.
		*/
		MySound_StopUnit();

		/* Remove the input callback */
		callback.inputProc = 0;
		callback.inputProcRefCon = 0;

		if (noErr != (result = AudioUnitSetProperty(
			cur_audio.outputAudioUnit,
			kAudioUnitProperty_SetRenderCallback,
			kAudioUnitScope_Input,
			0,
			&callback,
			sizeof(callback))))
		{
#if dbglog_HAVE
			dbglog_writeln("AudioUnitSetProperty fails"
				"(kAudioUnitProperty_SetRenderCallback)");
#endif
		}

		(void) result; /* ignore any errors */

#if UseAudioComp
		if (noErr != (result = AudioComponentInstanceDispose(
			cur_audio.outputAudioUnit)))
		{
#if dbglog_HAVE
			dbglog_writeln("AudioComponentInstanceDispose fails"
				" in MySound_UnInit");
#endif
		}
#else
		if (noErr != (result = CloseComponent(
			cur_audio.outputAudioUnit)))
		{
#if dbglog_HAVE
			dbglog_writeln("CloseComponent fails in MySound_UnInit");
#endif
		}
#endif

		(void) result; /* ignore any errors */
	}
}

#define SOUND_SAMPLERATE 22255 /* = round(7833600 * 2 / 704) */

LOCALFUNC blnr MySound_Init(void)
{
	OSStatus result = noErr;
#if UseAudioComp
	AudioComponent comp;
	AudioComponentDescription desc;
#else
	Component comp;
	ComponentDescription desc;
#endif
	struct AURenderCallbackStruct callback;
	AudioStreamBasicDescription requestedDesc;

	cur_audio.fTheSoundBuffer = TheSoundBuffer;
	cur_audio.fPlayOffset = &ThePlayOffset;
	cur_audio.fFillOffset = &TheFillOffset;
	cur_audio.fMinFilledSoundBuffs = &MinFilledSoundBuffs;
	atomic_store_explicit(&cur_audio.wantplaying, falseblnr,
		memory_order_relaxed);

	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_DefaultOutput;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;


	requestedDesc.mFormatID = kAudioFormatLinearPCM;
	requestedDesc.mFormatFlags = kLinearPCMFormatFlagIsPacked
#if 3 != kLn2SoundSampSz
		| kLinearPCMFormatFlagIsSignedInteger
#endif
		;
	requestedDesc.mChannelsPerFrame = 1;
	requestedDesc.mSampleRate = SOUND_SAMPLERATE;

	requestedDesc.mBitsPerChannel = (1 << kLn2SoundSampSz);
#if 0
	requestedDesc.mFormatFlags |= kLinearPCMFormatFlagIsSignedInteger;
#endif
#if 0
	requestedDesc.mFormatFlags |= kLinearPCMFormatFlagIsBigEndian;
#endif

	requestedDesc.mFramesPerPacket = 1;
	requestedDesc.mBytesPerFrame = (requestedDesc.mBitsPerChannel
		* requestedDesc.mChannelsPerFrame) >> 3;
	requestedDesc.mBytesPerPacket = requestedDesc.mBytesPerFrame
		* requestedDesc.mFramesPerPacket;


	callback.inputProc = audioCallback;
	callback.inputProcRefCon = &cur_audio;

#if UseAudioComp
	if (NULL == (comp = AudioComponentFindNext(NULL, &desc)))
	{
#if dbglog_HAVE
		dbglog_writeln("Failed to start CoreAudio: "
			"AudioComponentFindNext returned NULL");
#endif
	} else
#else
	if (NULL == (comp = FindNextComponent(NULL, &desc)))
	{
#if dbglog_HAVE
		dbglog_writeln("Failed to start CoreAudio: "
			"FindNextComponent returned NULL");
#endif
	} else
#endif

#if UseAudioComp
	if (noErr != (result = AudioComponentInstanceNew(
		comp, &cur_audio.outputAudioUnit)))
	{
#if dbglog_HAVE
		dbglog_writeln("Failed to start CoreAudio:"
			" AudioComponentInstanceNew");
#endif
	} else
#else
	if (noErr != (result = OpenAComponent(
		comp, &cur_audio.outputAudioUnit)))
	{
#if dbglog_HAVE
		dbglog_writeln("Failed to start CoreAudio: OpenAComponent");
#endif
	} else
#endif

	if (noErr != (result = AudioUnitInitialize(
		cur_audio.outputAudioUnit)))
	{
#if dbglog_HAVE
		dbglog_writeln(
			"Failed to start CoreAudio: AudioUnitInitialize");
#endif
	} else

	if (noErr != (result = AudioUnitSetProperty(
		cur_audio.outputAudioUnit,
		kAudioUnitProperty_StreamFormat,
		kAudioUnitScope_Input,
		0,
		&requestedDesc,
		sizeof(requestedDesc))))
	{
#if dbglog_HAVE
		dbglog_writeln("Failed to start CoreAudio: "
			"AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
#endif
	} else

	if (noErr != (result = AudioUnitSetProperty(
		cur_audio.outputAudioUnit,
		kAudioUnitProperty_SetRenderCallback,
		kAudioUnitScope_Input,
		0,
		&callback,
		sizeof(callback))))
	{
#if dbglog_HAVE
		dbglog_writeln("Failed to start CoreAudio: "
			"AudioUnitSetProperty(kAudioUnitProperty_SetInputCallback)"
			);
#endif
	} else

	{
		cur_audio.enabled = trueblnr;

		MySound_Start();
			/*
				This should be taken care of by LeaveSpeedStopped,
				but since takes a while to get going properly,
				start early.
			*/
	}

	(void) result; /* ignore any errors */
	return trueblnr; /* keep going, even if no sound */
}

GLOBALOSGLUPROC MySound_EndWrite(ui4r actL)
{
	if (MySound_EndWrite0(actL)) {
	}
}

LOCALPROC MySound_SecondNotify(void)
{
	if (cur_audio.enabled) {
		MySound_SecondNotify0();
	}
}

#endif

/*
	The menu bar is built in Swift, in APPMENUS.swift. What used to
	be here was a three item stub — application, File with one Open
	item, and Special whose only entry dropped into the character
	cell overlay — because almost every command lived in that overlay
	rather than in the menu bar.
*/
LOCALPROC MyMenuSetup(void)
{
	[MNVMMenuController installMainMenu];
}



/* --- video out --- */


LOCALPROC HaveChangedScreenBuff(ui4r top, ui4r left,
	ui4r bottom, ui4r right)
{
	/*
		This used to be gated on [MyNSview canDraw], which was
		right for a view that drew through drawRect but is wrong
		for a layer hosting Metal view, and is deprecated as of
		macOS 10.14 for exactly that reason.

		canDraw answers NO while the window is not yet visible or
		is occluded. Since Metal presents through the layer rather
		than through AppKit's drawing machinery, that gate simply
		dropped frames: the window stayed black whenever drawing
		began before it came to the front, and drew correctly
		whenever it happened to be frontmost first. The symptom was
		intermittent, which is what made it worth a comment.

		MyDrawWithMetal already declines to draw when there is no
		renderer, so no further check is needed here.
	*/
	MyDrawWithMetal(top, left, bottom, right);
}

/*
	Converts and hands off the changed rectangle, if there is one.
	ScreenClearChanges leaves the rectangle empty, Bottom below Top,
	so a tick in which nothing on the guest screen changed costs
	nothing here and no frame is marked ready.
*/
LOCALPROC MyDrawChangesAndClear(void)
{
	if (ScreenChangedBottom > ScreenChangedTop) {
		HaveChangedScreenBuff(ScreenChangedTop, ScreenChangedLeft,
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

LOCALPROC DisableKeyRepeat(void)
{
}

LOCALPROC RestoreKeyRepeat(void)
{
}

LOCALPROC ReconnectKeyCodes3(void)
{
}

LOCALPROC DisconnectKeyCodes3(void)
{
	DisconnectKeyCodes2();
	MyMouseButtonSet(falseblnr);
}

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

/* --- main window creation and disposal --- */

LOCALFUNC blnr Screen_Init(void)
{
#if 0
	if (noErr != Gestalt(gestaltSystemVersion,
		&cur_video.system_version))
	{
		cur_video.system_version = 0;
	}
#endif

#if 0
#define MyCGMainDisplayID CGMainDisplayID
	CGDirectDisplayID CurMainDisplayID = MyCGMainDisplayID();

	cur_video.width = (ui5b) CGDisplayPixelsWide(CurMainDisplayID);
	cur_video.height = (ui5b) CGDisplayPixelsHigh(CurMainDisplayID);
#endif

	InitKeyCodes();

	return trueblnr;
}

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
			since drawRect is called very rarely, didn't
			bother above to calculate actual coordinates
			to pass to MyDrawWithMetal.

			if it did matter, could get list of dirty
			rectangles, instead of dirtyRect that is
			supposed to be their union. as follows:
		*/
#if 0
		{
			const NSRect *rectList;
			NSInteger count;
			NSInteger i;

			[self getRectsBeingDrawn:&rectList count:&count];
			for (i = 0; i < count; i++) {
				MyDrawWithMetal(<converted> rectList[i]);
			}
		}
#endif
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

LOCALPROC QZ_SetCaption(void)
{
#if 0
	NSString *string =
		[[NSString alloc] initWithUTF8String: kStrAppName];
#endif
	[MyWindow setTitle: myAppName /* string */];
#if 0
	[string release];
#endif
}

enum {
	kMagStateNormal,
#if EnableMagnify
	kMagStateMagnifgy,
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

		GLhOffset = botleftPos.x - AllScrnBounds.origin.x;
		GLvOffset = (botleftPos.y - AllScrnBounds.origin.y)
			+ ((NewWindowHeight < MainScrnBounds.size.height)
				? NewWindowHeight : MainScrnBounds.size.height);

		hOffset = GLhOffset;
		vOffset = AllScrnBounds.size.height - GLvOffset;

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
			WinIndx = kMagStateMagnifgy;
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

		GLhOffset = 0;
		GLvOffset = NewWindowHeight;

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
	QZ_SetCaption();
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
	short f_GLhOffset;
	short f_GLvOffset;
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
	r->f_GLhOffset = GLhOffset;
	r->f_GLvOffset = GLvOffset;
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
	GLhOffset = r->f_GLhOffset;
	GLvOffset = r->f_GLvOffset;
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
			UseMagnify ? kMagStateMagnifgy : kMagStateNormal;
		int NewWinState =
			WantFullScreen ? kWinStateFullScreen : kWinStateWindowed;
		int NewMagState = WinMagStates[NewWinState];

		WinMagStates[OldWinState] = OldMagState;
		if (kMagStateAuto != NewMagState) {
			WantMagnify = (kMagStateMagnifgy == NewMagState);
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
	ReconnectKeyCodes3();
	DisableKeyRepeat();
	EmulationWasInterrupted = trueblnr;
}

LOCALPROC EnterBackground(void)
{
	RestoreKeyRepeat();
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
		(gBackgroundFlag && ! RunInBackground
#if EnableAutoSlow && 0
			&& (QuietSubTicks >= 4092)
#endif
		)))
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
	}

#if 1
	/*
		Check if actual cursor visibility is what it should be.
		If move mouse to dock then cursor is made visible, but then
		if move directly to our window, cursor is not hidden again.
	*/
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
#endif
}

/* --- main program flow --- */

GLOBALOSGLUFUNC blnr ExtraTimeNotOver(void)
{
	UpdateTrueEmulatedTime();
	return TrueEmulatedTime == OnTrueTime;
}

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
	Keyboard_UpdateKeyMap2(Keyboard_RemapMac(scancode), down);
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
			/*
				int button = QZ_OtherMouseButtonToSDL(
					[event buttonNumber]);
			*/
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
			/*
				int button = QZ_OtherMouseButtonToSDL(
					[event buttonNumber]);
			*/
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

LOCALPROC MySleepSeconds(double seconds)
{
	struct timespec rqt;
	struct timespec rmt;

	if (seconds <= 0.0) {
		return;
	}

	rqt.tv_sec = (time_t)seconds;
	rqt.tv_nsec = (long)((seconds - (double)rqt.tv_sec) * 1000000000.0);

	(void) nanosleep(&rqt, &rmt);
}

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
}

GLOBALOSGLUPROC WaitForNextTick(void)
{
	blnr onEmuThread = EmuThread_IsCurrent();
	blnr releasedLock = falseblnr;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

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
			EmuLock_Release();
			MySleepSeconds(0.010);
			EmuLock_Acquire();
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
				EmuLock_Release();
				MySleepSeconds(inTimeout);
				EmuLock_Acquire();
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
	[pool release];
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

	MyMenuSetup();

	MyApplicationDelegate = [[MyClassApplicationDelegate alloc] init];
	[MyNSApp setDelegate: MyApplicationDelegate];

#if 0
	[MyNSApp finishLaunching];
#endif
		/*
			If use finishLaunching, after
			Hide Moof command, activating from
			Dock doesn't bring our window forward.
			Using "run" instead fixes this.
			As suggested by Hugues De Keyzer in
			http://forums.libsdl.org/ post.
			SDL 2.0 doesn't use this
			technique. Was another solution found?
		*/

	[MyNSApp run];
		/*
			our applicationDidFinishLaunching forces
			immediate halt.
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
#if 0 /* for testing start up error reporting */
	MacMsg(kStrOutOfMemTitle, kStrOutOfMemMessage, trueblnr);
	return falseblnr;
#else
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
#endif
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
	if (Screen_Init())
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

#if dbglog_HAVE && 0
IMPORTPROC DumpRTC(void);
#endif

LOCALPROC UnInitOSGLU(void)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

#if dbglog_HAVE && 0
	DumpRTC();
#endif

#if EmLocalTalk
	UnInitLocalTalk();
#endif
	RestoreKeyRepeat();
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
