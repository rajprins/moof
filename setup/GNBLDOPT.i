/*
	GNBLDOPT.i
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
	GeNeric BuiLD OPTions
*/

/* --- default definitions for SPBASDEF --- */

#ifndef MayUseSound
#define MayUseSound 1
#endif

#ifndef UseOpenGLinOSX
#define UseOpenGLinOSX 0
#endif

#ifndef UseMetalinOSX
#define UseMetalinOSX 0
#endif

#ifndef HaveSwiftSrcFiles
#define HaveSwiftSrcFiles 0
#endif

#ifndef kSwiftBridgeHeaderName
#define kSwiftBridgeHeaderName "CCOBRIDG.h"
#endif

#ifndef kSwiftIfaceHeaderName
#define kSwiftIfaceHeaderName "minivmac-Swift.h"
#endif

#ifndef UseMachinOSX
#define UseMachinOSX 0
#endif

#ifndef NeedIntFormatInfo
#define NeedIntFormatInfo 0
#endif

/* --- end of default definitions for SPBASDEF --- */

LOCALVAR blnr OnlyUserOptions = falseblnr;
LOCALVAR blnr DoingDevOpts = falseblnr;

LOCALVAR ui3r olv_cur;

LOCALFUNC tMyErr CurArgIsOption(char *s, ui3r *olv)
{
	tMyErr err;
	MyPStr t;

	if (! CurArgIsCStr_v2(s)) {
		err = kMyErrNoMatch;
	} else
	if (DoingDevOpts && OnlyUserOptions) {
		PStrFromCStr(t, s);
		PStrApndCStr(t, " is a developer only option");
		err = ReportParseFailPStr(t);
	} else
	if (*olv == olv_cur) {
		PStrFromCStr(t, s);
		PStrApndCStr(t, " has appeared more than once");
		err = ReportParseFailPStr(t);
	} else
	if (kMyErr_noErr != (err = AdvanceTheArg())) {
		/* fail */
	} else
	{
		*olv = olv_cur;
		err = kMyErr_noErr;
	}

	return err;
}

typedef char * (* tGetName)(int i);

LOCALFUNC blnr GetCurArgNameIndex(int n, tGetName p,
	int *r)
{
	blnr v;
	int i;

	for (i = 0; i < n; ++i) {
		if (CurArgIsCStr_v2(p(i))) {
			*r = i;
			v = trueblnr;
			goto label_1;
		}
	}
	v = falseblnr;

label_1:
	return v;
}

#define nanblnr 2

#define kListOptionAuto (-1)

LOCALFUNC tMyErr FindNamedOption(char *s, int n, tGetName p,
	int *r, ui3r *olv)
{
	tMyErr err;
	MyPStr t;

	if (kMyErr_noErr != (err = CurArgIsOption(s, olv))) {
		/* no */
	} else
	if (The_arg_end) {
		PStrFromCStr(t, "Expecting an argument for ");
		PStrApndCStr(t, s);
		PStrApndCStr(t, " when reached end");
		err = ReportParseFailPStr(t);
	} else
	if (GetCurArgNameIndex(n, p, r)) {
		err = AdvanceTheArg();
	} else
	if (CurArgIsCStr_v2("*")) {
		*r = kListOptionAuto;
		err = AdvanceTheArg();
	} else
	{
		PStrFromCStr(t, "Unknown value for ");
		PStrApndCStr(t, s);
		err = ReportParseFailPStr(t);
	}

	return err;
}

LOCALFUNC tMyErr BooleanTryAsOptionNot(char *s, blnr *r, ui3r *olv)
{
	tMyErr err;
	MyPStr t;

	if (kMyErr_noErr != (err = CurArgIsOption(s, olv))) {
		/* no */
	} else
	if (The_arg_end) {
		PStrFromCStr(t, "Expecting a boolean argument for ");
		PStrApndCStr(t, s);
		PStrApndCStr(t, " when reached end");
		err = ReportParseFailPStr(t);
	} else
	if (CurArgIsCStr_v2("1")) {
		*r = trueblnr;
		err = AdvanceTheArg();
	} else
	if (CurArgIsCStr_v2("0")) {
		*r = falseblnr;
		err = AdvanceTheArg();
	} else
	if (CurArgIsCStr_v2("*")) {
		*r = nanblnr;
		err = AdvanceTheArg();
	} else
	{
		PStrFromCStr(t, "Expecting a boolean argument for ");
		PStrApndCStr(t, s);
		err = ReportParseFailPStr(t);
	}

	return err;
}

LOCALFUNC tMyErr FlagTryAsOptionNot(char *s, blnr *r, ui3r *olv)
{
	tMyErr err;

	if (kMyErr_noErr != (err = CurArgIsOption(s, olv))) {
		/* no */
	} else
	{
		err = kMyErr_noErr;
		*r = trueblnr;
	}

	return err;
}

LOCALFUNC tMyErr GetCurArgOptionAsNumber(char *s, long *r)
{
	tMyErr err;
	MyPStr t0;
	MyPStr t;

	if (The_arg_end) {
		PStrFromCStr(t, "Expecting a number argument for ");
		PStrApndCStr(t, s);
		PStrApndCStr(t, " when reached end");
		err = ReportParseFailPStr(t);
	} else {
		GetCurArgAsPStr(t0);
		*r = PStrToSimr(t0);
		/* StringToNum(t0, r); */
		PStrFromSimr(*r, t);
		/* NumToString(*r, t); */
		if (! PStrEq(t0, t)) {
			PStrFromCStr(t, "Expecting a number argument for ");
			PStrApndCStr(t, s);
			PStrApndCStr(t, " but got ");
			PStrAppend(t, t0);
			err = ReportParseFailPStr(t);
		} else
		{
			err = AdvanceTheArg();
		}
	}

	return err;
}

LOCALFUNC tMyErr NumberTryAsOptionNot(char *s, long *r, ui3r *olv)
{
	tMyErr err;

	if (kMyErr_noErr != (err = CurArgIsOption(s, olv))) {
		/* no */
	} else
	if (kMyErr_noErr != (err = GetCurArgOptionAsNumber(s, r))) {
		/* fail */
	} else
	{
		err = kMyErr_noErr;
	}

	return err;
}

LOCALPROC WrtOptNamedOption(char *s, tGetName p, int i, int i0)
{
	if (i != i0) {
		WriteCStrToDestFile(" ");
		WriteCStrToDestFile(s);
		WriteCStrToDestFile(" ");
		WriteCStrToDestFile(p(i));
	}
}

LOCALPROC WrtOptNumberOption(char *s, int i, int i0)
{
	if (i != i0) {
		WriteCStrToDestFile(" ");
		WriteCStrToDestFile(s);
		WriteCStrToDestFile(" ");
		WriteUnsignedToOutput(i);
	}
}

LOCALPROC WrtOptSimrOption(char *s, simr i, simr i0)
{
	if (i != i0) {
		WriteCStrToDestFile(" ");
		WriteCStrToDestFile(s);
		WriteCStrToDestFile(" ");
		WriteSignedLongToOutput(i);
	}
}

LOCALPROC WrtOptBooleanOption(char *s, blnr i, blnr i0)
{
	if (i != i0) {
		WriteCStrToDestFile(" ");
		WriteCStrToDestFile(s);
		WriteCStrToDestFile(" ");
		WriteCStrToDestFile(i ? "1" : "0");
	}
}

LOCALPROC WrtOptFlagOption(char *s, blnr v)
{
	if (v) {
		WriteCStrToDestFile(" ");
		WriteCStrToDestFile(s);
	}
}


/* option: Branch */

LOCALVAR uimr Branch;
LOCALVAR ui3r olv_Branch;

LOCALPROC ResetBranchOption(void)
{
	olv_Branch = 0;
}

LOCALFUNC tMyErr TryAsBranchOptionNot(void)
{
	return NumberTryAsOptionNot("-br",
		(long *)&Branch, &olv_Branch);
}

LOCALFUNC tMyErr ChooseBranch(void)
{
	if (0 == olv_Branch) {
		Branch = MajorVersion;
	}

	return kMyErr_noErr;
}

LOCALPROC WrtOptBranchOption(void)
{
	WriteCStrToDestFile("-br");
	WriteCStrToDestFile(" ");
	WriteUnsignedToOutput(MajorVersion);
}


/* option: official binary */

/* do not use unless you are {kMaintainerName} */

LOCALVAR blnr CurOfficialBin;
LOCALVAR ui3r olv_OfficialBin;

LOCALPROC ResetOfficialBin(void)
{
	CurOfficialBin = falseblnr;
	olv_OfficialBin = 0;
}

LOCALFUNC tMyErr TryAsOfficialBinNot(void)
{
	return FlagTryAsOptionNot("-ob", &CurOfficialBin, &olv_OfficialBin);
}

LOCALFUNC tMyErr ChooseOfficialBin(void)
{
	return kMyErr_noErr;
}

LOCALPROC WrtOptOfficialBin(void)
{
	WrtOptFlagOption("-ob", CurOfficialBin);
}


/* option: target */

/*
	This program builds for exactly one host: 64 bit macOS on Apple
	Silicon, which this build system has always called "mcar". The
	option is still parsed, because the build scripts pass it and
	because naming the target documents what is being built.
*/

#define kTargetName "mcar"

LOCALVAR ui3r olv_targ;

LOCALPROC ResetTargetOption(void)
{
	olv_targ = 0;
}

LOCALFUNC tMyErr TryAsTargetOptionNot(void)
{
	tMyErr err;

	if (kMyErr_noErr != (err = CurArgIsOption("-t", &olv_targ))) {
		/* no */
	} else
	if (The_arg_end) {
		err = ReportParseFailure(
			"Expecting an argument for -t when reached end");
	} else
	if (! CurArgIsCStr_v2(kTargetName)) {
		err = ReportParseFailure("only '-t " kTargetName
			"' (Apple Silicon macOS) is supported");
	} else
	{
		err = AdvanceTheArg();
	}

	return err;
}

LOCALFUNC tMyErr ChooseTarg(void)
{
	tMyErr err;

	if (0 == olv_targ) {
		err = ReportParseFailure("target not specified ('-t "
			kTargetName "')");
	} else {
		err = kMyErr_noErr;
	}

	return err;
}

LOCALPROC WrtOptTarg(void)
{
	WriteCStrToDestFile(" ");
	WriteCStrToDestFile("-t");
	WriteCStrToDestFile(" ");
	WriteCStrToDestFile(kTargetName);
}


/* option: debug level */

enum {
	gbk_dbg_off,
	gbk_dbg_test,
	gbk_dbg_on,
	kNumDebugLevels
};

LOCALVAR int gbo_dbg;
LOCALVAR ui3r olv_dbg;

LOCALPROC ResetDbgOption(void)
{
	gbo_dbg = kListOptionAuto;
	olv_dbg = 0;
}

LOCALFUNC char * GetDbgLvlName(int i)
{
	char *s;

	switch (i) {
		case gbk_dbg_on:
			s = "d";
			break;
		case gbk_dbg_test:
			s = "t";
			break;
		case gbk_dbg_off:
			s = "s";
			break;
		default:
			s = "(unknown Debug Level)";
			break;
	}
	return s;
}

LOCALFUNC tMyErr TryAsDbgOptionNot(void)
{
	return FindNamedOption("-d",
		kNumDebugLevels, GetDbgLvlName, &gbo_dbg, &olv_dbg);
}

#define dfo_dbg() gbk_dbg_off

LOCALFUNC tMyErr ChooseDbgOption(void)
{
	if (kListOptionAuto == gbo_dbg) {
		gbo_dbg = dfo_dbg();
	}

	return kMyErr_noErr;
}

LOCALPROC WrtOptDbgOption(void)
{
	WrtOptNamedOption("-d", GetDbgLvlName, gbo_dbg, dfo_dbg());
}


/* option: language */

enum {
	gbk_lang_eng,
	gbk_lang_fre,
	gbk_lang_ita,
	gbk_lang_ger,
	gbk_lang_dut,
	gbk_lang_spa,
	gbk_lang_pol,
	gbk_lang_ptb,
	gbk_lang_cat,
	gbk_lang_cze,
	gbk_lang_srl,
	kNumLangLevels
};

LOCALVAR int gbo_lang;
LOCALVAR ui3r olv_lang;

LOCALPROC ResetLangOption(void)
{
	gbo_lang = kListOptionAuto;
	olv_lang = 0;
}

LOCALFUNC char * GetLangName(int i)
{
	/* ISO 639-2/B */
	char *s;

	switch (i) {
		case gbk_lang_eng:
			s = "eng";
			break;
		case gbk_lang_fre:
			s = "fre";
			break;
		case gbk_lang_ita:
			s = "ita";
			break;
		case gbk_lang_ger:
			s = "ger";
			break;
		case gbk_lang_dut:
			s = "dut";
			break;
		case gbk_lang_spa:
			s = "spa";
			break;
		case gbk_lang_pol:
			s = "pol";
			break;
		case gbk_lang_ptb:
			s = "ptb";
			break;
		case gbk_lang_cat:
			s = "cat";
			break;
		case gbk_lang_cze:
			s = "cze";
			break;
		case gbk_lang_srl:
			s = "srl";
			break;
		default:
			s = "(unknown Language Level)";
			break;
	}
	return s;
}

LOCALFUNC tMyErr TryAsLangOptionNot(void)
{
	return FindNamedOption("-lang",
		kNumLangLevels, GetLangName, &gbo_lang, &olv_lang);
}

LOCALFUNC char * GetLProjName(int i)
{
	/*
		As used in OS X, IETF language tags, except when not
	*/
	char *s;

	switch (i) {
		case gbk_lang_eng:
			s = "English";
			break;
		case gbk_lang_fre:
			s = "French";
			break;
		case gbk_lang_ita:
			s = "Italian";
			break;
		case gbk_lang_ger:
			s = "German";
			break;
		case gbk_lang_dut:
			s = "Dutch";
			break;
		case gbk_lang_spa:
			s = "Spanish";
			break;
		case gbk_lang_pol:
			s = "pl";
			break;
		case gbk_lang_ptb:
			s = "pt_BR";
			break;
		case gbk_lang_cat:
			s = "ca";
			break;
		case gbk_lang_cze:
			s = "cs";
			break;
		case gbk_lang_srl:
			s = "sr";
			break;
		default:
			s = "(unknown Language Level)";
			break;
	}
	return s;
}

#define dfo_lang() gbk_lang_eng

LOCALFUNC tMyErr ChooseLangOption(void)
{
	if (kListOptionAuto == gbo_lang) {
		gbo_lang = dfo_lang();
	}

	return kMyErr_noErr;
}

LOCALPROC WrtOptLangOption(void)
{
	WrtOptNamedOption("-lang", GetLangName, gbo_lang, dfo_lang());
}


/* option: IconMaster */

#ifndef WantIconMasterDflt
#define WantIconMasterDflt falseblnr
#endif

LOCALVAR blnr WantIconMaster;
LOCALVAR ui3r olv_IconMaster;

LOCALPROC ResetIconMaster(void)
{
	WantIconMaster = nanblnr;
	olv_IconMaster = 0;
}

LOCALFUNC tMyErr TryAsIconMasterNot(void)
{
	return BooleanTryAsOptionNot("-im",
		&WantIconMaster, &olv_IconMaster);
}

LOCALFUNC tMyErr ChooseIconMaster(void)
{
	if (nanblnr == WantIconMaster) {
		WantIconMaster = WantIconMasterDflt;
	}

	return kMyErr_noErr;
}

LOCALPROC WrtOptIconMaster(void)
{
	WrtOptBooleanOption("-im", WantIconMaster, WantIconMasterDflt);
}


/* option: Test Compile Time Error */

LOCALVAR blnr gbo_TstCompErr;
LOCALVAR ui3r olv_TstCompErr;

LOCALPROC ResetTstCompErr(void)
{
	gbo_TstCompErr = nanblnr;
	olv_TstCompErr = 0;
}

LOCALFUNC tMyErr TryAsTstCompErrNot(void)
{
	return BooleanTryAsOptionNot("-cte",
		&gbo_TstCompErr, &olv_TstCompErr);
}

#define dfo_TstCompErr() falseblnr

LOCALFUNC tMyErr ChooseTstCompErr(void)
{
	if (nanblnr == gbo_TstCompErr) {
		gbo_TstCompErr = dfo_TstCompErr();
	}

	return kMyErr_noErr;
}

LOCALPROC WrtOptTstCompErr(void)
{
	WrtOptBooleanOption("-cte", gbo_TstCompErr, dfo_TstCompErr());
}


/* option: Test Build System Error */

LOCALFUNC tMyErr TryAsTstBldSysErr(void)
{
	tMyErr err;

	if (! CurArgIsCStr_v2("-bte")) {
		err = kMyErrNoMatch;
	} else {
		err = ReportParseFailure("Testing Build System Error");
	}

	return err;
}


/*
	The host CPU family and target family used to be separate axes
	derived from the target. With only "mcar" left there is nothing to
	derive: the CPU is always ARM64 and the target family is always
	Mach-O. The "-cpu" option is gone.
*/


/* option: ide */

/*
	Only Apple Xcode ("xcd") is supported. As with "-t", the option is
	still parsed because the build scripts pass it.
*/

#define kIdeName "xcd"

LOCALVAR ui3r olv_ide;

LOCALPROC ResetIdeOption(void)
{
	olv_ide = 0;
}

LOCALFUNC tMyErr TryAsIdeOptionNot(void)
{
	tMyErr err;

	if (kMyErr_noErr != (err = CurArgIsOption("-e", &olv_ide))) {
		/* no */
	} else
	if (The_arg_end) {
		err = ReportParseFailure(
			"Expecting an argument for -e when reached end");
	} else
	if (! CurArgIsCStr_v2(kIdeName)) {
		err = ReportParseFailure("only '-e " kIdeName
			"' (Apple Xcode) is supported");
	} else
	{
		err = AdvanceTheArg();
	}

	return err;
}

LOCALFUNC tMyErr ChooseIde(void)
{
	return kMyErr_noErr;
}


/* option: ide version */

LOCALVAR uimr ide_vers;
LOCALVAR ui3r olv_ide_vers;

LOCALPROC ResetIdeVersOption(void)
{
	olv_ide_vers = 0;
}

LOCALFUNC tMyErr TryAsIdeVersOptionNot(void)
{
	return NumberTryAsOptionNot("-ev",
		(long *)&ide_vers, &olv_ide_vers);
}

LOCALFUNC uimr dfo_ide_vers(void)
{
	return 12300; /* Xcode 12.3, the first with Apple Silicon support */
}

LOCALFUNC tMyErr ChooseIdeVers(void)
{
	if (0 == olv_ide_vers) {
		ide_vers = dfo_ide_vers();
	}

	if (ide_vers < 12100) {
		/*
			Apple Silicon support arrived in Xcode 12.1, so nothing
			older can build this. Enforcing the floor is what lets
			the generator and OSGLUCCO.m both assume a modern SDK.
		*/
		return ReportParseFailure(
			"-ev must be at least 12100 (Xcode 12.1),"
			" the first with Apple Silicon support");
	}

	return kMyErr_noErr;
}

LOCALPROC WrtOptIdeVers(void)
{
	WrtOptNumberOption("-ev", ide_vers, dfo_ide_vers());
}


/* option: api family */

/*
	Only the Cocoa backend ("cco", src/OSGLUCCO.m) remains. As with
	"-t" and "-e", the option is still parsed because the build
	scripts pass it.
*/

#define kAPIFamName "cco"

LOCALVAR ui3r olv_apifam;

LOCALPROC ResetAPIFamOption(void)
{
	olv_apifam = 0;
}

LOCALFUNC tMyErr TryAsAPIFamOptionNot(void)
{
	tMyErr err;

	if (kMyErr_noErr != (err = CurArgIsOption("-api", &olv_apifam))) {
		/* no */
	} else
	if (The_arg_end) {
		err = ReportParseFailure(
			"Expecting an argument for -api when reached end");
	} else
	if (! CurArgIsCStr_v2(kAPIFamName)) {
		err = ReportParseFailure("only '-api " kAPIFamName
			"' (Cocoa) is supported");
	} else
	{
		err = AdvanceTheArg();
	}

	return err;
}

LOCALFUNC tMyErr ChooseAPIFam(void)
{
	return kMyErr_noErr;
}


/* option: print file list */

LOCALVAR blnr CurPrintCFiles;
LOCALVAR ui3r olv_PrintCFiles;

LOCALPROC ResetListOption(void)
{
	CurPrintCFiles = falseblnr;
	olv_PrintCFiles = 0;
}

LOCALFUNC tMyErr TryAsListOptionNot(void)
{
	return FlagTryAsOptionNot("-l", &CurPrintCFiles, &olv_PrintCFiles);
}

LOCALFUNC tMyErr ChooseListOption(void)
{
	return kMyErr_noErr;
}

LOCALPROC WrtOptListOption(void)
{
	WrtOptFlagOption("-l", CurPrintCFiles);
}


/* option: include all files */

LOCALVAR blnr CurUseAllFiles;
LOCALVAR ui3r olv_UseAllFiles;

LOCALPROC ResetUseAllFiles(void)
{
	CurUseAllFiles = falseblnr;
	olv_UseAllFiles = 0;
}

LOCALFUNC tMyErr TryAsUseAllFilesNot(void)
{
	return FlagTryAsOptionNot("-af", &CurUseAllFiles, &olv_UseAllFiles);
}

LOCALFUNC tMyErr ChooseUseAllFilesNot(void)
{
	return kMyErr_noErr;
}

LOCALPROC WrtOptUseAllFiles(void)
{
	WrtOptFlagOption("-af", CurUseAllFiles);
}


/* option: print variation name */

LOCALVAR blnr CurPrintVarName;
LOCALVAR ui3r olv_PrintVarName;

LOCALPROC ResetPrintVarName(void)
{
	CurPrintVarName = nanblnr;
	olv_PrintVarName = 0;
}

LOCALFUNC tMyErr TryAsPrintVarNameNot(void)
{
	return BooleanTryAsOptionNot("-pvn",
		&CurPrintVarName, &olv_PrintVarName);
}

LOCALFUNC blnr dfo_PrintVarName(void)
{
	blnr v;

	v = CurOfficialBin;

	return v;
}

LOCALFUNC tMyErr ChoosePrintVarName(void)
{
	if (nanblnr == CurPrintVarName) {
		CurPrintVarName = dfo_PrintVarName();
	}

	return kMyErr_noErr;
}

LOCALPROC WrtOptPrintVarName(void)
{
	WrtOptBooleanOption("-pvn", CurPrintVarName, dfo_PrintVarName());
}


/* option: print variation options */

LOCALVAR blnr CurPrintVarOpts;
LOCALVAR ui3r olv_PrintVarOpts;

LOCALPROC ResetPrintVarOpts(void)
{
	CurPrintVarOpts = nanblnr;
	olv_PrintVarOpts = 0;
}

LOCALFUNC tMyErr TryAsPrintVarOptsNot(void)
{
	return BooleanTryAsOptionNot("-pvo",
		&CurPrintVarOpts, &olv_PrintVarOpts);
}

LOCALFUNC blnr dfo_PrintVarOpts(void)
{
	blnr v;

	v = CurOfficialBin;

	return v;
}

LOCALFUNC tMyErr ChoosePrintVarOpts(void)
{
	if (nanblnr == CurPrintVarOpts) {
		CurPrintVarOpts = dfo_PrintVarOpts();
	}

	return kMyErr_noErr;
}

LOCALPROC WrtOptPrintVarOpts(void)
{
	WrtOptBooleanOption("-pvo", CurPrintVarOpts, dfo_PrintVarOpts());
}


/* option: maintainer name */

LOCALVAR char *vMaintainerName;
LOCALVAR ui3r olv_MaintainerName;

LOCALPROC ResetMaintainerName(void)
{
	vMaintainerName = nullpr;
	olv_MaintainerName = 0;
}

LOCALFUNC tMyErr TryAsMaintainerNameOptionNot(void)
{
	tMyErr err;
	MyPStr t;

	if (kMyErr_noErr != (err =
		CurArgIsOption("-maintainer", &olv_MaintainerName)))
	{
		/* no */
	} else
	if (The_arg_end) {
		PStrFromCStr(t, "Expecting maintainer argument for ");
		PStrApndCStr(t, "-maintainer");
		PStrApndCStr(t, " when reached end");
		err = ReportParseFailPStr(t);
	} else
	{
		vMaintainerName = Cur_args;
		err = AdvanceTheArg();
	}

	return err;
}

LOCALFUNC tMyErr ChooseMaintainerName(void)
{
	if (nullpr == vMaintainerName) {
		if (CurOfficialBin) {
			vMaintainerName = kMaintainerName;
		} else {
			vMaintainerName = "unknown";
		}
	}

	return kMyErr_noErr;
}


/* option: home page */

LOCALVAR char *vHomePage;
LOCALVAR ui3r olv_HomePage;

LOCALPROC ResetHomePage(void)
{
	vHomePage = nullpr;
	olv_HomePage = 0;
}

LOCALFUNC tMyErr TryAsHomePageOptionNot(void)
{
	tMyErr err;
	MyPStr t;

	if (kMyErr_noErr != (err =
		CurArgIsOption("-homepage", &olv_HomePage)))
	{
		/* no */
	} else
	if (The_arg_end) {
		PStrFromCStr(t, "Expecting homepage argument for ");
		PStrApndCStr(t, "-homepage");
		PStrApndCStr(t, " when reached end");
		err = ReportParseFailPStr(t);
	} else
	{
		vHomePage = Cur_args;
		err = AdvanceTheArg();
	}

	return err;
}

LOCALFUNC tMyErr ChooseHomePage(void)
{
	if (nullpr == vHomePage) {
		if (CurOfficialBin) {
			vHomePage = kStrHomePage;
		} else {
			vHomePage = "(unknown)";
		}
	}

	return kMyErr_noErr;
}


/*
	The application is always a Mach-O bundle (.app folder), and never
	has classic Macintosh resource-fork resources, so what used to be
	the derived HaveMacBundleApp and HaveMacRrscs flags are now
	constants. WantUnTranslocate was already hard-wired off, because
	it needed undocumented calls.
*/


/* option: Abbrev Name */

LOCALVAR char *vStrAppAbbrev;
LOCALVAR ui3r olv_AbbrevName;

LOCALPROC ResetAbbrevName(void)
{
	vStrAppAbbrev = nullpr;
	olv_AbbrevName = 0;
}

LOCALFUNC tMyErr TryAsAbbrevNameOptionNot(void)
{
	tMyErr err;
	MyPStr t;

	if (kMyErr_noErr != (err =
		CurArgIsOption("-an", &olv_AbbrevName)))
	{
		/* no */
	} else
	if (The_arg_end) {
		PStrFromCStr(t, "Expecting an argument for ");
		PStrApndCStr(t, "-an");
		PStrApndCStr(t, " when reached end");
		err = ReportParseFailPStr(t);
	} else
	{
		if (CStrLength(Cur_args) > 8) {
			err = ReportParseFailure("-an argument too long");
		} else {
			vStrAppAbbrev = Cur_args;
			err = AdvanceTheArg();
		}
	}

	return err;
}

LOCALFUNC tMyErr ChooseAbbrevName(void)
{
	if (nullpr == vStrAppAbbrev) {
		vStrAppAbbrev = kStrAppAbbrev;
	}

	return kMyErr_noErr;
}


/* option: Variation Name */

LOCALVAR char *vVariationName;
LOCALVAR ui3r olv_VariationName;

LOCALPROC ResetVariationName(void)
{
	vVariationName = nullpr;
	olv_VariationName = 0;
}

LOCALFUNC tMyErr TryAsVariationNameOptionNot(void)
{
	tMyErr err;
	MyPStr t;

	if (kMyErr_noErr != (err =
		CurArgIsOption("-n", &olv_VariationName)))
	{
		/* no */
	} else
	if (The_arg_end) {
		PStrFromCStr(t, "Expecting an argument for ");
		PStrApndCStr(t, "-n");
		PStrApndCStr(t, " when reached end");
		err = ReportParseFailPStr(t);
	} else
	{
		if (CStrLength(Cur_args) > 64) {
			err = ReportParseFailure("-n argument too long");
		} else {
			vVariationName = Cur_args;
			err = AdvanceTheArg();
		}
	}

	return err;
}

LOCALFUNC tMyErr ChooseVariationName(void)
{
#if 0
	if (nullpr == vVariationName) {
	}
#endif

	return kMyErr_noErr;
}


/* option: Need International Characters */

LOCALVAR blnr NeedIntl;
LOCALVAR ui3r olv_NeedIntl;

LOCALPROC ResetNeedIntl(void)
{
	NeedIntl = falseblnr;
	olv_NeedIntl = 0;
}

LOCALFUNC tMyErr TryAsNeedIntlNot(void)
{
	return FlagTryAsOptionNot("-intl", &NeedIntl, &olv_NeedIntl);
}

LOCALFUNC tMyErr ChooseNeedIntl(void)
{
	return kMyErr_noErr;
}


/*
	The "-dmo" demonstration message and "-act" activation code
	options were upstream licensing features, drawn into the Control
	Mode overlay, so they are gone along with it.
*/


/* --- end of default definition of options --- */

LOCALPROC GNResetCommandLineParameters(void)
{
	ResetBranchOption();
	ResetTargetOption();
	ResetDbgOption();
	ResetLangOption();
	ResetIconMaster();
	ResetTstCompErr();
}

LOCALFUNC tMyErr TryAsGNOptionNot(void)
{
	tMyErr err;

	if (kMyErrNoMatch == (err = TryAsBranchOptionNot()))
	if (kMyErrNoMatch == (err = TryAsTargetOptionNot()))
	if (kMyErrNoMatch == (err = TryAsDbgOptionNot()))
	if (kMyErrNoMatch == (err = TryAsLangOptionNot()))
	if (kMyErrNoMatch == (err = TryAsIconMasterNot()))
	if (kMyErrNoMatch == (err = TryAsTstCompErrNot()))
	if (kMyErrNoMatch == (err = TryAsTstBldSysErr()))
	{
	}

	return err;
}

LOCALFUNC tMyErr AutoChooseGNSettings(void)
{
	tMyErr err;

	if (kMyErr_noErr == (err = ChooseBranch()))
	if (kMyErr_noErr == (err = ChooseTarg()))
	if (kMyErr_noErr == (err = ChooseDbgOption()))
	if (kMyErr_noErr == (err = ChooseLangOption()))
	if (kMyErr_noErr == (err = ChooseIconMaster()))
	if (kMyErr_noErr == (err = ChooseTstCompErr()))
	{
		err = kMyErr_noErr;
	}

	return err;
}

LOCALPROC WrtOptGNSettings(void)
{
	WrtOptBranchOption();
	WrtOptTarg();
	WrtOptDbgOption();
	WrtOptLangOption();
	WrtOptIconMaster();
	WrtOptTstCompErr();
}

LOCALPROC GNDevResetCommandLineParameters(void)
{
	ResetOfficialBin();
	ResetIdeOption();
	ResetIdeVersOption();
	ResetAPIFamOption();
	ResetListOption();
	ResetUseAllFiles();
	ResetPrintVarName();
	ResetPrintVarOpts();
	ResetMaintainerName();
	ResetHomePage();
	ResetAbbrevName();
	ResetVariationName();
	ResetNeedIntl();
}

LOCALFUNC tMyErr TryAsGNDevOptionNot(void)
{
	tMyErr err;

	DoingDevOpts = trueblnr;

	if (kMyErrNoMatch == (err = TryAsOfficialBinNot()))
	if (kMyErrNoMatch == (err = TryAsIdeOptionNot()))
	if (kMyErrNoMatch == (err = TryAsIdeVersOptionNot()))
	if (kMyErrNoMatch == (err = TryAsAPIFamOptionNot()))
	if (kMyErrNoMatch == (err = TryAsListOptionNot()))
	if (kMyErrNoMatch == (err = TryAsUseAllFilesNot()))
	if (kMyErrNoMatch == (err = TryAsPrintVarNameNot()))
	if (kMyErrNoMatch == (err = TryAsPrintVarOptsNot()))
	if (kMyErrNoMatch == (err = TryAsMaintainerNameOptionNot()))
	if (kMyErrNoMatch == (err = TryAsHomePageOptionNot()))
	if (kMyErrNoMatch == (err = TryAsAbbrevNameOptionNot()))
	if (kMyErrNoMatch == (err = TryAsVariationNameOptionNot()))
	if (kMyErrNoMatch == (err = TryAsNeedIntlNot()))
	{
	}

	DoingDevOpts = falseblnr;

	return err;
}

LOCALFUNC tMyErr AutoChooseGNDevSettings(void)
{
	tMyErr err;

	if (kMyErr_noErr == (err = ChooseOfficialBin()))
	if (kMyErr_noErr == (err = ChooseIde()))
	if (kMyErr_noErr == (err = ChooseIdeVers()))
	if (kMyErr_noErr == (err = ChooseAPIFam()))
	if (kMyErr_noErr == (err = ChooseListOption()))
	if (kMyErr_noErr == (err = ChooseUseAllFilesNot()))
	if (kMyErr_noErr == (err = ChoosePrintVarName()))
	if (kMyErr_noErr == (err = ChoosePrintVarOpts()))
	if (kMyErr_noErr == (err = ChooseMaintainerName()))
	if (kMyErr_noErr == (err = ChooseHomePage()))
	if (kMyErr_noErr == (err = ChooseAbbrevName()))
	if (kMyErr_noErr == (err = ChooseVariationName()))
	if (kMyErr_noErr == (err = ChooseNeedIntl()))
	{
		err = kMyErr_noErr;
	}

	return err;
}

#if 0
LOCALPROC WrtOptGNDevSettings(void)
{
	WrtOptOfficialBin();
	WrtOptIdeVers();
	WrtOptListOption();
	WrtOptUseAllFiles();
	WrtOptPrintVarName();
	WrtOptPrintVarOpts();
	/* Maintainer */
	/* HomePage */
	/* Sponsor */
	/* VariationName */
	/* AbbrevName */
	/* ConfigDir */
	/* Err2File */
}
#endif
