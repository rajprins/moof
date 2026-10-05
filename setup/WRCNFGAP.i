/*
	WRCNFGAP.i
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
	WRite "CNFGrAPi.h"
*/

LOCALPROC WriteLocalTalkCNFUIOSG(void)
{
	WriteDestFileLn("#include <sys/socket.h>");
	WriteDestFileLn("#include <arpa/inet.h>");
	if ((gbk_lto_bpf == gbo_lto) || CurUseAllFiles) {
		WriteDestFileLn("#include <netinet/in.h>");
		WriteDestFileLn("#include <net/if.h>");
		WriteDestFileLn("#include <net/route.h>");
		WriteDestFileLn("#include <net/if_dl.h>");
		WriteDestFileLn("#include <sys/select.h>");
		WriteDestFileLn("#include <sys/ioctl.h>");
		WriteDestFileLn("#include <sys/sysctl.h>");
		WriteDestFileLn("#include <net/bpf.h>");
	}
	if ((gbk_lto_udp == gbo_lto) || CurUseAllFiles) {
		WriteCompCondBool("use_SO_REUSEPORT", trueblnr);
	}
}

LOCALPROC WriteCommonCNFUIOSGContents(void)
{
	WriteDestFileLn("/*");
	++DestFileIndent;
		WriteDestFileLn(
			"see comment in OSGCOMUI.h");
		WriteConfigurationWarning();
	--DestFileIndent;
	WriteDestFileLn("*/");


	if (gbo_TstCompErr) {
		WriteDestFileLn("#error \"Testing Compile Time Error\"");
	}

	WriteBlankLineToDestFile();

	WriteDestFileLn("#import <Cocoa/Cocoa.h>");
#if MayUseSound
	if (MySoundEnabled || CurUseAllFiles) {
		WriteDestFileLn("#include <CoreAudio/CoreAudio.h>");
		WriteDestFileLn("#include <AudioUnit/AudioUnit.h>");
	}
#endif
#if UseOpenGLinOSX
	WriteDestFileLn("#include <OpenGL/gl.h>");
#endif
#if UseMetalinOSX
	WriteDestFileLn("#import <Metal/Metal.h>");
	WriteDestFileLn("#import <QuartzCore/QuartzCore.h>");
#endif
	WriteDestFileLn("#include <stdio.h>");
	WriteDestFileLn("#include <stdlib.h>");
	WriteDestFileLn("#include <string.h>");
	WriteDestFileLn("#include <sys/param.h>");
	WriteDestFileLn("#include <sys/time.h>");
	if (WantLocalTalk || CurUseAllFiles) {
		WriteDestFileLn("#include <unistd.h>");
		WriteLocalTalkCNFUIOSG();
	}

	/*
		There used to be a block of "#define MyNSEventType... NS..."
		aliases here, emitted when building against an SDK older than
		Xcode 12.1, along with "#define UseAudioComp 0" for CPUs other
		than ARM64. Apple Silicon requires Xcode 12.1 or later (see
		ChooseIdeVers), so neither can apply, and OSGLUCCO.m now uses
		the modern Cocoa names directly.
	*/

	WriteBlankLineToDestFile();

	WriteDestFileLn("#define EnableDragDrop 1");

	WriteDestFileLn("#define MyAppIsBundle 1");
}


LOCALPROC WriteCommonCNFUDOSGContents(void)
{
	WriteDestFileLn("/*");
	++DestFileIndent;
		WriteDestFileLn(
			"see comment in OSGCOMUD.h");
		WriteConfigurationWarning();
	--DestFileIndent;
	WriteDestFileLn("*/");

	WriteBlankLineToDestFile();

	if (WantIconMaster) {
		WriteDestFileLn("#define InstallFileIcons 1");
	}
}
