/*
	CCODISKS.h

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
	DISKS and ROM for the Cocoa backend

	Path lookup and alias resolution, the disk image files behind the
	drives, advisory locks, disk insertion, creation of new images,
	and loading the ROM.

	Not a header in the usual sense: this is a fragment of
	OSGLUCCO.m, #included by it exactly once, in place, so that the
	backend stays a single translation unit. LOCALVAR and LOCALPROC
	are file static and the order of inclusion matters.
*/

/* --- drives --- */

LOCALFUNC blnr FindNamedChildPath(NSString *parentPath,
	char *ChildName, NSString **childPath)
{
	blnr v = falseblnr;
	NSString *ss = NSStringFromSubstCStr(ChildName);
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

/*
	Advisory locks on the image files, so that two copies of the
	emulator do not write into the same disk image at once. flock
	rather than fcntl: a whole file lock is all that is needed, and
	flock's lock belongs to the open file rather than the process,
	so it is released when the image is closed.
*/

LOCALFUNC blnr MyLockFile(FILE *refnum)
{
	blnr IsOk = falseblnr;
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

	return IsOk;
}

LOCALPROC MyUnlockFile(FILE *refnum)
{
	int fd = fileno(refnum);

	(void) flock(fd, LOCK_UN);
}

LOCALFUNC tMacErr vSonyEject0(tDrive Drive_No, blnr deleteit)
{
	FILE *refnum = Drives[Drive_No];

	DiskEjectedNotify(Drive_No);

	MyUnlockFile(refnum);

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
		/*
			This runs on the emulator thread, which has no pool of
			its own, and both lastPathComponent and the NSData in
			NSStringToRomanPbuf are autoreleased.
		*/
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

		if (locked || MyLockFile(refnum)) {
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

	if (mnvm_fnfErr == (err = LoadMacRomFrom(MyDataPath)))
	if (mnvm_fnfErr == (err = LoadMacRomFromPrefDir()))
	if (mnvm_fnfErr == (err = LoadMacRomFromGlobalDir()))
	{
	}

	(void) err; /* ignore any errors */
	return trueblnr; /* keep launching Moof, regardless */
}
