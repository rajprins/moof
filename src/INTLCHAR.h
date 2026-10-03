/*
	INTLCHAR.h

	Copyright (C) 2010 Paul C. Pratt

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
	InterNaTionAL CHARacters
*/

/*
	Character cells.

	A cell is a character in the private character set that the
	string constants in the STRCN*.h files are translated into by
	ClStrAppendSubstCStr, before being mapped to a host character set
	by one of the Cell2*Map tables below.

	The cells used to double as indexes into an 8x16 pixel font,
	along with box drawing, icon and banner cells, for drawing the
	Control Mode overlay into the emulated screen. The overlay is
	gone, so the glyphs and the drawing only cells are too.

	The order here must match every Cell2*Map table.
*/

enum {
	kCellUpA,
	kCellUpB,
	kCellUpC,
	kCellUpD,
	kCellUpE,
	kCellUpF,
	kCellUpG,
	kCellUpH,
	kCellUpI,
	kCellUpJ,
	kCellUpK,
	kCellUpL,
	kCellUpM,
	kCellUpN,
	kCellUpO,
	kCellUpP,
	kCellUpQ,
	kCellUpR,
	kCellUpS,
	kCellUpT,
	kCellUpU,
	kCellUpV,
	kCellUpW,
	kCellUpX,
	kCellUpY,
	kCellUpZ,
	kCellLoA,
	kCellLoB,
	kCellLoC,
	kCellLoD,
	kCellLoE,
	kCellLoF,
	kCellLoG,
	kCellLoH,
	kCellLoI,
	kCellLoJ,
	kCellLoK,
	kCellLoL,
	kCellLoM,
	kCellLoN,
	kCellLoO,
	kCellLoP,
	kCellLoQ,
	kCellLoR,
	kCellLoS,
	kCellLoT,
	kCellLoU,
	kCellLoV,
	kCellLoW,
	kCellLoX,
	kCellLoY,
	kCellLoZ,
	kCellDigit0,
	kCellDigit1,
	kCellDigit2,
	kCellDigit3,
	kCellDigit4,
	kCellDigit5,
	kCellDigit6,
	kCellDigit7,
	kCellDigit8,
	kCellDigit9,
	kCellExclamation,
	kCellAmpersand,
	kCellApostrophe,
	kCellLeftParen,
	kCellRightParen,
	kCellComma,
	kCellHyphen,
	kCellPeriod,
	kCellSlash,
	kCellColon,
	kCellSemicolon,
	kCellQuestion,
	kCellEllipsis,
	kCellUnderscore,
	kCellLeftDQuote,
	kCellRightDQuote,
	kCellLeftSQuote,
	kCellRightSQuote,
	kCellCopyright,
	kCellSpace,

#if NeedIntlChars
	kCellUpADiaeresis,
	kCellUpARing,
	kCellUpCCedilla,
	kCellUpEAcute,
	kCellUpNTilde,
	kCellUpODiaeresis,
	kCellUpUDiaeresis,
	kCellLoAAcute,
	kCellLoAGrave,
	kCellLoACircumflex,
	kCellLoADiaeresis,
	kCellLoATilde,
	kCellLoARing,
	kCellLoCCedilla,
	kCellLoEAcute,
	kCellLoEGrave,
	kCellLoECircumflex,
	kCellLoEDiaeresis,
	kCellLoIAcute,
	kCellLoIGrave,
	kCellLoICircumflex,
	kCellLoIDiaeresis,
	kCellLoNTilde,
	kCellLoOAcute,
	kCellLoOGrave,
	kCellLoOCircumflex,
	kCellLoODiaeresis,
	kCellLoOTilde,
	kCellLoUAcute,
	kCellLoUGrave,
	kCellLoUCircumflex,
	kCellLoUDiaeresis,

	kCellUpAE,
	kCellUpOStroke,

	kCellLoAE,
	kCellLoOStroke,
	kCellInvQuestion,
	kCellInvExclam,

	kCellUpAGrave,
	kCellUpATilde,
	kCellUpOTilde,
	kCellUpLigatureOE,
	kCellLoLigatureOE,

	kCellLoYDiaeresis,
	kCellUpYDiaeresis,

	kCellUpACircumflex,
	kCellUpECircumflex,
	kCellUpAAcute,
	kCellUpEDiaeresis,
	kCellUpEGrave,
	kCellUpIAcute,
	kCellUpICircumflex,
	kCellUpIDiaeresis,
	kCellUpIGrave,
	kCellUpOAcute,
	kCellUpOCircumflex,

	kCellUpOGrave,
	kCellUpUAcute,
	kCellUpUCircumflex,
	kCellUpUGrave,
	kCellSharpS,

	kCellUpACedille,
	kCellLoACedille,
	kCellUpCAcute,
	kCellLoCAcute,
	kCellUpECedille,
	kCellLoECedille,
	kCellUpLBar,
	kCellLoLBar,
	kCellUpNAcute,
	kCellLoNAcute,
	kCellUpSAcute,
	kCellLoSAcute,
	kCellUpZAcute,
	kCellLoZAcute,
	kCellUpZDot,
	kCellLoZDot,
	kCellMidDot,
	kCellUpCCaron,
	kCellLoCCaron,
	kCellLoECaron,
	kCellLoRCaron,
	kCellLoSCaron,
	kCellLoTCaron,
	kCellLoZCaron,
	kCellUpYAcute,
	kCellLoYAcute,
	kCellLoUDblac,
	kCellLoURing,
	kCellUpDStroke,
	kCellLoDStroke,
#endif

	kNumCells
};

#ifndef NeedCell2MacAsciiMap
#define NeedCell2MacAsciiMap 0
#endif

#if NeedCell2MacAsciiMap
/* Mac Roman character set */
LOCALVAR const char Cell2MacAsciiMap[] = {
	'\101', /* kCellUpA */
	'\102', /* kCellUpB */
	'\103', /* kCellUpC */
	'\104', /* kCellUpD */
	'\105', /* kCellUpE */
	'\106', /* kCellUpF */
	'\107', /* kCellUpG */
	'\110', /* kCellUpH */
	'\111', /* kCellUpI */
	'\112', /* kCellUpJ */
	'\113', /* kCellUpK */
	'\114', /* kCellUpL */
	'\115', /* kCellUpM */
	'\116', /* kCellUpN */
	'\117', /* kCellUpO */
	'\120', /* kCellUpP */
	'\121', /* kCellUpQ */
	'\122', /* kCellUpR */
	'\123', /* kCellUpS */
	'\124', /* kCellUpT */
	'\125', /* kCellUpU */
	'\126', /* kCellUpV */
	'\127', /* kCellUpW */
	'\130', /* kCellUpX */
	'\131', /* kCellUpY */
	'\132', /* kCellUpZ */
	'\141', /* kCellLoA */
	'\142', /* kCellLoB */
	'\143', /* kCellLoC */
	'\144', /* kCellLoD */
	'\145', /* kCellLoE */
	'\146', /* kCellLoF */
	'\147', /* kCellLoG */
	'\150', /* kCellLoH */
	'\151', /* kCellLoI */
	'\152', /* kCellLoJ */
	'\153', /* kCellLoK */
	'\154', /* kCellLoL */
	'\155', /* kCellLoM */
	'\156', /* kCellLoN */
	'\157', /* kCellLoO */
	'\160', /* kCellLoP */
	'\161', /* kCellLoQ */
	'\162', /* kCellLoR */
	'\163', /* kCellLoS */
	'\164', /* kCellLoT */
	'\165', /* kCellLoU */
	'\166', /* kCellLoV */
	'\167', /* kCellLoW */
	'\170', /* kCellLoX */
	'\171', /* kCellLoY */
	'\172', /* kCellLoZ */
	'\060', /* kCellDigit0 */
	'\061', /* kCellDigit1 */
	'\062', /* kCellDigit2 */
	'\063', /* kCellDigit3 */
	'\064', /* kCellDigit4 */
	'\065', /* kCellDigit5 */
	'\066', /* kCellDigit6 */
	'\067', /* kCellDigit7 */
	'\070', /* kCellDigit8 */
	'\071', /* kCellDigit9 */
	'\041', /* kCellExclamation */
	'\046', /* kCellAmpersand */
	'\047', /* kCellApostrophe */
	'\050', /* kCellLeftParen */
	'\051', /* kCellRightParen */
	'\054', /* kCellComma */
	'\055', /* kCellHyphen */
	'\056', /* kCellPeriod */
	'\057', /* kCellSlash */
	'\072', /* kCellColon */
	'\073', /* kCellSemicolon */
	'\077', /* kCellQuestion */
	'\311', /* kCellEllipsis */
	'\137', /* kCellUnderscore */
	'\322', /* kCellLeftDQuote */
	'\323', /* kCellRightDQuote */
	'\324', /* kCellLeftSQuote */
	'\325', /* kCellRightSQuote */
	'\251', /* kCellCopyright */
	'\040', /* kCellSpace */

#if NeedIntlChars
	'\200', /* kCellUpADiaeresis */
	'\201', /* kCellUpARing */
	'\202', /* kCellUpCCedilla */
	'\203', /* kCellUpEAcute */
	'\204', /* kCellUpNTilde */
	'\205', /* kCellUpODiaeresis */
	'\206', /* kCellUpUDiaeresis */
	'\207', /* kCellLoAAcute */
	'\210', /* kCellLoAGrave */
	'\211', /* kCellLoACircumflex */
	'\212', /* kCellLoADiaeresis */
	'\213', /* kCellLoATilde */
	'\214', /* kCellLoARing */
	'\215', /* kCellLoCCedilla */
	'\216', /* kCellLoEAcute */
	'\217', /* kCellLoEGrave */
	'\220', /* kCellLoECircumflex */
	'\221', /* kCellLoEDiaeresis */
	'\222', /* kCellLoIAcute */
	'\223', /* kCellLoIGrave */
	'\224', /* kCellLoICircumflex */
	'\225', /* kCellLoIDiaeresis */
	'\226', /* kCellLoNTilde */
	'\227', /* kCellLoOAcute */
	'\230', /* kCellLoOGrave */
	'\231', /* kCellLoOCircumflex */
	'\232', /* kCellLoODiaeresis */
	'\233', /* kCellLoOTilde */
	'\234', /* kCellLoUAcute */
	'\235', /* kCellLoUGrave */
	'\236', /* kCellLoUCircumflex */
	'\237', /* kCellLoUDiaeresis */

	'\256', /* kCellUpAE */
	'\257', /* kCellUpOStroke */

	'\276', /* kCellLoAE */
	'\277', /* kCellLoOStroke */
	'\300', /* kCellInvQuestion */
	'\301', /* kCellInvExclam */

	'\313', /* kCellUpAGrave */
	'\314', /* kCellUpATilde */
	'\315', /* kCellUpOTilde */
	'\316', /* kCellUpLigatureOE */
	'\317', /* kCellLoLigatureOE */

	'\330', /* kCellLoYDiaeresis */
	'\331', /* kCellUpYDiaeresis */

	'\345', /* kCellUpACircumflex */
	'\346', /* kCellUpECircumflex */
	'\347', /* kCellUpAAcute */
	'\350', /* kCellUpEDiaeresis */
	'\351', /* kCellUpEGrave */
	'\352', /* kCellUpIAcute */
	'\353', /* kCellUpICircumflex */
	'\354', /* kCellUpIDiaeresis */
	'\355', /* kCellUpIGrave */
	'\356', /* kCellUpOAcute */
	'\357', /* kCellUpOCircumflex */

	'\361', /* kCellUpOGrave */
	'\362', /* kCellUpUAcute */
	'\363', /* kCellUpUCircumflex */
	'\364', /* kCellUpUGrave */
	'\247', /* kCellSharpS */

	'\260', /* kCellUpACedille */
	'\261', /* kCellLoACedille */
	'\262', /* kCellUpCAcute */
	'\263', /* kCellLoCAcute */
	'\264', /* kCellUpECedille */
	'\265', /* kCellLoECedille */
	'\266', /* kCellUpLBar */
	'\267', /* kCellLoLBar */
	'\270', /* kCellUpNAcute */
	'\271', /* kCellLoNAcute */
	'\272', /* kCellUpSAcute */
	'\273', /* kCellLoSAcute */
	'\274', /* kCellUpZAcute */
	'\275', /* kCellLoZAcute */
	'\276', /* kCellUpZDot */
	'\277', /* kCellLoZDot */
	'\341', /* kCellMidDot */
	'\103', /* kCellUpCCaron */
	'\143', /* kCellLoCCaron */
	'\145', /* kCellLoECaron */
	'\162', /* kCellLoRCaron */
	'\163', /* kCellLoSCaron */
	'\164', /* kCellLoTCaron */
	'\172', /* kCellLoZCaron */
	'\131', /* kCellUpYAcute */
	'\171', /* kCellLoYAcute */
	'\165', /* kCellLoUDblac */
	'\165', /* kCellLoURing */
	'\104', /* kCellUpDStroke */
	'\144', /* kCellLoDStroke */
#endif

	'\0' /* just so last above line can end in ',' */
};
#endif

#ifndef NeedCell2WinAsciiMap
#define NeedCell2WinAsciiMap 0
#endif

#if NeedCell2WinAsciiMap
/* Windows character set (windows-1252 code page) */
LOCALVAR const ui3b Cell2WinAsciiMap[] = {
	0x41, /* kCellUpA */
	0x42, /* kCellUpB */
	0x43, /* kCellUpC */
	0x44, /* kCellUpD */
	0x45, /* kCellUpE */
	0x46, /* kCellUpF */
	0x47, /* kCellUpG */
	0x48, /* kCellUpH */
	0x49, /* kCellUpI */
	0x4A, /* kCellUpJ */
	0x4B, /* kCellUpK */
	0x4C, /* kCellUpL */
	0x4D, /* kCellUpM */
	0x4E, /* kCellUpN */
	0x4F, /* kCellUpO */
	0x50, /* kCellUpP */
	0x51, /* kCellUpQ */
	0x52, /* kCellUpR */
	0x53, /* kCellUpS */
	0x54, /* kCellUpT */
	0x55, /* kCellUpU */
	0x56, /* kCellUpV */
	0x57, /* kCellUpW */
	0x58, /* kCellUpX */
	0x59, /* kCellUpY */
	0x5A, /* kCellUpZ */
	0x61, /* kCellLoA */
	0x62, /* kCellLoB */
	0x63, /* kCellLoC */
	0x64, /* kCellLoD */
	0x65, /* kCellLoE */
	0x66, /* kCellLoF */
	0x67, /* kCellLoG */
	0x68, /* kCellLoH */
	0x69, /* kCellLoI */
	0x6A, /* kCellLoJ */
	0x6B, /* kCellLoK */
	0x6C, /* kCellLoL */
	0x6D, /* kCellLoM */
	0x6E, /* kCellLoN */
	0x6F, /* kCellLoO */
	0x70, /* kCellLoP */
	0x71, /* kCellLoQ */
	0x72, /* kCellLoR */
	0x73, /* kCellLoS */
	0x74, /* kCellLoT */
	0x75, /* kCellLoU */
	0x76, /* kCellLoV */
	0x77, /* kCellLoW */
	0x78, /* kCellLoX */
	0x79, /* kCellLoY */
	0x7A, /* kCellLoZ */
	0x30, /* kCellDigit0 */
	0x31, /* kCellDigit1 */
	0x32, /* kCellDigit2 */
	0x33, /* kCellDigit3 */
	0x34, /* kCellDigit4 */
	0x35, /* kCellDigit5 */
	0x36, /* kCellDigit6 */
	0x37, /* kCellDigit7 */
	0x38, /* kCellDigit8 */
	0x39, /* kCellDigit9 */
	0x21, /* kCellExclamation */
	0x26, /* kCellAmpersand */
	0x27, /* kCellApostrophe */
	0x28, /* kCellLeftParen */
	0x29, /* kCellRightParen */
	0x2C, /* kCellComma */
	0x2D, /* kCellHyphen */
	0x2E, /* kCellPeriod */
	0x2F, /* kCellSlash */
	0x3A, /* kCellColon */
	0x3B, /* kCellSemicolon */
	0x3F, /* kCellQuestion */
	0x85, /* kCellEllipsis */
	0x5F, /* kCellUnderscore */
	0x93, /* kCellLeftDQuote */
	0x94, /* kCellRightDQuote */
	0x91, /* kCellLeftSQuote */
	0x92, /* kCellRightSQuote */
	0xA9, /* kCellCopyright */
	0x20, /* kCellSpace */

#if NeedIntlChars
	0xC4, /* kCellUpADiaeresis */
	0xC5, /* kCellUpARing */
	0xC7, /* kCellUpCCedilla */
	0xC9, /* kCellUpEAcute */
	0xD1, /* kCellUpNTilde */
	0xD6, /* kCellUpODiaeresis */
	0xDC, /* kCellUpUDiaeresis */
	0xE1, /* kCellLoAAcute */
	0xE0, /* kCellLoAGrave */
	0xE2, /* kCellLoACircumflex */
	0xE4, /* kCellLoADiaeresis */
	0xE3, /* kCellLoATilde */
	0xE5, /* kCellLoARing */
	0xE7, /* kCellLoCCedilla */
	0xE9, /* kCellLoEAcute */
	0xE8, /* kCellLoEGrave */
	0xEA, /* kCellLoECircumflex */
	0xEB, /* kCellLoEDiaeresis */
	0xED, /* kCellLoIAcute */
	0xEC, /* kCellLoIGrave */
	0xEE, /* kCellLoICircumflex */
	0xEF, /* kCellLoIDiaeresis */
	0xF1, /* kCellLoNTilde */
	0xF3, /* kCellLoOAcute */
	0xF2, /* kCellLoOGrave */
	0xF4, /* kCellLoOCircumflex */
	0xF6, /* kCellLoODiaeresis */
	0xF5, /* kCellLoOTilde */
	0xFA, /* kCellLoUAcute */
	0xF9, /* kCellLoUGrave */
	0xFB, /* kCellLoUCircumflex */
	0xFC, /* kCellLoUDiaeresis */

	0xC6, /* kCellUpAE */
	0xD8, /* kCellUpOStroke */

	0xE6, /* kCellLoAE */
	0xF8, /* kCellLoOStroke */
	0xBF, /* kCellInvQuestion */
	0xA1, /* kCellInvExclam */

	0xC0, /* kCellUpAGrave */
	0xC3, /* kCellUpATilde */
	0xD5, /* kCellUpOTilde */
	0x8C, /* kCellUpLigatureOE */
	0x9C, /* kCellLoLigatureOE */

	0xFF, /* kCellLoYDiaeresis */
	0x9F, /* kCellUpYDiaeresis */

	0xC2, /* kCellUpACircumflex */
	0xCA, /* kCellUpECircumflex */
	0xC1, /* kCellUpAAcute */
	0xCB, /* kCellUpEDiaeresis */
	0xC8, /* kCellUpEGrave */
	0xCD, /* kCellUpIAcute */
	0xCE, /* kCellUpICircumflex */
	0xCF, /* kCellUpIDiaeresis */
	0xCC, /* kCellUpIGrave */
	0xD3, /* kCellUpOAcute */
	0xD4, /* kCellUpOCircumflex */

	0xD2, /* kCellUpOGrave */
	0xDA, /* kCellUpUAcute */
	0xDB, /* kCellUpUCircumflex */
	0xD9, /* kCellUpUGrave */
	0xDF, /* kCellSharpS */

	0x41, /* kCellUpACedille */
	0x61, /* kCellLoACedille */
	0x43, /* kCellUpCAcute */
	0x63, /* kCellLoCAcute */
	0x45, /* kCellUpECedille */
	0x65, /* kCellLoECedille */
	0x4C, /* kCellUpLBar */
	0x6C, /* kCellLoLBar */
	0x4E, /* kCellUpNAcute */
	0x6E, /* kCellLoNAcute */
	0x53, /* kCellUpSAcute */
	0x73, /* kCellLoSAcute */
	0x5A, /* kCellUpZAcute */
	0x7A, /* kCellLoZAcute */
	0x5A, /* kCellUpZDot */
	0x7A, /* kCellLoZDot */
	0xB7, /* kCellMidDot */
	0x43, /* kCellUpCCaron */
	0x63, /* kCellLoCCaron */
	0x65, /* kCellLoECaron */
	0x61, /* kCellLoRCaron */
	0x9A, /* kCellLoSCaron */
	0x74, /* kCellLoTCaron */
	0x9E, /* kCellLoZCaron */
	0xDD, /* kCellUpYAcute */
	0xFD, /* kCellLoYAcute */
	0x75, /* kCellLoUDblac */
	0x75, /* kCellLoURing */
	0x44, /* kCellUpDStroke */
	0x64, /* kCellLoDStroke */
#endif

	'\0' /* just so last above line can end in ',' */
};
#endif

#ifndef NeedCell2PlainAsciiMap
#define NeedCell2PlainAsciiMap 0
#endif

#if NeedCell2PlainAsciiMap
/* Plain ascii - remove accents when possible */
LOCALVAR const char Cell2PlainAsciiMap[] = {
	'A', /* kCellUpA */
	'B', /* kCellUpB */
	'C', /* kCellUpC */
	'D', /* kCellUpD */
	'E', /* kCellUpE */
	'F', /* kCellUpF */
	'G', /* kCellUpG */
	'H', /* kCellUpH */
	'I', /* kCellUpI */
	'J', /* kCellUpJ */
	'K', /* kCellUpK */
	'L', /* kCellUpL */
	'M', /* kCellUpM */
	'N', /* kCellUpN */
	'O', /* kCellUpO */
	'P', /* kCellUpP */
	'Q', /* kCellUpQ */
	'R', /* kCellUpR */
	'S', /* kCellUpS */
	'T', /* kCellUpT */
	'U', /* kCellUpU */
	'V', /* kCellUpV */
	'W', /* kCellUpW */
	'X', /* kCellUpX */
	'Y', /* kCellUpY */
	'Z', /* kCellUpZ */
	'a', /* kCellLoA */
	'b', /* kCellLoB */
	'c', /* kCellLoC */
	'd', /* kCellLoD */
	'e', /* kCellLoE */
	'f', /* kCellLoF */
	'g', /* kCellLoG */
	'h', /* kCellLoH */
	'i', /* kCellLoI */
	'j', /* kCellLoJ */
	'k', /* kCellLoK */
	'l', /* kCellLoL */
	'm', /* kCellLoM */
	'n', /* kCellLoN */
	'o', /* kCellLoO */
	'p', /* kCellLoP */
	'q', /* kCellLoQ */
	'r', /* kCellLoR */
	's', /* kCellLoS */
	't', /* kCellLoT */
	'u', /* kCellLoU */
	'v', /* kCellLoV */
	'w', /* kCellLoW */
	'x', /* kCellLoX */
	'y', /* kCellLoY */
	'z', /* kCellLoZ */
	'0', /* kCellDigit0 */
	'1', /* kCellDigit1 */
	'2', /* kCellDigit2 */
	'3', /* kCellDigit3 */
	'4', /* kCellDigit4 */
	'5', /* kCellDigit5 */
	'6', /* kCellDigit6 */
	'7', /* kCellDigit7 */
	'8', /* kCellDigit8 */
	'9', /* kCellDigit9 */
	'!', /* kCellExclamation */
	'&', /* kCellAmpersand */
	'\047', /* kCellApostrophe */
	'(', /* kCellLeftParen */
	')', /* kCellRightParen */
	',', /* kCellComma */
	'-', /* kCellHyphen */
	'.', /* kCellPeriod */
	'/', /* kCellSlash */
	':', /* kCellColon */
	';', /* kCellSemicolon */
	'?', /* kCellQuestion */
	'_', /* kCellEllipsis */
	'_', /* kCellUnderscore */
	'"', /* kCellLeftDQuote */
	'"', /* kCellRightDQuote */
	'\047', /* kCellLeftSQuote */
	'\047', /* kCellRightSQuote */
	'c', /* kCellCopyright */
	' ', /* kCellSpace */

#if NeedIntlChars
	'A', /* kCellUpADiaeresis */
	'A', /* kCellUpARing */
	'C', /* kCellUpCCedilla */
	'E', /* kCellUpEAcute */
	'N', /* kCellUpNTilde */
	'O', /* kCellUpODiaeresis */
	'U', /* kCellUpUDiaeresis */
	'a', /* kCellLoAAcute */
	'a', /* kCellLoAGrave */
	'a', /* kCellLoACircumflex */
	'a', /* kCellLoADiaeresis */
	'a', /* kCellLoATilde */
	'a', /* kCellLoARing */
	'c', /* kCellLoCCedilla */
	'e', /* kCellLoEAcute */
	'e', /* kCellLoEGrave */
	'e', /* kCellLoECircumflex */
	'e', /* kCellLoEDiaeresis */
	'i', /* kCellLoIAcute */
	'i', /* kCellLoIGrave */
	'i', /* kCellLoICircumflex */
	'i', /* kCellLoIDiaeresis */
	'n', /* kCellLoNTilde */
	'o', /* kCellLoOAcute */
	'o', /* kCellLoOGrave */
	'o', /* kCellLoOCircumflex */
	'o', /* kCellLoODiaeresis */
	'o', /* kCellLoOTilde */
	'u', /* kCellLoUAcute */
	'u', /* kCellLoUGrave */
	'u', /* kCellLoUCircumflex */
	'u', /* kCellLoUDiaeresis */

	'?', /* kCellUpAE */
	'O', /* kCellUpOStroke */

	'?', /* kCellLoAE */
	'o', /* kCellLoOStroke */
	'?', /* kCellInvQuestion */
	'!', /* kCellInvExclam */

	'A', /* kCellUpAGrave */
	'A', /* kCellUpATilde */
	'O', /* kCellUpOTilde */
	'?', /* kCellUpLigatureOE */
	'?', /* kCellLoLigatureOE */

	'y', /* kCellLoYDiaeresis */
	'Y', /* kCellUpYDiaeresis */

	'A', /* kCellUpACircumflex */
	'E', /* kCellUpECircumflex */
	'A', /* kCellUpAAcute */
	'E', /* kCellUpEDiaeresis */
	'E', /* kCellUpEGrave */
	'A', /* kCellUpIAcute */
	'I', /* kCellUpICircumflex */
	'I', /* kCellUpIDiaeresis */
	'I', /* kCellUpIGrave */
	'O', /* kCellUpOAcute */
	'O', /* kCellUpOCircumflex */

	'O', /* kCellUpOGrave */
	'U', /* kCellUpUAcute */
	'U', /* kCellUpUCircumflex */
	'U', /* kCellUpUGrave */
	'B', /* kCellSharpS */

	'A', /* kCellUpACedille */
	'a', /* kCellLoACedille */
	'C', /* kCellUpCAcute */
	'c', /* kCellLoCAcute */
	'E', /* kCellUpECedille */
	'e', /* kCellLoECedille */
	'L', /* kCellUpLBar */
	'l', /* kCellLoLBar */
	'N', /* kCellUpNAcute */
	'n', /* kCellLoNAcute */
	'S', /* kCellUpSAcute */
	's', /* kCellLoSAcute */
	'Z', /* kCellUpZAcute */
	'z', /* kCellLoZAcute */
	'Z', /* kCellUpZDot */
	'z', /* kCellLoZDot */
	'.', /* kCellMidDot */
	'C', /* kCellUpCCaron */
	'c', /* kCellLoCCaron */
	'e', /* kCellLoECaron */
	'r', /* kCellLoRCaron */
	's', /* kCellLoSCaron */
	't', /* kCellLoTCaron */
	'z', /* kCellLoZCaron */
	'Y', /* kCellUpYAcute */
	'y', /* kCellLoYAcute */
	'u', /* kCellLoUDblac */
	'u', /* kCellLoURing */
	'D', /* kCellUpDStroke */
	'd', /* kCellLoDStroke */
#endif

	'\0' /* just so last above line can end in ',' */
};
#endif

#ifndef NeedCell2UnicodeMap
#define NeedCell2UnicodeMap 0
#endif

#if NeedCell2UnicodeMap
/* Unicode character set */
LOCALVAR const ui4b Cell2UnicodeMap[] = {
	0x0041, /* kCellUpA */
	0x0042, /* kCellUpB */
	0x0043, /* kCellUpC */
	0x0044, /* kCellUpD */
	0x0045, /* kCellUpE */
	0x0046, /* kCellUpF */
	0x0047, /* kCellUpG */
	0x0048, /* kCellUpH */
	0x0049, /* kCellUpI */
	0x004A, /* kCellUpJ */
	0x004B, /* kCellUpK */
	0x004C, /* kCellUpL */
	0x004D, /* kCellUpM */
	0x004E, /* kCellUpN */
	0x004F, /* kCellUpO */
	0x0050, /* kCellUpP */
	0x0051, /* kCellUpQ */
	0x0052, /* kCellUpR */
	0x0053, /* kCellUpS */
	0x0054, /* kCellUpT */
	0x0055, /* kCellUpU */
	0x0056, /* kCellUpV */
	0x0057, /* kCellUpW */
	0x0058, /* kCellUpX */
	0x0059, /* kCellUpY */
	0x005A, /* kCellUpZ */
	0x0061, /* kCellLoA */
	0x0062, /* kCellLoB */
	0x0063, /* kCellLoC */
	0x0064, /* kCellLoD */
	0x0065, /* kCellLoE */
	0x0066, /* kCellLoF */
	0x0067, /* kCellLoG */
	0x0068, /* kCellLoH */
	0x0069, /* kCellLoI */
	0x006A, /* kCellLoJ */
	0x006B, /* kCellLoK */
	0x006C, /* kCellLoL */
	0x006D, /* kCellLoM */
	0x006E, /* kCellLoN */
	0x006F, /* kCellLoO */
	0x0070, /* kCellLoP */
	0x0071, /* kCellLoQ */
	0x0072, /* kCellLoR */
	0x0073, /* kCellLoS */
	0x0074, /* kCellLoT */
	0x0075, /* kCellLoU */
	0x0076, /* kCellLoV */
	0x0077, /* kCellLoW */
	0x0078, /* kCellLoX */
	0x0079, /* kCellLoY */
	0x007A, /* kCellLoZ */
	0x0030, /* kCellDigit0 */
	0x0031, /* kCellDigit1 */
	0x0032, /* kCellDigit2 */
	0x0033, /* kCellDigit3 */
	0x0034, /* kCellDigit4 */
	0x0035, /* kCellDigit5 */
	0x0036, /* kCellDigit6 */
	0x0037, /* kCellDigit7 */
	0x0038, /* kCellDigit8 */
	0x0039, /* kCellDigit9 */
	0x0021, /* kCellExclamation */
	0x0026, /* kCellAmpersand */
	0x0027, /* kCellApostrophe */
	0x0028, /* kCellLeftParen */
	0x0029, /* kCellRightParen */
	0x002C, /* kCellComma */
	0x002D, /* kCellHyphen */
	0x002E, /* kCellPeriod */
	0x002F, /* kCellSlash */
	0x003A, /* kCellColon */
	0x003B, /* kCellSemicolon */
	0x003F, /* kCellQuestion */
	0x2026, /* kCellEllipsis */
	0x005F, /* kCellUnderscore */
	0x201C, /* kCellLeftDQuote */
	0x201D, /* kCellRightDQuote */
	0x2018, /* kCellLeftSQuote */
	0x2019, /* kCellRightSQuote */
	0x00A9, /* kCellCopyright */
	0x0020, /* kCellSpace */

#if NeedIntlChars
	0x00C4, /* kCellUpADiaeresis */
	0x00C5, /* kCellUpARing */
	0x00C7, /* kCellUpCCedilla */
	0x00C9, /* kCellUpEAcute */
	0x00D1, /* kCellUpNTilde */
	0x00D6, /* kCellUpODiaeresis */
	0x00DC, /* kCellUpUDiaeresis */
	0x00E1, /* kCellLoAAcute */
	0x00E0, /* kCellLoAGrave */
	0x00E2, /* kCellLoACircumflex */
	0x00E4, /* kCellLoADiaeresis */
	0x00E3, /* kCellLoATilde */
	0x00E5, /* kCellLoARing */
	0x00E7, /* kCellLoCCedilla */
	0x00E9, /* kCellLoEAcute */
	0x00E8, /* kCellLoEGrave */
	0x00EA, /* kCellLoECircumflex */
	0x00EB, /* kCellLoEDiaeresis */
	0x00ED, /* kCellLoIAcute */
	0x00EC, /* kCellLoIGrave */
	0x00EE, /* kCellLoICircumflex */
	0x00EF, /* kCellLoIDiaeresis */
	0x00F1, /* kCellLoNTilde */
	0x00F3, /* kCellLoOAcute */
	0x00F2, /* kCellLoOGrave */
	0x00F4, /* kCellLoOCircumflex */
	0x00F6, /* kCellLoODiaeresis */
	0x00F5, /* kCellLoOTilde */
	0x00FA, /* kCellLoUAcute */
	0x00F9, /* kCellLoUGrave */
	0x00FB, /* kCellLoUCircumflex */
	0x00FC, /* kCellLoUDiaeresis */

	0x00C6, /* kCellUpAE */
	0x00D8, /* kCellUpOStroke */

	0x00E6, /* kCellLoAE */
	0x00F8, /* kCellLoOStroke */
	0x00BF, /* kCellInvQuestion */
	0x00A1, /* kCellInvExclam */

	0x00C0, /* kCellUpAGrave */
	0x00C3, /* kCellUpATilde */
	0x00D5, /* kCellUpOTilde */
	0x0152, /* kCellUpLigatureOE */
	0x0153, /* kCellLoLigatureOE */

	0x00FF, /* kCellLoYDiaeresis */
	0x0178, /* kCellUpYDiaeresis */

	0x00C2, /* kCellUpACircumflex */
	0x00CA, /* kCellUpECircumflex */
	0x00C1, /* kCellUpAAcute */
	0x00CB, /* kCellUpEDiaeresis */
	0x00C8, /* kCellUpEGrave */
	0x00CD, /* kCellUpIAcute */
	0x00CE, /* kCellUpICircumflex */
	0x00CF, /* kCellUpIDiaeresis */
	0x00CC, /* kCellUpIGrave */
	0x00D3, /* kCellUpOAcute */
	0x00D4, /* kCellUpOCircumflex */

	0x00D2, /* kCellUpOGrave */
	0x00DA, /* kCellUpUAcute */
	0x00DB, /* kCellUpUCircumflex */
	0x00D9, /* kCellUpUGrave */
	0x00DF, /* kCellSharpS */

	0x0104, /* kCellUpACedille */
	0x0105, /* kCellLoACedille */
	0x0106, /* kCellUpCAcute */
	0x0107, /* kCellLoCAcute */
	0x0118, /* kCellUpECedille */
	0x0119, /* kCellLoECedille */
	0x0141, /* kCellUpLBar */
	0x0142, /* kCellLoLBar */
	0x0143, /* kCellUpNAcute */
	0x0144, /* kCellLoNAcute */
	0x015A, /* kCellUpSAcute */
	0x015B, /* kCellLoSAcute */
	0x0179, /* kCellUpZAcute */
	0x017A, /* kCellLoZAcute */
	0x017B, /* kCellUpZDot */
	0x017C, /* kCellLoZDot */
	0x00B7, /* kCellMidDot */
	0x010C, /* kCellUpCCaron */
	0x010D, /* kCellLoCCaron */
	0x011B, /* kCellLoECaron */
	0x0159, /* kCellLoRCaron */
	0x0161, /* kCellLoSCaron */
	0x0165, /* kCellLoTCaron */
	0x017E, /* kCellLoZCaron */
	0x00DD, /* kCellUpYAcute */
	0x00FD, /* kCellLoYAcute */
	0x0171, /* kCellLoUDblac */
	0x016F, /* kCellLoURing */
	0x0110, /* kCellUpDStroke */
	0x0111, /* kCellLoDStroke */
#endif

	'\0' /* just so last above line can end in ',' */
};
#endif

LOCALVAR blnr SpeedStopped = falseblnr;

LOCALVAR blnr RunInBackground = (WantInitRunInBackground != 0);

#if VarFullScreen
LOCALVAR blnr WantFullScreen = (WantInitFullScreen != 0);
#endif

#if EnableMagnify
LOCALVAR blnr WantMagnify = (WantInitMagnify != 0);
#endif

#ifndef NeedRequestInsertDisk
#define NeedRequestInsertDisk 0
#endif

#if NeedRequestInsertDisk
LOCALVAR blnr RequestInsertDisk = falseblnr;
#endif

LOCALFUNC char * GetSubstitutionStr(char x)
{
	char *s;

	switch (x) {
		case 'w':
			s = kStrHomePage;
			break;
		case 'y':
			s = kStrCopyrightYear;
			break;
		case 'p':
			s = kStrAppName;
			break;
		case 'v':
			s = kAppVariationStr;
			break;
		case 'r':
			s = RomFileName;
			break;
		default:
			s = "???";
			break;
	}
	return s;
}

LOCALFUNC int ClStrSizeSubstCStr(char *s)
{
	/* must match ClStrAppendSubstCStr ! */

	char *p = s;
	char c;
	int L = 0;

	while (0 != (c = *p++)) {
		if ('^' == c) {
			if (0 == (c = *p++)) {
				goto l_exit; /* oops, unexpected end of string, abort */
			} else if ('^' == c) {
				++L;
			} else {
				L += ClStrSizeSubstCStr(GetSubstitutionStr(c));
			}
		} else if (';' == c) {
			if (0 == (c = *p++)) {
				goto l_exit; /* oops, unexpected end of string, abort */
			}

			switch (c) {
				case 'l':
#if NeedIntlChars
				case '`':
				case 'd':
				case 'e':
				case 'i':
				case 'n':
				case 'u':
				case 'v':
				case 'E':
				case 'r':
#endif
					if (0 == (c = *p++)) {
						/* oops, unexpected end of string, abort */
						goto l_exit;
					}
					(void) c; /* not needed for computing size */
					break;
				default:
					break;
			}
			++L;
		} else {
			++L;
		}
	}

l_exit:
	return L;
}

LOCALPROC ClStrAppendChar(int *L0, ui3b *r, ui3b c)
{
	int L = *L0;

	r[L] = c;
	L++;
	*L0 = L;
}

LOCALPROC ClStrAppendSubstCStr(int *L, ui3b *r, char *s)
{
	/* must match ClStrSizeSubstCStr ! */

	char *p = s;
	char c;
	ui3b x;

	while (0 != (c = *p++)) {
		if ('^' == c) {
			if (0 == (c = *p++)) {
				return; /* oops, unexpected end of string, abort */
			} else if ('^' == c) {
				ClStrAppendChar(L, r, c);
			} else {
				ClStrAppendSubstCStr(L, r, GetSubstitutionStr(c));
			}
		} else if (';' == c) {
			if (0 == (c = *p++)) {
				return; /* oops, unexpected end of string, abort */
			}

			switch (c) {
				case 'g': x = kCellCopyright; break;
				case 'l':
					if (0 == (c = *p++)) {
						/* oops, unexpected end of string, abort */
						return;
					}

					switch (c) {
						case 'a': x = kCellApostrophe; break;
						case 'l': x = kCellEllipsis; break;
						case 's': x = kCellSemicolon; break;
#if NeedIntlChars
						case 'E': x = kCellUpAE; break;
						case 'e': x = kCellLoAE; break;
						case '.': x = kCellMidDot; break;
#endif
						default: x = kCellQuestion; break;
					}
					break;
				case '[': x = kCellLeftDQuote; break;
				case '{': x = kCellRightDQuote; break;
				case ']': x = kCellLeftSQuote; break;
				case '}': x = kCellRightSQuote; break;
#if NeedIntlChars
				case '?': x = kCellInvQuestion; break;
				case 'A': x = kCellUpARing; break;
				case 'C': x = kCellUpCCedilla; break;
				case 'O': x = kCellUpOStroke; break;
				case 'Q': x = kCellUpLigatureOE; break;
				case '`':
					if (0 == (c = *p++)) {
						/* oops, unexpected end of string, abort */
						return;
					}

					switch (c) {
						case 'A': x = kCellUpAGrave; break;
						case 'E': x = kCellUpEGrave; break;
						case 'I': x = kCellUpIGrave; break;
						case 'O': x = kCellUpOGrave; break;
						case 'U': x = kCellUpUGrave; break;
						case 'a': x = kCellLoAGrave; break;
						case 'e': x = kCellLoEGrave; break;
						case 'i': x = kCellLoIGrave; break;
						case 'o': x = kCellLoOGrave; break;
						case 'u': x = kCellLoUGrave; break;
						default: x = kCellQuestion; break;
					}
					break;
				case 'a': x = kCellLoARing; break;
				case 'c': x = kCellLoCCedilla; break;
				case 'd':
					if (0 == (c = *p++)) {
						/* oops, unexpected end of string, abort */
						return;
					}

					switch (c) {
						case 'A': x = kCellUpACedille; break;
						case 'a': x = kCellLoACedille; break;
						case 'D': x = kCellUpDStroke; break;
						case 'd': x = kCellLoDStroke; break;
						case 'E': x = kCellUpECedille; break;
						case 'e': x = kCellLoECedille; break;
						case 'L': x = kCellUpLBar; break;
						case 'l': x = kCellLoLBar; break;
						case 'Z': x = kCellUpZDot; break;
						case 'z': x = kCellLoZDot; break;
						default: x = kCellQuestion; break;
					}
					break;
				case 'e':
					if (0 == (c = *p++)) {
						/* oops, unexpected end of string, abort */
						return;
					}

					switch (c) {
						case 'A': x = kCellUpAAcute; break;
						case 'E': x = kCellUpEAcute; break;
						case 'I': x = kCellUpIAcute; break;
						case 'O': x = kCellUpOAcute; break;
						case 'U': x = kCellUpUAcute; break;
						case 'a': x = kCellLoAAcute; break;
						case 'e': x = kCellLoEAcute; break;
						case 'i': x = kCellLoIAcute; break;
						case 'o': x = kCellLoOAcute; break;
						case 'u': x = kCellLoUAcute; break;

						case 'C': x = kCellUpCAcute; break;
						case 'c': x = kCellLoCAcute; break;
						case 'N': x = kCellUpNAcute; break;
						case 'n': x = kCellLoNAcute; break;
						case 'S': x = kCellUpSAcute; break;
						case 's': x = kCellLoSAcute; break;
						case 'Z': x = kCellUpZAcute; break;
						case 'z': x = kCellLoZAcute; break;
						case 'Y': x = kCellUpYAcute; break;
						case 'y': x = kCellLoYAcute; break;

						default: x = kCellQuestion; break;
					}
					break;
				case 'i':
					if (0 == (c = *p++)) {
						/* oops, unexpected end of string, abort */
						return;
					}

					switch (c) {
						case 'A': x = kCellUpACircumflex; break;
						case 'E': x = kCellUpECircumflex; break;
						case 'I': x = kCellUpICircumflex; break;
						case 'O': x = kCellUpOCircumflex; break;
						case 'U': x = kCellUpUCircumflex; break;
						case 'a': x = kCellLoACircumflex; break;
						case 'e': x = kCellLoECircumflex; break;
						case 'i': x = kCellLoICircumflex; break;
						case 'o': x = kCellLoOCircumflex; break;
						case 'u': x = kCellLoUCircumflex; break;
						default: x = kCellQuestion; break;
					}
					break;
				case 'n':
					if (0 == (c = *p++)) {
						/* oops, unexpected end of string, abort */
						return;
					}

					switch (c) {
						case 'A': x = kCellUpATilde; break;
						case 'N': x = kCellUpNTilde; break;
						case 'O': x = kCellUpOTilde; break;
						case 'a': x = kCellLoATilde; break;
						case 'n': x = kCellLoNTilde; break;
						case 'o': x = kCellLoOTilde; break;
						default: x = kCellQuestion; break;
					}
					break;
				case 'o': x = kCellLoOStroke; break;
				case 'q': x = kCellLoLigatureOE; break;
				case 's': x = kCellSharpS; break;
				case 'u':
					if (0 == (c = *p++)) {
						/* oops, unexpected end of string, abort */
						return;
					}

					switch (c) {
						case 'A': x = kCellUpADiaeresis; break;
						case 'E': x = kCellUpEDiaeresis; break;
						case 'I': x = kCellUpIDiaeresis; break;
						case 'O': x = kCellUpODiaeresis; break;
						case 'U': x = kCellUpUDiaeresis; break;
						case 'Y': x = kCellUpYDiaeresis; break;
						case 'a': x = kCellLoADiaeresis; break;
						case 'e': x = kCellLoEDiaeresis; break;
						case 'i': x = kCellLoIDiaeresis; break;
						case 'o': x = kCellLoODiaeresis; break;
						case 'u': x = kCellLoUDiaeresis; break;
						case 'y': x = kCellLoYDiaeresis; break;
						default: x = kCellQuestion; break;
					}
					break;
				case 'v':
					if (0 == (c = *p++)) {
						/* oops, unexpected end of string, abort */
						return;
					}

					switch (c) {
						case 'C': x = kCellUpCCaron; break;
						case 'c': x = kCellLoCCaron; break;
						case 'e': x = kCellLoECaron; break;
						case 'r': x = kCellLoRCaron; break;
						case 's': x = kCellLoSCaron; break;
						case 't': x = kCellLoTCaron; break;
						case 'z': x = kCellLoZCaron; break;
						default: x = kCellQuestion; break;
					}
					break;
				case 'E':
					if (0 == (c = *p++)) {
						/* oops, unexpected end of string, abort */
						return;
					}

					switch (c) {
						case 'u': x = kCellLoUDblac; break;
						default: x = kCellQuestion; break;
					}
					break;
				case 'r':
					if (0 == (c = *p++)) {
						/* oops, unexpected end of string, abort */
						return;
					}

					switch (c) {
						case 'u': x = kCellLoURing; break;
						default: x = kCellQuestion; break;
					}
					break;
#endif
				default: x = kCellQuestion; break;
			}
			ClStrAppendChar(L, r, x);
		} else {
			switch (c) {
				case 'A': x = kCellUpA; break;
				case 'B': x = kCellUpB; break;
				case 'C': x = kCellUpC; break;
				case 'D': x = kCellUpD; break;
				case 'E': x = kCellUpE; break;
				case 'F': x = kCellUpF; break;
				case 'G': x = kCellUpG; break;
				case 'H': x = kCellUpH; break;
				case 'I': x = kCellUpI; break;
				case 'J': x = kCellUpJ; break;
				case 'K': x = kCellUpK; break;
				case 'L': x = kCellUpL; break;
				case 'M': x = kCellUpM; break;
				case 'N': x = kCellUpN; break;
				case 'O': x = kCellUpO; break;
				case 'P': x = kCellUpP; break;
				case 'Q': x = kCellUpQ; break;
				case 'R': x = kCellUpR; break;
				case 'S': x = kCellUpS; break;
				case 'T': x = kCellUpT; break;
				case 'U': x = kCellUpU; break;
				case 'V': x = kCellUpV; break;
				case 'W': x = kCellUpW; break;
				case 'X': x = kCellUpX; break;
				case 'Y': x = kCellUpY; break;
				case 'Z': x = kCellUpZ; break;
				case 'a': x = kCellLoA; break;
				case 'b': x = kCellLoB; break;
				case 'c': x = kCellLoC; break;
				case 'd': x = kCellLoD; break;
				case 'e': x = kCellLoE; break;
				case 'f': x = kCellLoF; break;
				case 'g': x = kCellLoG; break;
				case 'h': x = kCellLoH; break;
				case 'i': x = kCellLoI; break;
				case 'j': x = kCellLoJ; break;
				case 'k': x = kCellLoK; break;
				case 'l': x = kCellLoL; break;
				case 'm': x = kCellLoM; break;
				case 'n': x = kCellLoN; break;
				case 'o': x = kCellLoO; break;
				case 'p': x = kCellLoP; break;
				case 'q': x = kCellLoQ; break;
				case 'r': x = kCellLoR; break;
				case 's': x = kCellLoS; break;
				case 't': x = kCellLoT; break;
				case 'u': x = kCellLoU; break;
				case 'v': x = kCellLoV; break;
				case 'w': x = kCellLoW; break;
				case 'x': x = kCellLoX; break;
				case 'y': x = kCellLoY; break;
				case 'z': x = kCellLoZ; break;
				case '0': x = kCellDigit0; break;
				case '1': x = kCellDigit1; break;
				case '2': x = kCellDigit2; break;
				case '3': x = kCellDigit3; break;
				case '4': x = kCellDigit4; break;
				case '5': x = kCellDigit5; break;
				case '6': x = kCellDigit6; break;
				case '7': x = kCellDigit7; break;
				case '8': x = kCellDigit8; break;
				case '9': x = kCellDigit9; break;
				case '!': x = kCellExclamation; break;
				case '&': x = kCellAmpersand; break;
				case '(': x = kCellLeftParen; break;
				case ')': x = kCellRightParen; break;
				case ',': x = kCellComma; break;
				case '-': x = kCellHyphen; break;
				case '.': x = kCellPeriod; break;
				case '/': x = kCellSlash; break;
				case ':': x = kCellColon; break;
				case ';': x = kCellSemicolon; break;
				case '?': x = kCellQuestion; break;
				case '_': x = kCellUnderscore; break;
				case ' ': x = kCellSpace; break;
				case '\047': x = kCellApostrophe; break;

				default: x = kCellQuestion; break;
			}
			ClStrAppendChar(L, r, x);
		}
	}
}

#define ClStrMaxLength 512

LOCALPROC ClStrFromSubstCStr(int *L, ui3b *r, char *s)
{
	int n = ClStrSizeSubstCStr(s);

	*L = 0;
	if (n <= ClStrMaxLength) {
		ClStrAppendSubstCStr(L, r, s);

		if (n != *L) {
			/* try to ensure mismatch is noticed */
			*L = 0;
		}
	}
}
