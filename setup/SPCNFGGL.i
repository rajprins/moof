/*
	SPCNFGGL.i
	Copyright (C) 2007 Paul C. Pratt

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
	program SPecific CoNFiGuration GLobals
*/

LOCALPROC WriteAppSpecificCNFUDALLoptions(void)
{
	WriteBlankLineToDestFile();

	WriteCompCondBool("MySoundRecenterSilence", falseblnr);

	WriteDefineUimr("kLn2SoundSampSz", cur_SoundSampSz);

	WriteBlankLineToDestFile();

	WriteCompCondBool("dbglog_HAVE", DbgLogHAVE);

	WriteCompCondBool("WantAbnormalReports", gbo_AbnormalReports);

	WriteBlankLineToDestFile();

	WriteDefineUimr("NumDrives", cur_numdrives);

	WriteCompCondBool("NonDiskProtect", NonDiskProtect);

	/*
		The Sony disk extensions used to be switched off for the
		backends that could not present a file dialog (gtk, nds, sdl).
		Cocoa can, so they depend only on -min-extn.
	*/
	WriteCompCondBool("IncludeSonyRawMode", ! WantMinExtn);
	WriteCompCondBool("IncludeSonyGetName", ! WantMinExtn);
	WriteCompCondBool("IncludeSonyNew", ! WantMinExtn);
	WriteCompCondBool("IncludeSonyNameNew", ! WantMinExtn);

	WriteBlankLineToDestFile();

	WriteDefineUimr("vMacScreenHeight", cur_vres);
	WriteDefineUimr("vMacScreenWidth", cur_hres);
	WriteDefineUimr("vMacScreenDepth", cur_ScrnDpth);


	WriteBlankLineToDestFile();

	WriteBgnDestFileLn();
	WriteCStrToDestFile("#define kROM_Size ");
	WriteCStrToDestFile("0x");
	WriteHexLongToOutput(1UL << cur_RomSize);
	WriteEndDestFileLn();


	WriteBlankLineToDestFile();

	WriteCompCondBool("IncludePbufs", trueblnr);

	WriteDefineUimr("NumPbufs", 4);


	WriteBlankLineToDestFile();

	WriteCompCondBool("EnableMouseMotion", MyMouseMotion);

	WriteBlankLineToDestFile();

	WriteCompCondBool("IncludeHostTextClipExchange", trueblnr);

	WriteDestFileLn("#define EnableAutoSlow 1");
	WriteCompCondBool("EmLocalTalk", WantLocalTalk);
	if (WantLocalTalk) {
		WriteDestFileLn("#define LT_MayHaveEcho 1");
	}

	WriteCompCondBool("AutoLocation", WantAutoLocation);
	WriteCompCondBool("AutoTimeZone", WantAutoTimeZone);
}
