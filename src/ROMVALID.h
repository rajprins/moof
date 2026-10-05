/*
	ROMVALID.h

	Copyright (C) 2007 Paul C. Pratt
	Copyright (C) 2026 Moof contributors

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
	ROM VALIDation

	The part of the old CONTROLM.h that checks a loaded ROM image,
	waits at startup until there is one, and reports the problems
	found along the way.

	Every message here goes through MacMsg, which parks it until the
	host presents it as a native alert from CheckSavedMacMsg. Nothing
	is drawn into the emulated screen any more.
*/

#ifdef ROMVALID_H
#error "header already included"
#else
#define ROMVALID_H
#endif

/*
	A non fatal MacMsg.

	This used to differ from MacMsg by first dismissing a message
	already shown in the overlay, so that the new one replaced it.
	Messages are now presented as alerts, and CheckSavedMacMsg
	releases a message as soon as it takes it for presentation, so
	there is nothing left to dismiss and the two are the same. As
	with MacMsg, a message raised while another is still waiting to
	be presented is dropped. The name is kept for its callers.
*/
LOCALPROC MacMsgOverride(char *briefMsg, char *longMsg)
{
	MacMsg(briefMsg, longMsg, falseblnr);
}

#if dbglog_HAVE
GLOBALOSGLUPROC MacMsgDebugAlert(char *s)
{
	MacMsgOverride("Debug", s);
}
#endif

#ifndef CheckRomCheckSum
#define CheckRomCheckSum 1
#endif

#if CheckRomCheckSum
LOCALFUNC ui5r Calc_Checksum(void)
{
	long int i;
	ui5b CheckSum = 0;
	ui3p p = 4 + ROM;

	for (i = (kCheckSumRom_Size - 4) >> 1; --i >= 0; ) {
		CheckSum += do_get_mem_word(p);
		p += 2;
	}

	return CheckSum;
}
#endif

#if CheckRomCheckSum && RomStartCheckSum
LOCALPROC WarnMsgCorruptedROM(void)
{
	MacMsgOverride(kStrCorruptedROMTitle, kStrCorruptedROMMessage);
}
#endif

#if CheckRomCheckSum
LOCALPROC WarnMsgUnsupportedROM(void)
{
	MacMsgOverride(kStrUnsupportedROMTitle,
		kStrUnsupportedROMMessage);
}
#endif

LOCALFUNC tMacErr ROM_IsValid(void)
{
#if CheckRomCheckSum
	ui5r CheckSum =
#if RomStartCheckSum
		do_get_mem_long(ROM)
#else
		Calc_Checksum()
#endif
		;

#ifdef kRomCheckSum1
	if (CheckSum == kRomCheckSum1) {
	} else
#endif
#ifdef kRomCheckSum2
	if (CheckSum == kRomCheckSum2) {
	} else
#endif
#ifdef kRomCheckSum3
	if (CheckSum == kRomCheckSum3) {
	} else
#endif
	{
		WarnMsgUnsupportedROM();
		return mnvm_miscErr;
	}
	/*
		Even if ROM is corrupt or unsupported, go ahead and
		try to run anyway. It shouldn't do any harm.
		[update: no, don't]
	*/

#if RomStartCheckSum
	{
		ui5r CheckSumActual = Calc_Checksum();

		if (CheckSum != CheckSumActual) {
			WarnMsgCorruptedROM();
			return mnvm_miscErr;
		}
	}
#endif

#endif /* CheckRomCheckSum */

	ROM_loaded = trueblnr;
	SpeedStopped = falseblnr;

	return mnvm_noErr;
}

#if NonDiskProtect
GLOBALOSGLUPROC WarnMsgUnsupportedDisk(void)
{
	MacMsgOverride("Unsupported Disk Image",
		"I do not recognize the format of the Disk Image,"
		" and so will not try to mount it.");
}
#endif

/*
	Called once at startup, after the host is set up and before the
	emulated computer starts. If no ROM image was found, say so and
	wait until the user supplies one, by dropping it onto the window
	or through File > Open Disk Image, either of which loads a ROM
	rather than inserting a disk while none is loaded.

	This used to draw the message into the emulated screen. It is
	now an ordinary MacMsg, which reaches the screen as an alert
	because WaitForNextTick, on the main thread at this point, idles
	through CheckForSavedTasks.
*/
LOCALFUNC blnr WaitForRom(void)
{
	if (! ROM_loaded) {
		MacMsg(kStrNoROMTitle, kStrNoROMMessage, falseblnr);

		SpeedStopped = trueblnr;
		do {
			WaitForNextTick();

			if (ForceMacOff) {
				return falseblnr;
			}
		} while (SpeedStopped);
	}

	return trueblnr;
}
