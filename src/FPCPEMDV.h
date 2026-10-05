/*
	FPCPEMDV.h

	Copyright (C) 2007 Ross Martin, Paul C. Pratt

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
	Floating Point CoProcessor Emulated Device
	(included by MINEM68K.c)
*/

/*
	ReportAbnormalID unused 0x0306 - 0x03FF
*/


LOCALVAR struct fpustruct
{
	myfpr fp[8];
	CPTR FPIAR; /* Floating point instruction address register */
	int ExcPending;
		/*
			vector of an enabled exception raised by an earlier
			instruction, not yet cleared by FSAVE, or 0
		*/
	CPTR CurInstAddr; /* address of the current operation */
	blnr SNaNOperand; /* current operation has a signaling NaN */
	ui5r ExtraEXC; /* EXC bits not from softfloat (INEX1) */
} fpu_dat;

LOCALPROC myfp_SetFPIAR(ui5r v)
{
	fpu_dat.FPIAR = v;
}

LOCALFUNC ui5r myfp_GetFPIAR(void)
{
	return fpu_dat.FPIAR;
}

/*
	Hardware reset of the 68881, also done by FRESTORE of a null
	state frame: FPCR, FPSR and FPIAR are cleared and the data
	registers are loaded with nonsignaling NaNs (MC68881UM 5.?,
	M68000PRM FRESTORE).
*/
LOCALPROC FPU_Reset(void)
{
	int i;

	for (i = 0; i < 8; ++i) {
		fpu_dat.fp[i].high = 0x7FFF;
		fpu_dat.fp[i].low = LIT64(0xFFFFFFFFFFFFFFFF);
	}
	fpu_dat.FPIAR = 0;
	fpu_dat.ExcPending = 0;
	myfp_Reset();
}

/*
	The 68881 reports an enabled exception from an earlier
	instruction when the next coprocessor instruction (other than
	FSAVE or FRESTORE) starts: a pre-instruction exception, format
	$0 frame, whose PC is the new instruction so that it is
	restarted after the handler (MC68881UM 6.?, MC68020UM 10.?).
	The exception stays pending until FSAVE, which handlers must
	execute first; they clear it by setting bit 27 of the saved
	BIU flags before FRESTORE.
	Called before anything past the opcode word has been fetched.
*/
LOCALFUNC blnr FPU_TookPendingException(void)
{
	if (0 == fpu_dat.ExcPending) {
		return falseblnr;
	}

	BackupPC();
	Exception(fpu_dat.ExcPending);
	return trueblnr;
}

/*
	Start of an operation that can raise floating point
	exceptions. Called right after the command word is fetched.
*/
LOCALPROC FPU_BeginOp(void)
{
	fpu_dat.CurInstAddr = m68k_getpc() - 4;
	fpu_dat.SNaNOperand = falseblnr;
	fpu_dat.ExtraEXC = 0;
	float_exception_flags = 0;
}

/*
	End of such an operation: replace the FPSR EXC byte with
	this operation's exceptions, update AEXC, load FPIAR, and
	make an enabled exception pending. Returns trueblnr if the
	destination must be left unmodified, which the 68881 does
	when the SNAN, OPERR or DZ trap is enabled (M68000PRM 1.6.?);
	for the other exceptions the result is stored as usual.
*/
LOCALFUNC blnr FPU_FinishOp(void)
{
	ui5r exc;
	int vec;

	if (fpu_dat.SNaNOperand) {
		float_raise(float_flag_invalid);
	}
	exc = myfp_FlagsToEXC(fpu_dat.SNaNOperand) | fpu_dat.ExtraEXC;
	myfp_ClearExceptions();
	myfp_SetEXC(exc);
	myfp_SetFPIAR(fpu_dat.CurInstAddr);

	vec = myfp_EnabledExcVector();
	if (0 != vec) {
		fpu_dat.ExcPending = vec;
	}

	return 0 != (exc & myfp_GetFPCR()
		& (myfp_EXC_SNAN | myfp_EXC_OPERR | myfp_EXC_DZ));
}

/* quieted copy of x, as stored when the SNAN trap is disabled */
LOCALPROC FPU_Quiet(myfpr *r, myfpr *x)
{
	*r = *x;
	if (floatx80_is_signaling_nan(*r)) {
		r->low |= LIT64(0x4000000000000000);
	}
}

LOCALFUNC blnr DecodeAddrModeRegister(ui5b sz)
{
	ui4r Dat = V_regs.CurDecOpY.v[0].ArgDat;
	ui4r themode = (Dat >> 3) & 7;
	ui4r thereg = Dat & 7;

	switch (themode) {
		case 2 :
		case 3 :
		case 4 :
		case 5 :
		case 6 :
			return DecodeModeRegister(sz);
			break;
		case 7 :
			switch (thereg) {
				case 0 :
				case 1 :
				case 2 :
				case 3 :
				case 4 :
					return DecodeModeRegister(sz);
					break;
				default :
					return falseblnr;
					break;
			}
			break;
		default :
			return falseblnr;
			break;
	}
}

LOCALPROC read_long_double(ui5r addr, myfpr *r)
{
	ui4r v2;
	ui5r v1;
	ui5r v0;

	v2 = get_word(addr + 0);
	/* ignore word at offset 2 */
	v1 = get_long(addr + 4);
	v0 = get_long(addr + 8);

	myfp_FromExtendedFormat(r, v2, v1, v0);
}

LOCALPROC write_long_double(ui5r addr, myfpr *xx)
{
	ui4r v2;
	ui5r v1;
	ui5r v0;

	myfp_ToExtendedFormat(xx, &v2, &v1, &v0);

	put_word(addr + 0, v2);
	put_word(addr + 2,  0);
	put_long(addr + 4, v1);
	put_long(addr + 8, v0);
}

#if 0
LOCALPROC read_double(ui5r addr, myfpr *r)
{
	ui5r v1;
	ui5r v0;

	v1 = get_long(addr + 0);
	v0 = get_long(addr + 4);

	myfp_FromDoubleFormat(r, v1, v0);
}

LOCALPROC write_double(ui5r addr, myfpr *dd)
{
	ui5r v1;
	ui5r v0;

	myfp_ToDoubleFormat(dd, &v1, &v0);

	put_long(addr + 0, v1);
	put_long(addr + 4, v0);
}
#endif

#if 0
LOCALPROC read_single(ui5r addr, myfpr *r)
{
	myfp_FromSingleFormat(r, get_long(addr));
}

LOCALPROC write_single(ui5r addr, myfpr *ff)
{
	put_long(addr, myfp_ToSingleFormat(ff));
}
#endif


LOCALFUNC int CheckFPCondition(ui4b predicate)
{
	int condition_true = 0;

	ui3r cc = myfp_GetConditionCodeByte();

	int c_nan  = (cc) & 1;
	/* int c_inf  = (cc >> 1) & 1; */
	int c_zero = (cc >> 2) & 1;
	int c_neg  = (cc >> 3) & 1;

	/*
		printf(
			"FPSR Checked: c_nan=%d, c_zero=%d, c_neg=%d,"
			" predicate=0x%04x\n",
			c_nan, c_zero, c_neg, predicate);
	*/

	switch (predicate) {
		case 0x11: /* SEQ */
		case 0x01: /* EQ */
			condition_true = c_zero;
			break;
		case 0x1E: /* SNE */
		case 0x0E: /* NE */
			condition_true = ! c_zero;
			break;
		case 0x02: /* OGT */
		case 0x12: /* GT */
			condition_true = (! c_neg) && (! c_zero) && (! c_nan);
			break;
		case 0x0D: /* ULE */
		case 0x1D: /* NGT */
			condition_true = c_neg || c_zero || c_nan;
			break;
		case 0x03: /* OGE */
		case 0x13: /* GE */
			condition_true = c_zero || ((! c_neg) && (! c_nan));
			break;
		case 0x0C: /* ULT */
		case 0x1C: /* NGE */
			condition_true = c_nan || ((! c_zero) && c_neg) ;
			break;
		case 0x04: /* OLT */
		case 0x14: /* LT */
			condition_true = c_neg && (! c_nan) && (! c_zero);
			break;
		case 0x0B: /* UGE */
		case 0x1B: /* NLT */
			condition_true = c_nan || c_zero || (! c_neg);
			break;
		case 0x05: /* OLE */
		case 0x15: /* LE */
			condition_true = ((! c_nan) && c_neg) || c_zero;
			break;
		case 0x0A: /* UGT */
		case 0x1A: /* NLE */
			condition_true = c_nan || ((! c_neg) && (! c_zero));
			break;
		case 0x06: /* OGL */
		case 0x16: /* GL */
			condition_true = (! c_nan) && (! c_zero);
			break;
		case 0x09: /* UEQ */
		case 0x19: /* NGL */
			condition_true = c_nan || c_zero;
			break;
		case 0x07: /* OR */
		case 0x17: /* GLE */
			condition_true = ! c_nan;
			break;
		case 0x08: /* NGLE */
		case 0x18: /* NGLE */
			condition_true = c_nan;
			break;
		case 0x00: /* SFALSE */
		case 0x10: /* FALSE */
			condition_true = 0;
			break;
		case 0x0F: /* STRUE */
		case 0x1F: /* TRUE */
			condition_true = 1;
			break;
	}

	/* printf("condition_true=%d\n", condition_true); */

	return condition_true;
}

/*
	Evaluate a conditional predicate for FBcc, FDBcc, FScc and
	FTRAPcc. The IEEE nonaware predicates ($10..$1F) set BSUN
	(and so IOP) when NAN is set (M68000PRM 3.6.? and 1.6.4.?).
	If BSUN is enabled the exception is taken at once, with the
	PC at the conditional instruction so it is retried after the
	handler. nExt is the number of bytes fetched past the opcode.
	Returns -1 if that happened, else the condition.
*/
LOCALFUNC int FPU_CheckCondition(ui4b predicate, ui5r nExt)
{
	if ((0x10 == (predicate & 0x30))
		&& (0 != (myfp_GetConditionCodeByte() & 0x01)))
	{
		myfp_SetEXC(myfp_EXC_BSUN);
		if (0 != (myfp_GetFPCR() & myfp_EXC_BSUN)) {
			m68k_setpc(m68k_getpc() - 2 - nExt);
			Exception(48);
			return -1;
		}
	}

	return CheckFPCondition(predicate);
}

LOCALIPROC DoCodeFPU_dflt(void)
{
	ReportAbnormalID(0x0301,
		"unimplemented Floating Point Instruction");
#if dbglog_HAVE
	{
		ui4r opcode = ((ui4r)(V_regs.CurDecOpY.v[0].AMd) << 8)
			| V_regs.CurDecOpY.v[0].ArgDat;

		dbglog_writelnNum("opcode", opcode);
	}
#endif
	DoCodeFdefault();
}

LOCALIPROC DoCodeFPU_Save(void)
{
	ui4r opcode = ((ui4r)(V_regs.CurDecOpY.v[0].AMd) << 8)
		| V_regs.CurDecOpY.v[0].ArgDat;
	if ((opcode == 0xF327) || (opcode == 0xF32D)) {
#if 0
		DecodeModeRegister(4);
		SetArgValueL(0); /* for now, try null state frame */
#endif
		/* 28 byte 68881 IDLE frame */

		if (! DecodeAddrModeRegister(28)) {
			DoCodeFPU_dflt();
#if dbglog_HAVE
			dbglog_writeln(
				"DecodeAddrModeRegister fails in DoCodeFPU_Save");
#endif
		} else {
			put_long(V_regs.ArgAddr.mem, 0x1f180000);
			put_long(V_regs.ArgAddr.mem + 4, 0);
			put_long(V_regs.ArgAddr.mem + 8, 0);
			put_long(V_regs.ArgAddr.mem + 12, 0);
			put_long(V_regs.ArgAddr.mem + 16, 0);
			put_long(V_regs.ArgAddr.mem + 20, 0);
			/*
				BIU flags: bit 27 clear means an exception is
				pending (handlers set it to clear the exception).
				FSAVE takes the pending exception out of the FPU.
			*/
			put_long(V_regs.ArgAddr.mem + 24,
				(0 != fpu_dat.ExcPending) ? 0x70000000 : 0x78000000);
			fpu_dat.ExcPending = 0;
		}

	} else {
		DoCodeFPU_dflt();
#if dbglog_HAVE
		dbglog_writeln("unimplemented FPU Save");
#endif
	}
}

LOCALIPROC DoCodeFPU_Restore(void)
{
	ui4r opcode = ((ui4r)(V_regs.CurDecOpY.v[0].AMd) << 8)
		| V_regs.CurDecOpY.v[0].ArgDat;
	ui4r themode = (opcode >> 3) & 7;
	ui4r thereg = opcode & 7;
	if ((opcode == 0xF35F) || (opcode == 0xF36D)) {
		ui5r dstvalue;

		if (! DecodeAddrModeRegister(4)) {
			DoCodeFPU_dflt();
#if dbglog_HAVE
			dbglog_writeln(
				"DecodeAddrModeRegister fails in DoCodeFPU_Restore");
#endif
		} else {
			dstvalue = get_long(V_regs.ArgAddr.mem);
			if (dstvalue == 0) {
				/* null state frame resets the FPU */
				FPU_Reset();
			} else {
				if (0x1f180000 == dstvalue) {
					ui5r biu = get_long(V_regs.ArgAddr.mem + 24);

					if (3 == themode) {
						m68k_areg(thereg) = V_regs.ArgAddr.mem + 28;
					}
					/*
						bit 27 clear: exception pending. Only the
						FPSR/FPCR bits are kept, so derive which.
					*/
					fpu_dat.ExcPending = (0 == (biu & 0x08000000))
						? myfp_EnabledExcVector() : 0;
				} else {
					DoCodeFPU_dflt();
#if dbglog_HAVE
					dbglog_writeln("unknown restore");
						/* not a null state we saved */
#endif
				}
			}
		}
	} else {
		DoCodeFPU_dflt();
#if dbglog_HAVE
		dbglog_writeln("unimplemented FPU Restore");
#endif
	}
}

LOCALIPROC DoCodeFPU_FBccW(void)
{
	/*
		Also get here for a NOP instruction (opcode 0xF280),
		which is simply a FBF.w with offset 0
	*/
	ui4r Dat = V_regs.CurDecOpY.v[0].ArgDat;
	int cond;

	if (FPU_TookPendingException()) {
		return;
	}
	cond = FPU_CheckCondition(Dat & 0x3F, 0);
	if (cond < 0) {
		/* took BSUN exception */
	} else if (cond) {
		DoCodeBraW();
	} else {
		SkipiWord();
	}

	/* printf("pc_p set to 0x%p in FBcc (32bit)\n", V_pc_p); */
}

LOCALIPROC DoCodeFPU_FBccL(void)
{
	ui4r Dat = V_regs.CurDecOpY.v[0].ArgDat;
	int cond;

	if (FPU_TookPendingException()) {
		return;
	}
	cond = FPU_CheckCondition(Dat & 0x3F, 0);
	if (cond < 0) {
		/* took BSUN exception */
	} else if (cond) {
		DoCodeBraL();
	} else {
		SkipiLong();
	}
}

LOCALIPROC DoCodeFPU_DBcc(void)
{
	ui4r Dat = V_regs.CurDecOpY.v[0].ArgDat;
	ui4r thereg = Dat & 7;
	ui4b word2;
	int condition_true;

	if (FPU_TookPendingException()) {
		return;
	}
	word2 = (int)nextiword();
	condition_true = FPU_CheckCondition(word2 & 0x3F, 2);

	if (condition_true < 0) {
		/* took BSUN exception */
	} else if (! condition_true) {
		ui5b fdb_count = ui5r_FromSWord(m68k_dreg(thereg)) - 1;

		m68k_dreg(thereg) =
			(m68k_dreg(thereg) & ~ 0xFFFF) | (fdb_count & 0xFFFF);
		if ((si5b)fdb_count == -1) {
			SkipiWord();
		} else {
			DoCodeBraW();
		}
	} else {
		SkipiWord();
	}
}

LOCALIPROC DoCodeFPU_Trapcc(void)
{
	ui4r Dat = V_regs.CurDecOpY.v[0].ArgDat;
	ui4r thereg = Dat & 7;
	ui4b word2;
	int condition_true;
	ui5r nExt = 2;

	if (FPU_TookPendingException()) {
		return;
	}
	word2 = (int)nextiword();
	condition_true = FPU_CheckCondition(word2 & 0x3F, 2);
	if (condition_true < 0) {
		return; /* took BSUN exception */
	}

	if (thereg == 2) {
		(void) nextiword();
		nExt += 2;
	} else if (thereg == 3) {
		(void) nextilong();
		nExt += 4;
	} else if (thereg == 4) {
	} else {
		ReportAbnormalID(0x0302, "Invalid FTRAPcc (?");
	}

	if (condition_true) {
		ReportAbnormalID(0x0303, "FTRAPcc trapping");
		ExceptionFmt2(7, CurInstAddr(nExt));
	}
}

LOCALIPROC DoCodeFPU_Scc(void)
{
	ui4b word2;
	int cond;

	if (FPU_TookPendingException()) {
		return;
	}
	word2 = (int)nextiword();
	cond = FPU_CheckCondition(word2 & 0x3F, 2);
	if (cond < 0) {
		/* took BSUN exception */
	} else if (! DecodeModeRegister(1)) {
		DoCodeFPU_dflt();
#if dbglog_HAVE
		dbglog_writeln("bad mode/reg in DoCodeFPU_Scc");
#endif
	} else {
		if (cond) {
			SetArgValueB(0xFFFF);
		} else {
			SetArgValueB(0x0000);
		}
	}
}

LOCALPROC DoCodeF_InvalidPlusWord(void)
{
	BackupPC();
	DoCodeFPU_dflt();
}

LOCALFUNC int CountCSIAlist(ui4b word2)
{
	ui4b regselect = (word2 >> 10) & 0x7;
	int num = 0;

	if (regselect & 1) {
		num++;
	}
	if (regselect & 2) {
		num++;
	}
	if (regselect & 4) {
		num++;
	}

	return num;
}

LOCALPROC DoCodeFPU_Move_EA_CSIA(ui4b word2)
{
	int n;
	ui5b ea_value[3];
	ui4b regselect = (word2 >> 10) & 0x7;
	int num = CountCSIAlist(word2);

	if (regselect == 0) {
		DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
		dbglog_writeln("Invalid FMOVE instruction");
#endif
		return;
	}

	/* FMOVEM.L <EA>, <FP CR,SR,IAR list> */

	if (! DecodeModeRegister(4 * num)) {
		DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
		dbglog_writeln("bad mode/reg in DoCodeFPU_Move_EA_CSIA");
#endif
	} else {
		ea_value[0] = GetArgValueL();
		if (num > 1) {
			ea_value[1] = get_long(V_regs.ArgAddr.mem + 4);
		}
		if (num > 2) {
			ea_value[2] = get_long(V_regs.ArgAddr.mem + 8);
		}

		n = 0;
		if (regselect & (1 << 2)) {
			myfp_SetFPCR(ea_value[n++]);
		}
		if (regselect & (1 << 1)) {
			myfp_SetFPSR(ea_value[n++]);
		}
		if (regselect & (1 << 0)) {
			myfp_SetFPIAR(ea_value[n++]);
		}
	}
}

LOCALPROC DoCodeFPU_MoveM_CSIA_EA(ui4b word2)
{
	int n;
	ui5b ea_value[3];
	int num = CountCSIAlist(word2);

	ui4b regselect = (word2 >> 10) & 0x7;

	/* FMOVEM.L <FP CR,SR,IAR list>, <EA> */

	if (0 == regselect) {
		DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
		dbglog_writeln("Invalid FMOVE instruction");
#endif
	} else
	if (! DecodeModeRegister(4 * num)) {
		DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
		dbglog_writeln("bad mode/reg in DoCodeFPU_MoveM_CSIA_EA");
#endif
	} else
	{
		n = 0;
		if (regselect & (1 << 2)) {
			ea_value[n++] = myfp_GetFPCR();
		}
		if (regselect & (1 << 1)) {
			ea_value[n++] = myfp_GetFPSR();
		}
		if (regselect & (1 << 0)) {
			ea_value[n++] = myfp_GetFPIAR();
		}

		SetArgValueL(ea_value[0]);
		if (num > 1) {
			put_long(V_regs.ArgAddr.mem + 4, ea_value[1]);
		}
		if (num > 2) {
			put_long(V_regs.ArgAddr.mem + 8, ea_value[2]);
		}
	}
}

LOCALPROC DoCodeFPU_MoveM_EA_list(ui4b word2)
{
	int i;
	ui5r myaddr;
	ui5r count;
	ui4b register_list = word2;

	ui4b fmove_mode = (word2 >> 11) & 0x3;

	/* FMOVEM.X <ea>, <list> */

	if ((fmove_mode == 0) || (fmove_mode == 1)) {
		DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
		dbglog_writeln("Invalid FMOVEM.X instruction");
#endif
		return;
	}

	if (fmove_mode == 3) {
		/* Dynamic mode */
		register_list = V_regs.regs[(word2 >> 4) & 7];
	}

	count = 0;
	for (i = 0; i <= 7; i++) {
		int j = 1 << (7 - i);
		if (j & register_list) {
			++count;
		}
	}

	if (! DecodeModeRegister(12 * count)) {
		DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
		dbglog_writeln(
			"DecodeModeRegister fails DoCodeFPU_MoveM_EA_list");
#endif
	} else {
		/* Postincrement mode or Control mode */

		myaddr = V_regs.ArgAddr.mem;

		for (i = 0; i <= 7; i++) {
			int j = 1 << (7 - i);
			if (j & register_list) {
				read_long_double(myaddr, &fpu_dat.fp[i]);
				myaddr += 12;
			}
		}
	}
}

LOCALPROC DoCodeFPU_MoveM_list_EA(ui4b word2)
{
	/* FMOVEM.X <list>, <ea> */

	int i;
	ui5r myaddr;
	ui5r count;
	ui4b register_list = word2;
	ui4r Dat = V_regs.CurDecOpY.v[0].ArgDat;
	ui4r themode = (Dat >> 3) & 7;

	ui4b fmove_mode = (word2 >> 11) & 0x3;

	if ((fmove_mode == 1) || (fmove_mode == 3)) {
		/* Dynamic mode */
		register_list = V_regs.regs[(word2 >> 4) & 7];
	}

	count = 0;
	for (i = 7; i >= 0; i--) {
		int j = 1 << i;
		if (j & register_list) {
			++count;
		}
	}

	if (! DecodeModeRegister(12 * count)) {
		DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
		dbglog_writeln(
			"DecodeModeRegister fails DoCodeFPU_MoveM_list_EA");
#endif
	} else {
		if (themode == 4) {
			/* Predecrement mode */

			myaddr = V_regs.ArgAddr.mem + 12 * count;

			for (i = 7; i >= 0; i--) {
				int j = 1 << i;
				if (j & register_list) {
					myaddr -= 12;
					write_long_double(myaddr, &fpu_dat.fp[i]);
				}
			}
		} else {
			/* Control mode */

			myaddr = V_regs.ArgAddr.mem;

			for (i = 0; i <= 7; i++) {
				int j = 1 << (7 - i);
				if (j & register_list) {
					write_long_double(myaddr, &fpu_dat.fp[i]);
					myaddr += 12;
				}
			}
		}
	}
}

LOCALPROC FPU_StoreResult(myfpr *DestReg, myfpr *result)
{
	FPU_Quiet(DestReg, result);
	myfp_SetConditionCodeByteFromResult(DestReg);
}

LOCALPROC SaveResultAndFPSR(myfpr *DestReg, myfpr *result)
{
	if (! FPU_FinishOp()) {
		FPU_StoreResult(DestReg, result);
	}
}

LOCALPROC DoCodeFPU_MoveCR(ui4b word2)
{
	/* FMOVECR */
	ui4r opcode = ((ui4r)(V_regs.CurDecOpY.v[0].AMd) << 8)
		| V_regs.CurDecOpY.v[0].ArgDat;

	if (opcode != 0xF200) {
		DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
		dbglog_writeln("bad opcode in FMOVECR");
#endif
	} else {
		ui4b RomOffset = word2 & 0x7F;
		ui4b DestReg = (word2 >> 7) & 0x7;
		myfpr result;

		if (! myfp_getCR(&result, RomOffset)) {
			DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
			dbglog_writeln("Invalid constant number in FMOVECR");
#endif
		} else {
			/* FMOVECR sets the condition codes like FMOVE */
			SaveResultAndFPSR(&fpu_dat.fp[DestReg], &result);
		}
	}
}

/* opmodes that use the destination register as an operand */
LOCALFUNC blnr FPU_OpIsDyadic(ui4r opmode)
{
	return ((opmode >= 0x20) && (opmode <= 0x2F))
		|| (0x38 == opmode)
		|| ((opmode >= 0x60) && (opmode <= 0x6F));
}

LOCALPROC DoCodeFPU_GenOp(ui4b word2, myfpr *source)
{
	myfpr result;
	myfpr t0;
	myfpr *DestReg = &fpu_dat.fp[(word2 >> 7) & 0x7];

	if (floatx80_is_signaling_nan(*source)
		|| (FPU_OpIsDyadic(word2 & 0x7F)
			&& floatx80_is_signaling_nan(*DestReg)))
	{
		fpu_dat.SNaNOperand = trueblnr;
	}

	switch (word2 & 0x7F) {

		case 0x00: /* FMOVE */
			SaveResultAndFPSR(DestReg, source);
			break;

		case 0x01: /* FINT */
			myfp_Int(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x02: /* FSINH */
			myfp_Sinh(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x03: /* FINTRZ */
			myfp_IntRZ(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x04: /* FSQRT */
			myfp_Sqrt(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x06: /* FLOGNP1 */
			myfp_LogNP1(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x08: /* FETOXM1 */
			myfp_EToXM1(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x09: /* FTANH */
			myfp_Tanh(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x0A: /* FATAN */
			myfp_ATan(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x0C: /* FASIN */
			myfp_ASin(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x0D: /* FATANH */
			myfp_ATanh(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x0E: /* FSIN */
			myfp_Sin(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x0F: /* FTAN */
			myfp_Tan(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x10: /* FETOX */
			myfp_EToX(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x11: /* FTWOTOX */
			myfp_TwoToX(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x12: /* FTENTOX */
			myfp_TenToX(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x14: /* FLOGN */
			myfp_LogN(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x15: /* FLOG10 */
			myfp_Log10(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x16: /* FLOG2 */
			myfp_Log2(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x18: /* FABS */
			myfp_Abs(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x19: /* FCOSH */
			myfp_Cosh(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x1A: /* FNEG */
			myfp_Neg(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x1C: /* FACOS */
			myfp_ACos(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x1D: /* FCOS */
			myfp_Cos(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x1E: /* FGETEXP */
			myfp_GetExp(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x1F: /* FGETMAN */
			myfp_GetMan(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x20: /* FDIV */
			myfp_Div(&result, DestReg, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x21: /* FMOD */  /* 0x2D in some docs, 0x21 in others ? */
			myfp_Mod(&result, DestReg, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x22: /* FADD */
			myfp_Add(&result, DestReg, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x23: /* FMUL */
			myfp_Mul(&result, DestReg, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x24: /* FSGLDIV */
			myfp_Div(&t0, DestReg, source);
			myfp_RoundToSingle(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x25: /* FREM */
			myfp_Rem(&result, DestReg, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x26: /* FSCALE */
			myfp_Scale(&result, DestReg, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x27: /* FSGLMUL */
			myfp_Mul(&t0, DestReg, source);
			myfp_RoundToSingle(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x28: /* FSUB */
			myfp_Sub(&result, DestReg, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x30:
		case 0x31:
		case 0x32:
		case 0x33:
		case 0x34:
		case 0x35:
		case 0x36:
		case 0x37:
			/* FSINCOS */
			myfp_SinCos(&result, &t0, source);
			if (! FPU_FinishOp()) {
				FPU_Quiet(&fpu_dat.fp[word2 & 0x7], &t0);
				FPU_StoreResult(DestReg, &result);
			}
			break;

		case 0x38: /* FCMP */
			{
				/*
					A real compare, not a subtraction: the
					difference of equal infinities is a NaN.
				*/
				ui3r cc = myfp_Compare(DestReg, source);

				if (! FPU_FinishOp()) {
					myfp_SetConditionCodeByte(cc);
				}
			}
			break;

		case 0x3A: /* FTST */
			if (! FPU_FinishOp()) {
				myfp_SetConditionCodeByteFromResult(source);
			}
			break;

		/*
			everything after here is not in 68881/68882,
			appears first in 68040
		*/

		case 0x40: /* FSMOVE */
			myfp_RoundToSingle(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x41: /* FSSQRT */
			myfp_Sqrt(&t0, source);
			myfp_RoundToSingle(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x44: /* FDMOVE */
			myfp_RoundToDouble(&result, source);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x45: /* FDSQRT */
			myfp_Sqrt(&t0, source);
			myfp_RoundToDouble(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x58: /* FSABS */
			myfp_Abs(&t0, source);
			myfp_RoundToSingle(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x5A: /* FSNEG */
			myfp_Neg(&t0, source);
			myfp_RoundToSingle(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x5C: /* FDABS */
			myfp_Abs(&t0, source);
			myfp_RoundToDouble(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x5E: /* FDNEG */
			myfp_Neg(&t0, source);
			myfp_RoundToDouble(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x60: /* FSDIV */
			myfp_Div(&t0, DestReg, source);
			myfp_RoundToSingle(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x62: /* FSADD */
			myfp_Add(&t0, DestReg, source);
			myfp_RoundToSingle(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x63: /* FSMUL */
			myfp_Mul(&t0, DestReg, source);
			myfp_RoundToSingle(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x64: /* FDDIV */
			myfp_Div(&t0, DestReg, source);
			myfp_RoundToDouble(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x66: /* FDADD */
			myfp_Add(&t0, DestReg, source);
			myfp_RoundToDouble(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x67: /* FDMUL */
			myfp_Mul(&t0, DestReg, source);
			myfp_RoundToDouble(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x68: /* FSSUB */
			myfp_Sub(&t0, DestReg, source);
			myfp_RoundToSingle(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		case 0x6C: /* FDSUB */
			myfp_Sub(&t0, DestReg, source);
			myfp_RoundToDouble(&result, &t0);
			SaveResultAndFPSR(DestReg, &result);
			break;

		default:
			DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
			dbglog_writeln("Invalid DoCodeFPU_GenOp");
#endif
			break;
	}
}

LOCALPROC DoCodeFPU_GenOpReg(ui4b word2)
{
	ui4r regselect = (word2 >> 10) & 0x7;

	DoCodeFPU_GenOp(word2, &fpu_dat.fp[regselect]);
}

LOCALPROC DoCodeFPU_GenOpEA(ui4b word2)
{
	myfpr source;

	switch ((word2 >> 10) & 0x7) {
		case 0: /* long-word integer */
			if (! DecodeModeRegister(4)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln(
					"DecodeModeRegister fails GetFPSource L");
#endif
			} else {
				myfp_FromLong(&source, GetArgValueL());
				DoCodeFPU_GenOp(word2, &source);
			}
			break;
		case 1: /* Single-Precision real */
			if (! DecodeModeRegister(4)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln(
					"DecodeModeRegister fails GetFPSource S");
#endif
			} else {
				ui5r v = GetArgValueL();

				fpu_dat.SNaNOperand = float32_is_signaling_nan(v);
				myfp_FromSingleFormat(&source, v);
				DoCodeFPU_GenOp(word2, &source);
			}
			break;
		case 2: /* extended precision real */
			if (! DecodeAddrModeRegister(12)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln(
					"DecodeAddrModeRegister fails GetFPSource X");
#endif
			} else {
				read_long_double(V_regs.ArgAddr.mem, &source);
				DoCodeFPU_GenOp(word2, &source);
			}
			break;
		case 3: /* packed-decimal real, 12 bytes */
			if (! DecodeAddrModeRegister(12)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln(
					"DecodeAddrModeRegister fails GetFPSource P");
#endif
			} else {
				ui5r v2 = get_long(V_regs.ArgAddr.mem);
				ui5r v1 = get_long(V_regs.ArgAddr.mem + 4);
				ui5r v0 = get_long(V_regs.ArgAddr.mem + 8);

				if (myfp_FromPackedFormat(&source, v2, v1, v0)) {
					fpu_dat.ExtraEXC |= myfp_EXC_INEX1;
				}
				DoCodeFPU_GenOp(word2, &source);
			}
			break;
		case 4: /* Word integer */
			if (! DecodeModeRegister(2)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln(
					"DecodeModeRegister fails GetFPSource W");
#endif
			} else {
				myfp_FromLong(&source, GetArgValueW());
				DoCodeFPU_GenOp(word2, &source);
			}
			break;
		case 5: /* Double-precision real */
			if (! DecodeAddrModeRegister(8)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln(
					"DecodeAddrModeRegister fails GetFPSource D");
#endif
			} else {
				ui5r v1 = get_long(V_regs.ArgAddr.mem);
				ui5r v0 = get_long(V_regs.ArgAddr.mem + 4);

				fpu_dat.SNaNOperand = float64_is_signaling_nan(
					(((ui6b)v1) << 32) | (v0 & 0xFFFFFFFF));
				myfp_FromDoubleFormat(&source, v1, v0);
				DoCodeFPU_GenOp(word2, &source);
			}
			break;
		case 6: /* Byte Integer */
			if (! DecodeModeRegister(1)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln(
					"DecodeModeRegister fails GetFPSource B");
#endif
			} else {
				myfp_FromLong(&source, GetArgValueB());
				DoCodeFPU_GenOp(word2, &source);
			}
			break;
		case 7: /* Not a valid source specifier */
			DoCodeFPU_MoveCR(word2);
			break;
		default:
			/* should not be able to get here */
			break;
	}
}

LOCALPROC DoCodeFPU_Move_FP_EA(ui4b word2)
{
	/* FMOVE FP?, <EA> */

	ui4r SourceReg = (word2 >> 7) & 0x7;
	myfpr *source = &fpu_dat.fp[SourceReg];
	myfpr q; /* source, quieted if a signaling NaN */

	/*
		Can set SNAN, OPERR, OVFL, UNFL, INEX2 but doesn't change
		the condition codes. The destination is decoded first
		(that may fetch extension words and adjust An) and only
		written if FPU_FinishOp allows it.
	*/
	fpu_dat.SNaNOperand = floatx80_is_signaling_nan(*source);
	FPU_Quiet(&q, source);

	switch ((word2 >> 10) & 0x7) {
		case 0: /* long-word integer */
			if (! DecodeModeRegister(4)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln("DecodeModeRegister fails FMOVE L");
#endif
			} else {
				ui5r v = myfp_ToInt(source, 32);

				if (! FPU_FinishOp()) {
					SetArgValueL(v);
				}
			}
			break;
		case 1: /* Single-Precision real */
			if (! DecodeModeRegister(4)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln("DecodeModeRegister fails FMOVE S");
#endif
			} else {
				ui5r v = myfp_ToSingleFormat(source);

				if (! FPU_FinishOp()) {
					SetArgValueL(v);
				}
			}
			break;
		case 2: /* extended precision real */
			if (! DecodeAddrModeRegister(12)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln("DecodeAddrModeRegister fails FMOVE X");
#endif
			} else {
				if (! FPU_FinishOp()) {
					write_long_double(V_regs.ArgAddr.mem, &q);
				}
			}
			break;
		case 3: /* packed-decimal real, static k-factor */
		case 7: /* packed-decimal real, dynamic k-factor */
			if (! DecodeAddrModeRegister(12)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln("DecodeAddrModeRegister fails FMOVE P");
#endif
			} else {
				ui5r v2;
				ui5r v1;
				ui5r v0;
				ui5r k = (3 == ((word2 >> 10) & 0x7))
					? word2
					: V_regs.regs[(word2 >> 4) & 7];

				/* k-factor is a 7 bit signed number */
				k &= 0x7F;
				float_exception_flags |= myfp_ToPackedFormat(&q,
					(0 != (k & 0x40)) ? ((si3r)k - 0x80) : (si3r)k,
					&v2, &v1, &v0);
				if (! FPU_FinishOp()) {
					put_long(V_regs.ArgAddr.mem, v2);
					put_long(V_regs.ArgAddr.mem + 4, v1);
					put_long(V_regs.ArgAddr.mem + 8, v0);
				}
			}
			break;
		case 4: /* Word integer */
			if (! DecodeModeRegister(2)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln("DecodeModeRegister fails FMOVE W");
#endif
			} else {
				ui5r v = myfp_ToInt(source, 16);

				if (! FPU_FinishOp()) {
					SetArgValueW(v);
				}
			}
			break;
		case 5: /* Double-precision real */
			if (! DecodeAddrModeRegister(8)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln("DecodeAddrModeRegister fails FMOVE D");
#endif
			} else {
				ui5r v1;
				ui5r v0;

				myfp_ToDoubleFormat(source, &v1, &v0);
				if (! FPU_FinishOp()) {
					put_long(V_regs.ArgAddr.mem, v1);
					put_long(V_regs.ArgAddr.mem + 4, v0);
				}
			}
			break;
		case 6: /* Byte Integer */
			if (! DecodeModeRegister(1)) {
				DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
				dbglog_writeln("DecodeModeRegister fails FMOVE B");
#endif
			} else {
				ui5r v = myfp_ToInt(source, 8);

				if (! FPU_FinishOp()) {
					SetArgValueB(v);
				}
			}
			break;
		default:
			/* can't get here, all 8 formats handled */
			break;
	}
}

LOCALIPROC DoCodeFPU_md60(void)
{
	ui4b word2;

	if (FPU_TookPendingException()) {
		return;
	}
	word2 = (int)nextiword();

	switch ((word2 >> 13) & 0x7) {
		case 0:
			FPU_BeginOp();
			DoCodeFPU_GenOpReg(word2);
			break;
		case 2:
			FPU_BeginOp();
			DoCodeFPU_GenOpEA(word2);
			break;
		case 3:
			FPU_BeginOp();
			DoCodeFPU_Move_FP_EA(word2);
			break;
		case 4:
			DoCodeFPU_Move_EA_CSIA(word2);
			break;
		case 5:
			DoCodeFPU_MoveM_CSIA_EA(word2);
			break;
		case 6:
			DoCodeFPU_MoveM_EA_list(word2);
			break;
		case 7:
			DoCodeFPU_MoveM_list_EA(word2);
			break;
		default:
			DoCodeF_InvalidPlusWord();
#if dbglog_HAVE
			dbglog_writelnNum("Invalid DoCodeFPU_md60",
				(word2 >> 13) & 0x7);
#endif
			break;
	}
}
