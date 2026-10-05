/*
	CCOPRAM.h

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
	PRAM persistence for the Cocoa backend

	Saving the guest's parameter RAM between runs.

	Not a header in the usual sense: this is a fragment of
	OSGLUCCO.m, #included exactly once, in place, from CCOTIME.h,
	so that the backend stays a single translation unit. LOCALVAR
	and LOCALPROC are file static and the order of inclusion
	matters.
*/

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
