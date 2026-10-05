/*
	KEYRMPMC.h

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
	KEYboard ReMaP for MaCintosh hosts

	The part of the old CONTROLM.h that has to survive the removal of
	the character cell Control Mode overlay: translating host key
	codes into the keys the emulated computer sees.

	Before, the host Control key was taken over by the overlay. By
	default it mapped to the pseudo key MKC_CM, holding it down
	entered Control Mode, and every other key went to the overlay
	rather than to the emulated computer until it was released. The
	commands that mode offered are now in the native menu bar, the
	Settings window and the About panel, so the mode, its state
	machine and its drawing are gone. Every key, Control included,
	now passes straight through to the emulated keyboard.

	Control reaching the guest does not conflict with the menu key
	equivalents, which are all Control chords: those are matched in
	-[MyClassApplication sendEvent:] before the emulator sees the
	event, and only chords no menu item claims fall through to here.

	The remapping itself is set when the build is generated, by the
	setuptool "-km" and "-ccs" options, which define the
	MKC_formac_* names used below.
*/

#ifdef KEYRMPMC_H
#error "header already included"
#else
#define KEYRMPMC_H
#endif

LOCALFUNC ui3r Keyboard_RemapMac(ui3r key)
{
	switch (key) {
#if MKC_formac_Control != MKC_Control
		case MKC_Control:
			key = MKC_formac_Control;
			break;
#endif
#if MKC_formac_Command != MKC_Command
		case MKC_Command:
			key = MKC_formac_Command;
			break;
#endif
#if MKC_formac_Option != MKC_Option
		case MKC_Option:
			key = MKC_formac_Option;
			break;
#endif
#if MKC_formac_Shift != MKC_Shift
		case MKC_Shift:
			key = MKC_formac_Shift;
			break;
#endif
#if MKC_formac_CapsLock != MKC_CapsLock
		case MKC_CapsLock:
			key = MKC_formac_CapsLock;
			break;
#endif
#if MKC_formac_F1 != MKC_F1
		case MKC_F1:
			key = MKC_formac_F1;
			break;
#endif
#if MKC_formac_F2 != MKC_F2
		case MKC_F2:
			key = MKC_formac_F2;
			break;
#endif
#if MKC_formac_F3 != MKC_F3
		case MKC_F3:
			key = MKC_formac_F3;
			break;
#endif
#if MKC_formac_F4 != MKC_F4
		case MKC_F4:
			key = MKC_formac_F4;
			break;
#endif
#if MKC_formac_F5 != MKC_F5
		case MKC_F5:
			key = MKC_formac_F5;
			break;
#endif
#if MKC_formac_Escape != MKC_Escape
		case MKC_Escape:
			key = MKC_formac_Escape;
			break;
#endif
#if MKC_formac_BackSlash != MKC_BackSlash
		case MKC_BackSlash:
			key = MKC_formac_BackSlash;
			break;
#endif
#if MKC_formac_Slash != MKC_Slash
		case MKC_Slash:
			key = MKC_formac_Slash;
			break;
#endif
#if MKC_formac_Grave != MKC_Grave
		case MKC_Grave:
			key = MKC_formac_Grave;
			break;
#endif
#if MKC_formac_Enter != MKC_Enter
		case MKC_Enter:
			key = MKC_formac_Enter;
			break;
#endif
#if MKC_formac_PageUp != MKC_PageUp
		case MKC_PageUp:
			key = MKC_formac_PageUp;
			break;
#endif
#if MKC_formac_PageDown != MKC_PageDown
		case MKC_PageDown:
			key = MKC_formac_PageDown;
			break;
#endif
#if MKC_formac_Home != MKC_Home
		case MKC_Home:
			key = MKC_formac_Home;
			break;
#endif
#if MKC_formac_End != MKC_End
		case MKC_End:
			key = MKC_formac_End;
			break;
#endif
#if MKC_formac_Help != MKC_Help
		case MKC_Help:
			key = MKC_formac_Help;
			break;
#endif
#if MKC_formac_ForwardDel != MKC_ForwardDel
		case MKC_ForwardDel:
			key = MKC_formac_ForwardDel;
			break;
#endif
		default:
			break;
	}

	return key;
}

/*
	Called when key ups may be missed, such as when the window is
	sent to the background or a modal dialog takes over. Every key
	the emulated computer believes is down is released, except Caps
	Lock, which is a toggle whose state the host reports again with
	the next modifier change.

	Control used to be kept as well, because it belonged to the
	overlay rather than to the emulated keyboard. It is now an
	ordinary modifier and is released like Command, Option and Shift.
*/
LOCALPROC DisconnectKeyCodes2(void)
{
	DisconnectKeyCodes(kKeepMaskCapsLock);
}
