/*
	WRXCDFLS.i
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
	WRite XCoDe specific FiLeS

	Only Xcode 12.1 and later is supported (see ChooseIdeVers in
	GNBLDOPT.i), so the project is always written in the modern
	xcodeproj format with build configurations.
*/

static void WriteAPBXCDObjectId(unsigned int theClass, unsigned int v)
{
	WriteHexWordToOutput(theClass);
	WriteHexWordToOutput(v);
	WriteCStrToDestFile("0000000000000000");
}

enum {
	APBoclsSrcBld,
	APBoclsIcnsBld,
	APBoclsFramBld,
	APBospcLibStdcBld, /* unused; kept so later object ids don't shift */
	APBospcMnRsrcBld, /* unused; kept so later object ids don't shift */
	APBospcLangDummyBld,

	APBospcBuildStyle, /* unused; kept so later object ids don't shift */

	APBoclsSrcRf,
	APBoclsHdr,
	APBoclsInc,
	APBoclsIcnsRf,
	APBoclsFramRf,
	APBospcLibStdcRf, /* unused; kept so later object ids don't shift */
	APBospcProductRef,
	APBospcPlistRf,
	APBospcMainRsrcRf, /* unused; kept so later object ids don't shift */
	APBospcLangRf,

	APBospcPhaseLibs,
	APBospcSources,
	APBospcResources,
	APBospcLibraries,
	APBospcProducts,
	APBospcMainGroup,
	APBospcSrcHeaders,
	APBospcIncludes,

	APBospcTarget,
	APBospcRoot,
	APBospcBunRsrcs,
	APBospcPhaseRsrc, /* unused; kept so later object ids don't shift */
	APBospcHeaders, /* unused; kept so later object ids don't shift */
	APBospcPhaseSrcs,

	APBospcLangDummyRf,

	APBospcNatCnfg,
	APBospcPrjCnfg,
	APBospcLstNatCnfg,
	APBospcLstPrjCnfg,

	kNumAPBocls
};

static void WriteAPBXCDBgnObjList(char *s)
{
	WriteBgnDestFileLn();
	WriteCStrToDestFile(s);
	WriteCStrToDestFile(" = (");
	WriteEndDestFileLn();
	++DestFileIndent;
}

static void WriteAPBXCDEndObjList(void)
{
	--DestFileIndent;
	WriteDestFileLn(");");
}

LOCALPROC WriteAPBXCDObjectIdAndComment(unsigned int theClass,
	unsigned int v, MyProc comment)
{
	WriteAPBXCDObjectId(theClass, v);
	WriteCStrToDestFile(" /* ");
	comment();
	WriteCStrToDestFile(" */");
}

static void WriteAPBXCDBeginObject(unsigned int theClass,
	unsigned int v, MyProc comment)
{
	WriteBgnDestFileLn();
	WriteAPBXCDObjectIdAndComment(theClass, v, comment);
	WriteCStrToDestFile(" = {");
	WriteEndDestFileLn();
	++DestFileIndent;
}

static void WriteAPBXCDEndObject(void)
{
	--DestFileIndent;
	WriteDestFileLn("};");
}

LOCALPROC WriteAPBXCDobjlistelmp(unsigned int theClass, unsigned int v,
	MyProc comment)
{
	WriteBgnDestFileLn();
	WriteAPBXCDObjectIdAndComment(theClass, v, comment);
	WriteCStrToDestFile(",");
	WriteEndDestFileLn();
}

LOCALVAR int APBXCDForceSameLine = 0;

LOCALPROC WriteAPBXCDDObjectAPropBgn(void)
{
	if (0 == APBXCDForceSameLine) {
		WriteBgnDestFileLn();
	}
}

LOCALPROC WriteAPBXCDDObjectAPropEnd(void)
{
	WriteCStrToDestFile(";");
	if (0 == APBXCDForceSameLine) {
		WriteEndDestFileLn();
	} else {
		WriteSpaceToDestFile();
	}
}

LOCALPROC WriteAPBXCDObjectAp(unsigned int theClass, unsigned int v,
	MyProc comment, MyProc body)
{
	WriteBgnDestFileLn();
	WriteAPBXCDObjectIdAndComment(theClass, v, comment);
	WriteCStrToDestFile(" = {");
	++APBXCDForceSameLine;
	body();
	--APBXCDForceSameLine;
	WriteCStrToDestFile("};");
	WriteEndDestFileLn();
}

LOCALPROC WriteAPBXCDDObjAProp_SS(char *ns, char *vs)
{
	WriteAPBXCDDObjectAPropBgn();
	WriteCStrToDestFile(ns);
	WriteCStrToDestFile(" = ");
	WriteCStrToDestFile(vs);
	WriteAPBXCDDObjectAPropEnd();
}

LOCALPROC WriteAPBXCDDObjAProp_SP(char *ns, MyProc p)
{
	WriteAPBXCDDObjectAPropBgn();
	WriteCStrToDestFile(ns);
	WriteCStrToDestFile(" = ");
	p();
	WriteAPBXCDDObjectAPropEnd();
}

LOCALPROC WriteAPBXCDDObjAProp_SO(char *ns,
	unsigned int theClass, unsigned int v,
	MyProc comment)
{
	WriteAPBXCDDObjectAPropBgn();
	WriteCStrToDestFile(ns);
	WriteCStrToDestFile(" = ");
	WriteAPBXCDObjectIdAndComment(theClass,
		v, comment);
	WriteAPBXCDDObjectAPropEnd();
}

LOCALPROC WriteAPBXCDDObjAPropIsa(char *s)
{
	WriteAPBXCDDObjAProp_SS("isa", s);
}

LOCALPROC WriteAPBXCDDObjAPropIsaBuildFile(void)
{
	WriteAPBXCDDObjAPropIsa("PBXBuildFile");
}

LOCALPROC WriteAPBXCDDObjAPropIsaFileReference(void)
{
	WriteAPBXCDDObjAPropIsa("PBXFileReference");
}

LOCALPROC WriteAPBXCDDObjAPropIsaGroup(void)
{
	WriteAPBXCDDObjAPropIsa("PBXGroup");
}

LOCALPROC WriteAPBXCDDObjAPropFileEncoding30(void)
{
	WriteAPBXCDDObjAProp_SS("fileEncoding", "30");
}

LOCALPROC WriteAPBXCDDObjAPropFileEncoding4(void)
{
	WriteAPBXCDDObjAProp_SS("fileEncoding", "4");
}

LOCALPROC WriteAPBXCDDObjAPropName(MyProc p)
{
	WriteAPBXCDDObjAProp_SP("name", p);
}

LOCALPROC WriteAPBXCDDObjAPropPath(MyProc p)
{
	WriteAPBXCDDObjAProp_SP("path", p);
}

LOCALPROC WriteAPBXCDDObjAPropSourceTree(char *s)
{
	WriteAPBXCDDObjAProp_SS("sourceTree", s);
}

LOCALPROC WriteAPBXCDDObjAPropSourceTreeRoot(void)
{
	WriteAPBXCDDObjAPropSourceTree("SOURCE_ROOT");
}

LOCALPROC WriteAPBXCDDObjAPropSourceTreeSDKRoot(void)
{
	WriteAPBXCDDObjAPropSourceTree("SDKROOT");
}

LOCALPROC WriteAPBXCDDObjAPropSourceTreeGroup(void)
{
	WriteAPBXCDDObjAPropSourceTree("\"<group>\"");
}

LOCALPROC WriteAPBXCDDObjAPropLastKnownFType(MyProc p)
{
	WriteAPBXCDDObjAProp_SP("lastKnownFileType", p);
}

LOCALPROC WriteAPBXCDDObjAPropFileRef(
	unsigned int theClass, unsigned int v,
	MyProc comment)
{
	WriteAPBXCDDObjAProp_SO("fileRef",
		theClass, v, comment);
}

LOCALPROC WriteAPBXCDDObjAPropIncludeII0(void)
{
	WriteAPBXCDDObjAProp_SS("includeInIndex", "0");
}

LOCALPROC WriteSrcFileAPBXCDNameInSources(void)
{
	WriteSrcFileFileName();
	WriteCStrToDestFile(" in Sources");
}

LOCALPROC DoSrcFileAPBXCDaddFileBody(void)
{
	WriteAPBXCDDObjAPropIsaBuildFile();
	WriteAPBXCDDObjAPropFileRef(APBoclsSrcRf,
		FileCounter, WriteSrcFileFileName);
}

LOCALPROC DoSrcFileAPBXCDaddFile(void)
{
	WriteAPBXCDObjectAp(APBoclsSrcBld, FileCounter,
		WriteSrcFileAPBXCDNameInSources, DoSrcFileAPBXCDaddFileBody);
}

LOCALPROC WriteSrcFileAPBXCDtype(void)
{
	char *s;
	blnr UseObjc = ((DoSrcFile_gd()->Flgm & kCSrcFlgmOjbc) != 0);
	blnr UseSwift = ((DoSrcFile_gd()->Flgm & kCSrcFlgmSwift) != 0);

	if (UseSwift) {
		s = "sourcecode.swift";
	} else if (UseObjc) {
		s = "sourcecode.c.objc";
	} else {
		s = "sourcecode.c.c";
	}
	WriteCStrToDestFile(s);
}

LOCALPROC DoSrcFileAPBXCDaddFileRefBody(void)
{
	WriteAPBXCDDObjAPropIsaFileReference();
	WriteAPBXCDDObjAPropFileEncoding30();
	WriteAPBXCDDObjAPropLastKnownFType(WriteSrcFileAPBXCDtype);
	WriteAPBXCDDObjAPropName(WriteSrcFileFileName);
	WriteAPBXCDDObjAPropPath(WriteSrcFileFilePath);
	WriteAPBXCDDObjAPropSourceTreeRoot();
}

LOCALPROC DoSrcFileAPBXCDaddFileRef(void)
{
	WriteAPBXCDObjectAp(APBoclsSrcRf, FileCounter,
		WriteSrcFileFileName,
		DoSrcFileAPBXCDaddFileRefBody);
}

LOCALPROC DoSrcFileAPBXCDaddToGroup(void)
{
	WriteAPBXCDobjlistelmp(APBoclsSrcRf, FileCounter,
		WriteSrcFileFileName);
}

LOCALPROC DoSrcFileAPBXCDaddToSources(void)
{
	WriteAPBXCDobjlistelmp(APBoclsSrcBld, FileCounter,
		WriteSrcFileAPBXCDNameInSources);
}

LOCALPROC WriteHeaderFileAPBXCDtype(void)
{
	WriteCStrToDestFile("sourcecode.c.h");
}

LOCALPROC DoHeaderFileXCDaddFileRefBody(void)
{
	WriteAPBXCDDObjAPropIsaFileReference();
	WriteAPBXCDDObjAPropFileEncoding30();
	WriteAPBXCDDObjAPropLastKnownFType(WriteHeaderFileAPBXCDtype);
	WriteAPBXCDDObjAPropName(WriteSrcFileHeaderName);
	WriteAPBXCDDObjAPropPath(WriteSrcFileHeaderPath);
	WriteAPBXCDDObjAPropSourceTreeRoot();
}

LOCALPROC DoHeaderFileXCDaddFileRef(void)
{
	if (0 == (DoSrcFile_gd()->Flgm & kCSrcFlgmNoHeader)) {
		WriteAPBXCDObjectAp(APBoclsHdr, FileCounter,
			WriteSrcFileHeaderName,
			DoHeaderFileXCDaddFileRefBody);
	}
}

LOCALPROC DoHeaderFileXCDaddToGroup(void)
{
	if (0 == (DoSrcFile_gd()->Flgm & kCSrcFlgmNoHeader)) {
		WriteAPBXCDobjlistelmp(APBoclsHdr, FileCounter,
			WriteSrcFileHeaderName);
	}
}

LOCALPROC WriteDocTypeAPBXCDIconFileInResources(void)
{
	WriteDocTypeIconFileName();
	WriteCStrToDestFile(" in Resources");
}

LOCALPROC DoDocTypeAPBXCDaddFileBody(void)
{
	WriteAPBXCDDObjAPropIsaBuildFile();
	WriteAPBXCDDObjAPropFileRef(APBoclsIcnsRf,
		DocTypeCounter, WriteDocTypeIconFileName);
}

LOCALPROC DoDocTypeAPBXCDaddFile(void)
{
	WriteAPBXCDObjectAp(APBoclsIcnsBld, DocTypeCounter,
		WriteDocTypeAPBXCDIconFileInResources,
		DoDocTypeAPBXCDaddFileBody);
}

LOCALPROC WriteDocTypeAPBXCDtype(void)
{
	WriteCStrToDestFile("image.icns");
}

LOCALPROC DoDocTypeAPBXCDaddFileRefBody(void)
{
	WriteAPBXCDDObjAPropIsaFileReference();
	WriteAPBXCDDObjAPropLastKnownFType(WriteDocTypeAPBXCDtype);
	WriteAPBXCDDObjAPropName(WriteDocTypeIconFileName);
	WriteAPBXCDDObjAPropPath(WriteDocTypeIconFilePath);
	WriteAPBXCDDObjAPropSourceTreeRoot();
}

LOCALPROC DoDocTypeAPBXCDaddFileRef(void)
{
	WriteAPBXCDObjectAp(APBoclsIcnsRf, DocTypeCounter,
		WriteDocTypeIconFileName, DoDocTypeAPBXCDaddFileRefBody);
}

LOCALPROC DoDocTypeAPBXCDaddToGroup(void)
{
	WriteAPBXCDobjlistelmp(APBoclsIcnsRf, DocTypeCounter,
		WriteDocTypeIconFileName);
}

LOCALPROC DoDocTypeAPBXCDaddToSources(void)
{
	WriteAPBXCDobjlistelmp(APBoclsIcnsBld, DocTypeCounter,
		WriteDocTypeAPBXCDIconFileInResources);
}

LOCALPROC WriteFrameWorkAPBXCDFileName(void)
{
	WriteCStrToDestFile(DoFrameWork_gd()->s);
	WriteCStrToDestFile(".framework");
}

LOCALPROC WriteFrameWorkAPBXCDFilePath(void)
{
	WriteCStrToDestFile("System/Library/Frameworks/");
	WriteFrameWorkAPBXCDFileName();
}

LOCALPROC WriteFrameWorkAPBXCDileInFrameworks(void)
{
	WriteFrameWorkAPBXCDFileName();
	WriteCStrToDestFile(" in Frameworks");
}

LOCALPROC DoFrameWorkAPBXCDaddFileBody(void)
{
	WriteAPBXCDDObjAPropIsaBuildFile();
	WriteAPBXCDDObjAPropFileRef(APBoclsFramRf,
		FileCounter, WriteFrameWorkAPBXCDFileName);
}

LOCALPROC DoFrameWorkAPBXCDaddFile(void)
{
	WriteAPBXCDObjectAp(APBoclsFramBld, FileCounter,
		WriteFrameWorkAPBXCDileInFrameworks,
		DoFrameWorkAPBXCDaddFileBody);
}

LOCALPROC WriteFrameWorkAPBXCDtype(void)
{
	WriteCStrToDestFile("wrapper.framework");
}

LOCALPROC DoFrameWorkAPBXCDaddFileRefBody(void)
{
	WriteAPBXCDDObjAPropIsaFileReference();
	WriteAPBXCDDObjAPropLastKnownFType(WriteFrameWorkAPBXCDtype);
	WriteAPBXCDDObjAPropName(WriteFrameWorkAPBXCDFileName);
	WriteAPBXCDDObjAPropPath(WriteFrameWorkAPBXCDFilePath);
	WriteAPBXCDDObjAPropSourceTreeSDKRoot();
}

LOCALPROC DoFrameWorkAPBXCDaddFileRef(void)
{
	WriteAPBXCDObjectAp(APBoclsFramRf, FileCounter,
		WriteFrameWorkAPBXCDFileName,
		DoFrameWorkAPBXCDaddFileRefBody);
}

LOCALPROC DoFrameworkAPBXCDaddToBuild(void)
{
	WriteAPBXCDobjlistelmp(APBoclsFramBld, FileCounter,
		WriteFrameWorkAPBXCDileInFrameworks);
}

LOCALPROC DoFrameworkAPBXCDaddToLibraries(void)
{
	WriteAPBXCDobjlistelmp(APBoclsFramRf, FileCounter,
		WriteFrameWorkAPBXCDFileName);
}

LOCALPROC DoExtraHeaderFileXCDaddFileRefBody(void)
{
	WriteAPBXCDDObjAPropIsaFileReference();
	WriteAPBXCDDObjAPropFileEncoding30();
	WriteAPBXCDDObjAPropLastKnownFType(WriteHeaderFileAPBXCDtype);
	WriteAPBXCDDObjAPropName(WriteExtraHeaderFileName);
	WriteAPBXCDDObjAPropPath(WriteExtraHeaderFilePath);
	WriteAPBXCDDObjAPropSourceTreeRoot();
}

LOCALPROC DoExtraHeaderFileXCDaddFileRef(void)
{
	WriteAPBXCDObjectAp(APBoclsInc, FileCounter,
		WriteExtraHeaderFileName,
		DoExtraHeaderFileXCDaddFileRefBody);
}

LOCALPROC DoExtraHeaderFileXCDaddToGroup(void)
{
	WriteAPBXCDobjlistelmp(APBoclsInc, FileCounter,
		WriteExtraHeaderFileName);
}

LOCALPROC WriteDummyLangFileNameInResources(void)
{
	WriteDummyLangFileName();
	WriteCStrToDestFile(" in Resources");
}

LOCALPROC DoDummyLangAPBXCDaddFileBody(void)
{
	WriteAPBXCDDObjAPropIsaBuildFile();
	WriteAPBXCDDObjAPropFileRef(APBospcLangDummyRf, 0,
		WriteDummyLangFileName);
}

LOCALPROC DoDummyLangAPBXCDaddFile(void)
{
	WriteAPBXCDObjectAp(APBospcLangDummyBld, 0,
		WriteDummyLangFileNameInResources,
		DoDummyLangAPBXCDaddFileBody);
}

LOCALPROC WriteDummyLangFilePath(void)
{
	WriteFileInDirToDestFile0(WriteLProjFolderPath,
		WriteDummyLangFileName);
}

LOCALPROC WriteLangDummyAPBXCDtype(void)
{
	WriteCStrToDestFile("text");
}

LOCALPROC DoLangDummyAPBXCDaddFileRefBody(void)
{
	WriteAPBXCDDObjAPropIsaFileReference();
	WriteAPBXCDDObjAPropFileEncoding30();
	WriteAPBXCDDObjAPropLastKnownFType(WriteLangDummyAPBXCDtype);
	WriteAPBXCDDObjAPropName(WriteLProjName);
	WriteAPBXCDDObjAPropPath(WriteDummyLangFilePath);
	WriteAPBXCDDObjAPropSourceTreeRoot();
}

LOCALPROC DoLangDummyAPBXCDaddFileRef(void)
{
	WriteAPBXCDObjectAp(APBospcLangRf, 0,
		WriteLProjName,
		DoLangDummyAPBXCDaddFileRefBody);
}

LOCALPROC DoLangDummyAPBXCDaddToSources(void)
{
	WriteAPBXCDobjlistelmp(APBospcLangDummyBld, 0,
		WriteDummyLangFileNameInResources);
}

LOCALPROC DoLangDummyAPBXCDaddVariant(void)
{
	WriteAPBXCDBeginObject(APBospcLangDummyRf,
		0, WriteDummyLangFileName);

		WriteAPBXCDDObjAPropIsa("PBXVariantGroup");
		WriteAPBXCDBgnObjList("children");
			WriteAPBXCDobjlistelmp(APBospcLangRf, 0, WriteLProjName);
		WriteAPBXCDEndObjList();
		WriteAPBXCDDObjAPropName(WriteDummyLangFileName);
		WriteAPBXCDDObjAPropSourceTreeGroup();
	WriteAPBXCDEndObject();
}

static void DoBeginSectionAPBXCD(char *Name)
{
	--DestFileIndent; --DestFileIndent;
	WriteBlankLineToDestFile();
	WriteBgnDestFileLn();
	WriteCStrToDestFile("/* Begin ");
	WriteCStrToDestFile(Name);
	WriteCStrToDestFile(" section */");
	WriteEndDestFileLn();
	++DestFileIndent; ++DestFileIndent;
}

static void DoEndSectionAPBXCD(char *Name)
{
	--DestFileIndent; --DestFileIndent;
	WriteBgnDestFileLn();
	WriteCStrToDestFile("/* End ");
	WriteCStrToDestFile(Name);
	WriteCStrToDestFile(" section */");
	WriteEndDestFileLn();
	++DestFileIndent; ++DestFileIndent;
}

LOCALPROC WriteXCDconfigname(void)
{
	char *s;

	switch (gbo_dbg) {
		case gbk_dbg_on:
			s = "Debug";
			break;
		case gbk_dbg_test:
			s = "Test";
			break;
		case gbk_dbg_off:
			s = "Release";
			break;
		default:
			s = "(unknown Debug Level)";
			break;
	}

	WriteCStrToDestFile(s);
}

LOCALPROC WriteProductAPBXCDtype(void)
{
	WriteCStrToDestFile("wrapper.application");
}

LOCALPROC DoProductAPBXCDaddFileRefBody(void)
{
	WriteAPBXCDDObjAPropIsaFileReference();
	WriteAPBXCDDObjAPropIncludeII0();
	WriteAPBXCDDObjAPropLastKnownFType(WriteProductAPBXCDtype);
	WriteAPBXCDDObjAPropPath(WriteAppNameStr);
	WriteAPBXCDDObjAPropSourceTree("BUILT_PRODUCTS_DIR");
}

LOCALPROC DoProductAPBXCDaddFileRef(void)
{
	WriteAPBXCDObjectAp(APBospcProductRef, 0,
		WriteAppNameStr,
		DoProductAPBXCDaddFileRefBody);
}

LOCALPROC WritePlistAPBXCDtype(void)
{
	WriteCStrToDestFile("text.plist.xml");
}

LOCALPROC DoPlistAPBXCDaddFileRefBody(void)
{
	WriteAPBXCDDObjAPropIsaFileReference();
	WriteAPBXCDDObjAPropFileEncoding4();
	WriteAPBXCDDObjAPropLastKnownFType(WritePlistAPBXCDtype);
	WriteAPBXCDDObjAPropName(WriteInfoPlistFileName);
	WriteAPBXCDDObjAPropPath(WriteInfoPlistFilePath);
	WriteAPBXCDDObjAPropSourceTreeRoot();
}

LOCALPROC DoPlistAPBXCDaddFileRef(void)
{
	WriteAPBXCDObjectAp(APBospcPlistRf, 0,
		WriteInfoPlistFileName,
		DoPlistAPBXCDaddFileRefBody);
}

LOCALPROC WriteAPBXCDBuildSettings(void)
{
	WriteDestFileLn("ALWAYS_SEARCH_USER_PATHS = NO;");

	/* Apple Silicon only; there is no Intel host build. */
	WriteDestFileLn("ARCHS = arm64;");
	WriteDestFileLn("CLANG_WARN_UNREACHABLE_CODE = YES;");
	WriteDestFileLn("CODE_SIGN_IDENTITY = \"\";");
	WriteDestFileLn(
		"CONFIGURATION_BUILD_DIR = \"$(PROJECT_DIR)\";");
	WriteDestFileLn("COPY_PHASE_STRIP = NO;");
	if (gbk_dbg_on != gbo_dbg) {
		WriteDestFileLn("DEPLOYMENT_POSTPROCESSING = YES;");
	}
	WriteDestFileLn("GCC_CW_ASM_SYNTAX = NO;");
	if (gbk_dbg_on != gbo_dbg) {
		WriteDestFileLn("GCC_GENERATE_DEBUGGING_SYMBOLS = NO;");
	}
	if (gbk_dbg_on == gbo_dbg) {
		WriteDestFileLn("GCC_OPTIMIZATION_LEVEL = 0;");
	} else {
		/*
			-O2, not -O3 or -Ofast: the softfloat FPU in
			FPMATHEM.h depends on strict IEEE semantics.
		*/
		WriteDestFileLn("GCC_OPTIMIZATION_LEVEL = 2;");
	}
	WriteDestFileLn("GCC_PRECOMPILE_PREFIX_HEADER = NO;");
	WriteDestFileLn("GCC_PREFIX_HEADER = \"\";");
	WriteDestFileLn("GCC_SYMBOLS_PRIVATE_EXTERN = NO;");
	WriteDestFileLn("GCC_WARN_64_TO_32_BIT_CONVERSION = YES;");
	WriteDestFileLn("GCC_WARN_ABOUT_MISSING_PROTOTYPES = YES;");

	WriteBgnDestFileLn();
	WriteCStrToDestFile("INFOPLIST_FILE = ");
	WriteInfoPlistFilePath();
	WriteCStrToDestFile(";");
	WriteEndDestFileLn();
	WriteDestFileLn("INSTALL_PATH = \"$(HOME)/Applications\";");
	if (gbk_dbg_on != gbo_dbg) {
		WriteDestFileLn("LLVM_LTO = YES_THIN;");
	}
	/*
		The App Intents metadata extractor runs for every Swift
		target and warns when the app does not link AppIntents.
		This app never will, so skip the extraction step.
	*/
	WriteDestFileLn("LM_SKIP_METADATA_EXTRACTION = YES;");
	/*
		An explicit floor rather than
		$(MACOSX_RECOMMENDED_DEPLOYMENT_TARGET), which resolves
		to whatever the build machine runs and so produced an
		application that refused to start on anything older.

		14.0 is the lowest release that has every API the
		sources use: the frame driver takes its CADisplayLink
		from NSScreen, which is new in macOS 14, and that is the
		newest requirement. The SwiftUI in the Settings window
		and About panel (formStyle(.grouped), foregroundStyle)
		needs only macOS 13.

		Must match LSMinimumSystemVersion in WRMPLIST.i.
	*/
	WriteDestFileLn("MACOSX_DEPLOYMENT_TARGET = 14.0;");

	WriteBgnDestFileLn();
	WriteCStrToDestFile("PRODUCT_BUNDLE_IDENTIFIER = ");
	WriteTheBundleIdentifier();
	WriteCStrToDestFile(";");
	WriteEndDestFileLn();

	WriteBgnDestFileLn();
	WriteCStrToDestFile("PRODUCT_NAME = ");
	WriteStrAppAbbrev();
	WriteCStrToDestFile(";");
	WriteEndDestFileLn();
	WriteDestFileLn("SDKROOT = macosx;");
	if (gbk_dbg_on != gbo_dbg) {
		WriteDestFileLn("SEPARATE_STRIP = YES;");
		WriteDestFileLn("STRIPFLAGS = \"-u -r\";");
		WriteDestFileLn("STRIP_INSTALLED_PRODUCT = YES;");
	}
	if (HaveSwiftSrcFiles) {
		/*
			Swift interoperates with the Objective-C and C
			sources through two generated headers. The bridging
			header is hand written and exposes C to Swift. The
			interface header is emitted by the compiler and
			exposes Swift to Objective-C. Both names are pinned
			here rather than left to default, so that the
			#import in the Objective-C sources is stable.
		*/
		WriteDestFileLn("CLANG_ENABLE_MODULES = YES;");
		WriteBgnDestFileLn();
		WriteCStrToDestFile("PRODUCT_MODULE_NAME = ");
		WriteStrAppAbbrev();
		WriteCStrToDestFile(";");
		WriteEndDestFileLn();
		WriteBgnDestFileLn();
		WriteCStrToDestFile("SWIFT_OBJC_BRIDGING_HEADER = \"");
		WriteCStrToDestFile(src_d_name);
		WriteCStrToDestFile("/" kSwiftBridgeHeaderName "\";");
		WriteEndDestFileLn();
		WriteDestFileLn("SWIFT_OBJC_INTERFACE_HEADER_NAME = "
			"\"" kSwiftIfaceHeaderName "\";");
		if (gbk_dbg_on == gbo_dbg) {
			WriteDestFileLn("SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";");
		} else {
			WriteDestFileLn("SWIFT_COMPILATION_MODE = wholemodule;");
			WriteDestFileLn("SWIFT_OPTIMIZATION_LEVEL = \"-O\";");
		}
		WriteDestFileLn("SWIFT_VERSION = 5.0;");
	}
	WriteDestFileLn("USER_HEADER_SEARCH_PATHS = \"$(SRCROOT)/"
		cfg_d_name
		"\";");
	WriteAPBXCDBgnObjList("WARNING_CFLAGS");
		WriteDestFileLn("\"-Wall\",");
		WriteDestFileLn("\"-Wextra\",");
		WriteDestFileLn("\"-Wno-unused-parameter\",");
		WriteDestFileLn("\"-Wshadow\",");
		WriteDestFileLn("\"-Wimplicit-fallthrough\",");
		WriteDestFileLn("\"-Wundef\",");
		WriteDestFileLn("\"-Wstrict-prototypes\",");
		WriteDestFileLn("\"-Wno-uninitialized\",");
	WriteAPBXCDEndObjList();
}

LOCALPROC WriteStrFrameworks(void)
{
	WriteCStrToDestFile("Frameworks");
}

LOCALPROC WriteStrSources(void)
{
	WriteCStrToDestFile("Sources");
}

LOCALPROC WriteStrResources(void)
{
	WriteCStrToDestFile("Resources");
}

LOCALPROC WriteStrFrameworksLibraries(void)
{
	WriteCStrToDestFile("External Frameworks and Libraries");
}

LOCALPROC WriteStrQuoteFrameworksLibraries(void)
{
	WriteQuoteToDestFile();
	WriteStrFrameworksLibraries();
	WriteQuoteToDestFile();
}

LOCALPROC WriteStrProducts(void)
{
	WriteCStrToDestFile("Products");
}

LOCALPROC WriteStrHeaders(void)
{
	WriteCStrToDestFile("Headers");
}

LOCALPROC WriteStrIncludes(void)
{
	WriteCStrToDestFile("Includes");
}

LOCALPROC WriteStrProjectObject(void)
{
	WriteCStrToDestFile("Project object");
}

LOCALPROC WriteAPBXCDDObjAPropIsaAppTarg(void)
{
	WriteAPBXCDDObjAPropIsa("PBXNativeTarget");
}

LOCALPROC WriteStrConfListPBXProject(void)
{
	WriteCStrToDestFile("Build configuration list for PBXProject \"");
	WriteStrAppAbbrev();
	WriteCStrToDestFile("\"");
}

LOCALPROC WriteStrConfListPBXNativeTarget(void)
{
	WriteCStrToDestFile(
		"Build configuration list for PBXNativeTarget \"");
	WriteStrAppAbbrev();
	WriteCStrToDestFile("\"");
}

LOCALPROC WriteXCDProjectFile(void)
{
	WriteDestFileLn("// !$*UTF8*$!");
	WriteDestFileLn("{");
	++DestFileIndent;
		WriteDestFileLn("archiveVersion = 1;");
		WriteDestFileLn("classes = {");
		WriteDestFileLn("};");
		WriteDestFileLn("objectVersion = 50;");
		WriteDestFileLn("objects = {");
	++DestFileIndent;

	DoBeginSectionAPBXCD("PBXBuildFile");
		DoAllSrcFilesWithSetup(DoSrcFileAPBXCDaddFile);
		DoAllDocTypesWithSetup(DoDocTypeAPBXCDaddFile);

		DoAllFrameWorksWithSetup(DoFrameWorkAPBXCDaddFile);
		DoDummyLangAPBXCDaddFile();
	DoEndSectionAPBXCD("PBXBuildFile");

	DoBeginSectionAPBXCD("PBXFileReference");
		DoAllSrcFilesWithSetup(DoSrcFileAPBXCDaddFileRef);

		DoAllSrcFilesWithSetup(DoHeaderFileXCDaddFileRef);
		DoAllExtraHeaders2WithSetup(
			DoExtraHeaderFileXCDaddFileRef);

		DoAllDocTypesWithSetup(DoDocTypeAPBXCDaddFileRef);

		DoAllFrameWorksWithSetup(DoFrameWorkAPBXCDaddFileRef);

		DoProductAPBXCDaddFileRef();

		DoPlistAPBXCDaddFileRef();
		DoLangDummyAPBXCDaddFileRef();
	DoEndSectionAPBXCD("PBXFileReference");

	DoBeginSectionAPBXCD("PBXFrameworksBuildPhase");
		WriteAPBXCDBeginObject(APBospcPhaseLibs, 0, WriteStrFrameworks);
			WriteAPBXCDDObjAPropIsa("PBXFrameworksBuildPhase");
			WriteDestFileLn("buildActionMask = 2147483647;");
			WriteAPBXCDBgnObjList("files");
				DoAllFrameWorksWithSetup(
					DoFrameworkAPBXCDaddToBuild);
			WriteAPBXCDEndObjList();
			WriteDestFileLn("runOnlyForDeploymentPostprocessing = 0;");
		WriteAPBXCDEndObject();
	DoEndSectionAPBXCD("PBXFrameworksBuildPhase");

	DoBeginSectionAPBXCD("PBXGroup");
		WriteAPBXCDBeginObject(APBospcSources, 0, WriteStrSources);
			WriteAPBXCDDObjAPropIsaGroup();
			WriteAPBXCDBgnObjList("children");
				DoAllSrcFilesWithSetup(DoSrcFileAPBXCDaddToGroup);
			WriteAPBXCDEndObjList();
			WriteAPBXCDDObjAPropName(WriteStrSources);
			WriteAPBXCDDObjAPropSourceTreeGroup();
		WriteAPBXCDEndObject();

		WriteAPBXCDBeginObject(APBospcResources,
			0, WriteStrResources);

			WriteAPBXCDDObjAPropIsaGroup();
			WriteAPBXCDBgnObjList("children");
				DoAllDocTypesWithSetup(
					DoDocTypeAPBXCDaddToGroup);
				WriteAPBXCDobjlistelmp(APBospcPlistRf,
					0, WriteInfoPlistFileName);
				WriteAPBXCDobjlistelmp(APBospcLangDummyRf,
					0, WriteDummyLangFileName);
			WriteAPBXCDEndObjList();
			WriteAPBXCDDObjAPropName(WriteStrResources);
			WriteAPBXCDDObjAPropSourceTreeGroup();
		WriteAPBXCDEndObject();

		WriteAPBXCDBeginObject(APBospcLibraries,
			0, WriteStrFrameworksLibraries);

			WriteAPBXCDDObjAPropIsaGroup();
			WriteAPBXCDBgnObjList("children");
				DoAllFrameWorksWithSetup(
					DoFrameworkAPBXCDaddToLibraries);
			WriteAPBXCDEndObjList();
			WriteAPBXCDDObjAPropName(
				WriteStrQuoteFrameworksLibraries);
			WriteAPBXCDDObjAPropSourceTreeGroup();
		WriteAPBXCDEndObject();

		WriteAPBXCDBeginObject(APBospcProducts, 0, WriteStrProducts);
			WriteAPBXCDDObjAPropIsaGroup();
			WriteAPBXCDBgnObjList("children");
				WriteAPBXCDobjlistelmp(APBospcProductRef,
					0, WriteAppNameStr);
			WriteAPBXCDEndObjList();
			WriteAPBXCDDObjAPropName(WriteStrProducts);
			WriteAPBXCDDObjAPropSourceTreeGroup();
		WriteAPBXCDEndObject();

		WriteAPBXCDBeginObject(APBospcMainGroup, 0, WriteStrAppAbbrev);
			WriteAPBXCDDObjAPropIsaGroup();
			WriteAPBXCDBgnObjList("children");
				WriteAPBXCDobjlistelmp(APBospcSources,
					0, WriteStrSources);
				WriteAPBXCDobjlistelmp(APBospcSrcHeaders,
					0, WriteStrHeaders);
				WriteAPBXCDobjlistelmp(APBospcIncludes,
					0, WriteStrIncludes);
				WriteAPBXCDobjlistelmp(APBospcResources,
					0, WriteStrResources);
				WriteAPBXCDobjlistelmp(APBospcLibraries,
					0, WriteStrFrameworksLibraries);
				WriteAPBXCDobjlistelmp(APBospcProducts,
					0, WriteStrProducts);
			WriteAPBXCDEndObjList();

			WriteAPBXCDDObjAPropName(WriteStrAppAbbrev);
			WriteAPBXCDDObjAPropSourceTreeGroup();
		WriteAPBXCDEndObject();
		WriteAPBXCDBeginObject(APBospcSrcHeaders,
			0, WriteStrHeaders);

			WriteAPBXCDDObjAPropIsaGroup();
			WriteAPBXCDBgnObjList("children");
				DoAllSrcFilesWithSetup(
					DoHeaderFileXCDaddToGroup);
			WriteAPBXCDEndObjList();
			WriteAPBXCDDObjAPropName(WriteStrHeaders);
			WriteAPBXCDDObjAPropSourceTreeGroup();
		WriteAPBXCDEndObject();
		WriteAPBXCDBeginObject(APBospcIncludes,
			0, WriteStrIncludes);

			WriteAPBXCDDObjAPropIsaGroup();
			WriteAPBXCDBgnObjList("children");
				DoAllExtraHeaders2WithSetup(
					DoExtraHeaderFileXCDaddToGroup);
			WriteAPBXCDEndObjList();
			WriteAPBXCDDObjAPropName(WriteStrIncludes);
			WriteAPBXCDDObjAPropSourceTreeGroup();
		WriteAPBXCDEndObject();
	DoEndSectionAPBXCD("PBXGroup");

	DoBeginSectionAPBXCD("PBXNativeTarget");
		WriteAPBXCDBeginObject(APBospcTarget, 0, WriteStrAppAbbrev);
			WriteAPBXCDDObjAPropIsaAppTarg();
			WriteAPBXCDDObjAProp_SO("buildConfigurationList",
				APBospcLstNatCnfg, 0,
				WriteStrConfListPBXNativeTarget);
			WriteAPBXCDBgnObjList("buildPhases");
				WriteAPBXCDobjlistelmp(APBospcBunRsrcs,
					0, WriteStrResources);
				WriteAPBXCDobjlistelmp(APBospcPhaseSrcs,
					0, WriteStrSources);
				WriteAPBXCDobjlistelmp(APBospcPhaseLibs,
					0, WriteStrFrameworks);
			WriteAPBXCDEndObjList();
			WriteAPBXCDBgnObjList("buildRules");
			WriteAPBXCDEndObjList();
			WriteAPBXCDBgnObjList("dependencies");
			WriteAPBXCDEndObjList();

			WriteAPBXCDDObjAPropName(WriteStrAppAbbrev);

			WriteDestFileLn(
				"productInstallPath = \"$(HOME)/Applications\";");

			WriteBgnDestFileLn();
			WriteCStrToDestFile("productName = ");
			WriteStrAppAbbrev();
			WriteCStrToDestFile(";");
			WriteEndDestFileLn();

			WriteAPBXCDDObjAProp_SO("productReference",
				APBospcProductRef, 0,
				WriteAppNameStr);

			WriteDestFileLn(
				"productType = "
				"\"com.apple.product-type.application\";");
		WriteAPBXCDEndObject();
	DoEndSectionAPBXCD("PBXNativeTarget");

	DoBeginSectionAPBXCD("PBXProject");
		WriteAPBXCDBeginObject(APBospcRoot, 0, WriteStrProjectObject);
			WriteAPBXCDDObjAPropIsa("PBXProject");
			WriteDestFileLn("attributes = {");
			++DestFileIndent;
				WriteBgnDestFileLn();
				WriteCStrToDestFile("LastUpgradeCheck = ");
				WriteCharToDestFile('0'
					+ ((ide_vers / 10000) % 10));
				WriteCharToDestFile('0' + ((ide_vers / 1000) % 10));
				WriteCharToDestFile('0' + ((ide_vers / 100) % 10));
				WriteCStrToDestFile("0;");
				WriteEndDestFileLn();
			--DestFileIndent;
			WriteDestFileLn("};");
			WriteAPBXCDDObjAProp_SO("buildConfigurationList",
				APBospcLstPrjCnfg, 0,
				WriteStrConfListPBXProject);

			WriteDestFileLn(
				"compatibilityVersion = \"Xcode 9.3\";");

			WriteDestFileLn("hasScannedForEncodings = 1;");

			WriteAPBXCDDObjAProp_SO("mainGroup",
				APBospcMainGroup, 0,
				WriteStrAppAbbrev);

			WriteAPBXCDDObjAProp_SO("productRefGroup",
				APBospcProducts, 0,
				WriteStrProducts);

			WriteDestFileLn("projectDirPath = \"\";");

			WriteDestFileLn("projectRoot = \"\";");

			WriteAPBXCDBgnObjList("targets");
				WriteAPBXCDobjlistelmp(APBospcTarget,
					0, WriteStrAppAbbrev);
			WriteAPBXCDEndObjList();
		WriteAPBXCDEndObject();
	DoEndSectionAPBXCD("PBXProject");

	DoBeginSectionAPBXCD("PBXResourcesBuildPhase");
		WriteAPBXCDBeginObject(APBospcBunRsrcs,
			0, WriteStrResources);

			WriteAPBXCDDObjAPropIsa("PBXResourcesBuildPhase");
			WriteDestFileLn("buildActionMask = 2147483647;");
			WriteAPBXCDBgnObjList("files");
				DoAllDocTypesWithSetup(
					DoDocTypeAPBXCDaddToSources);
				DoLangDummyAPBXCDaddToSources();
			WriteAPBXCDEndObjList();
			WriteDestFileLn(
				"runOnlyForDeploymentPostprocessing = 0;");
		WriteAPBXCDEndObject();
	DoEndSectionAPBXCD("PBXResourcesBuildPhase");

	DoBeginSectionAPBXCD("PBXSourcesBuildPhase");
		WriteAPBXCDBeginObject(APBospcPhaseSrcs, 0, WriteStrSources);
			WriteAPBXCDDObjAPropIsa("PBXSourcesBuildPhase");
			WriteDestFileLn("buildActionMask = 2147483647;");
			WriteAPBXCDBgnObjList("files");
				DoAllSrcFilesSortWithSetup(
					DoSrcFileAPBXCDaddToSources);
			WriteAPBXCDEndObjList();
			WriteDestFileLn("runOnlyForDeploymentPostprocessing = 0;");
		WriteAPBXCDEndObject();
	DoEndSectionAPBXCD("PBXSourcesBuildPhase");

	DoBeginSectionAPBXCD("PBXVariantGroup");
		DoLangDummyAPBXCDaddVariant();
	DoEndSectionAPBXCD("PBXVariantGroup");

	DoBeginSectionAPBXCD("XCBuildConfiguration");
		WriteAPBXCDBeginObject(APBospcNatCnfg,
			0, WriteXCDconfigname);

			WriteAPBXCDDObjAPropIsa("XCBuildConfiguration");
			WriteDestFileLn("buildSettings = {");
			++DestFileIndent;
				WriteAPBXCDBuildSettings();
			--DestFileIndent;
			WriteDestFileLn("};");
			WriteAPBXCDDObjAPropName(WriteXCDconfigname);
		WriteAPBXCDEndObject();
		WriteAPBXCDBeginObject(APBospcPrjCnfg,
			0, WriteXCDconfigname);

			WriteAPBXCDDObjAPropIsa("XCBuildConfiguration");
			WriteDestFileLn("buildSettings = {");
			WriteDestFileLn("};");
			WriteAPBXCDDObjAPropName(WriteXCDconfigname);
		WriteAPBXCDEndObject();
	DoEndSectionAPBXCD("XCBuildConfiguration");

	DoBeginSectionAPBXCD("XCConfigurationList");
		WriteAPBXCDBeginObject(APBospcLstNatCnfg, 0,
			WriteStrConfListPBXNativeTarget);

			WriteAPBXCDDObjAPropIsa("XCConfigurationList");
			WriteAPBXCDBgnObjList("buildConfigurations");
				WriteAPBXCDobjlistelmp(APBospcNatCnfg,
					0, WriteXCDconfigname);
			WriteAPBXCDEndObjList();
			WriteAPBXCDDObjAProp_SS(
				"defaultConfigurationIsVisible", "0");
			WriteAPBXCDDObjAProp_SP(
				"defaultConfigurationName", WriteXCDconfigname);
		WriteAPBXCDEndObject();
		WriteAPBXCDBeginObject(APBospcLstPrjCnfg, 0,
			WriteStrConfListPBXProject);

			WriteAPBXCDDObjAPropIsa("XCConfigurationList");
			WriteAPBXCDBgnObjList("buildConfigurations");
				WriteAPBXCDobjlistelmp(APBospcPrjCnfg,
					0, WriteXCDconfigname);
			WriteAPBXCDEndObjList();
			WriteAPBXCDDObjAProp_SS(
				"defaultConfigurationIsVisible", "0");
			WriteAPBXCDDObjAProp_SP(
				"defaultConfigurationName", WriteXCDconfigname);
		WriteAPBXCDEndObject();
	DoEndSectionAPBXCD("XCConfigurationList");

	--DestFileIndent;
		WriteDestFileLn("};");
		WriteBgnDestFileLn();
		WriteCStrToDestFile("rootObject = ");
		WriteAPBXCDObjectIdAndComment(APBospcRoot,
			0, WriteStrProjectObject);
		WriteCStrToDestFile(";");
		WriteEndDestFileLn();
	--DestFileIndent;
	WriteDestFileLn("}");
}

LOCALPROC WriteOutDummyLangContents(void)
{
	WriteDestFileLn("dummy");
}

LOCALPROC WriteXCDSpecificFiles(void)
{
	MakeSubDirectory("my_proj_d", "my_project_d", vStrAppAbbrev,
		".xcodeproj");

	WriteADstFile1("my_proj_d",
		"project", ".pbxproj", "project file",
		WriteXCDProjectFile);

	WritePListData();

	MakeSubDirectory("my_lang_d", "my_config_d",
		GetLProjName(gbo_lang), ".lproj");

	WriteADstFile1("my_lang_d",
		"dummy", ".txt", "Dummy",
		WriteOutDummyLangContents);

	if (WantSandbox) {
		WriteEntitlementsData();
	}
}
