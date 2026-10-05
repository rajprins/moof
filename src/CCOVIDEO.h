/*
	CCOVIDEO.h

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
	VIDEO out for the Cocoa backend

	Conversion of the changed region of the guest framebuffer into
	ScalingBuff, and the hand off of the converted frame to the
	Metal renderer on the main thread.

	Not a header in the usual sense: this is a fragment of
	OSGLUCCO.m, #included by it exactly once, in place, so that the
	backend stays a single translation unit. LOCALVAR and LOCALPROC
	are file static and the order of inclusion matters.
*/

LOCALVAR ui3p ScalingBuff = nullpr;

/* Frame handed from the emulating thread to the main thread. */
LOCALVAR blnr FrameIsReady = falseblnr;
LOCALVAR blnr FrameIsColor = falseblnr;
LOCALVAR int FrameSrcX = 0;
LOCALVAR int FrameSrcY = 0;
LOCALVAR int FrameSrcW = 0;
LOCALVAR int FrameSrcH = 0;

LOCALVAR ui3p CLUT_final;

#define CLUT_finalsz1 (256 * 8)

#if (0 != vMacScreenDepth) && (vMacScreenDepth < 4)

#define CLUT_finalClrSz (256 << (5 - vMacScreenDepth))

#define CLUT_finalsz ((CLUT_finalClrSz > CLUT_finalsz1) \
	? CLUT_finalClrSz : CLUT_finalsz1)

#else
#define CLUT_finalsz CLUT_finalsz1
#endif


#define ScrnMapr_DoMap UpdateBWLuminanceCopy
#define ScrnMapr_Src screencomparebuff
#define ScrnMapr_Dst ScalingBuff
#define ScrnMapr_SrcDepth 0
#define ScrnMapr_DstDepth 3
#define ScrnMapr_Map CLUT_final

#include "SCRNMAPR.h"


#if (0 != vMacScreenDepth) && (vMacScreenDepth < 4)

#define ScrnMapr_DoMap UpdateMappedColorCopy
#define ScrnMapr_Src screencomparebuff
#define ScrnMapr_Dst ScalingBuff
#define ScrnMapr_SrcDepth vMacScreenDepth
#define ScrnMapr_DstDepth 5
#define ScrnMapr_Map CLUT_final

#include "SCRNMAPR.h"

#endif

#if vMacScreenDepth >= 4

#define ScrnTrns_DoTrans UpdateTransColorCopy
#define ScrnTrns_Src screencomparebuff
#define ScrnTrns_Dst ScalingBuff
#define ScrnTrns_SrcDepth vMacScreenDepth
#define ScrnTrns_DstDepth 5
#define ScrnTrns_DstZLo 1

#include "SCRNTRNS.h"

#endif

LOCALPROC UpdateLuminanceCopy(si4b top, si4b left,
	si4b bottom, si4b right)
{
	int i;

#if 0 != vMacScreenDepth
	if (UseColorMode) {

#if vMacScreenDepth < 4

		if (! ColorTransValid) {
			int j;
			int k;
			ui5p p4;

			p4 = (ui5p)CLUT_final;
			for (i = 0; i < 256; ++i) {
				for (k = 1 << (3 - vMacScreenDepth); --k >= 0; ) {
					j = (i >> (k << vMacScreenDepth)) & (CLUT_size - 1);
					*p4++ = (((ui5b)CLUT_reds[j] & 0xFF00) << 16)
						| (((ui5b)CLUT_greens[j] & 0xFF00) << 8)
						| ((ui5b)CLUT_blues[j] & 0xFF00);
				}
			}
			ColorTransValid = trueblnr;
		}

		UpdateMappedColorCopy(top, left, bottom, right);

#else
		UpdateTransColorCopy(top, left, bottom, right);
#endif

	} else
#endif
	{
		if (! ColorTransValid) {
			int k;
			ui3p p4 = (ui3p)CLUT_final;

			for (i = 0; i < 256; ++i) {
				for (k = 8; --k >= 0; ) {
					*p4++ = ((i >> k) & 0x01) - 1;
				}
			}
			ColorTransValid = trueblnr;
		}

		UpdateBWLuminanceCopy(top, left, bottom, right);
	}
}

/*
	Converts the changed region into ScalingBuff and presents the
	frame.

	Where the OpenGL path computed a raster position and blitted just
	the changed rectangle, the renderer is handed the whole frame plus
	the rectangle that should be visible, and the sampler does the
	scaling. Full screen panning and magnification are therefore no
	longer expressed here at all.

	The whole buffer is uploaded, so every pixel of ScalingBuff has
	to have been converted at least once before the first partial
	update. That holds because drawRect performs the first draw with
	the full screen rectangle.
*/
LOCALPROC MyDrawWithMetal(ui4r top, ui4r left, ui4r bottom, ui4r right)
{
	int srcX = 0;
	int srcY = 0;
	int srcW = vMacScreenWidth;
	int srcH = vMacScreenHeight;

	if (! HaveRenderer) {
		goto label_exit;
	}

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		if (top < ViewVStart) {
			top = ViewVStart;
		}
		if (left < ViewHStart) {
			left = ViewHStart;
		}
		if (bottom > ViewVStart + ViewVSize) {
			bottom = ViewVStart + ViewVSize;
		}
		if (right > ViewHStart + ViewHSize) {
			right = ViewHStart + ViewHSize;
		}

		if ((top >= bottom) || (left >= right)) {
			goto label_exit;
		}

		srcX = ViewHStart;
		srcY = ViewVStart;
		srcW = ViewHSize;
		srcH = ViewVSize;
	}
#endif

	UpdateLuminanceCopy(top, left, bottom, right);

	/*
		Conversion happens on whichever thread is emulating, but
		presentation must not: it reads the layer, whose geometry
		belongs to AppKit. So the converted frame is recorded here
		and MyUploadPendingFrame copies it out from the display link
		on the main thread. The emulator lock covers ScalingBuff, so
		the two never overlap.
	*/
	FrameSrcX = srcX;
	FrameSrcY = srcY;
	FrameSrcW = srcW;
	FrameSrcH = srcH;
#if 0 != vMacScreenDepth
	FrameIsColor = UseColorMode ? trueblnr : falseblnr;
#else
	FrameIsColor = falseblnr;
#endif
	FrameIsReady = trueblnr;

label_exit:
	;
}

/*
	Copies whatever the emulator last converted into the renderer's
	texture. Main thread only, with the emulator lock held by the
	caller: FrameIsReady and ScalingBuff belong to the lock. Returns
	whether there is now something for MyDrawUploadedFrame to draw.

	Only the copy happens under the lock. Taking a drawable can wait
	on the compositor, and encoding and committing are GPU side
	work; none of that needs emulator state, so the caller releases
	the lock first and then calls MyDrawUploadedFrame. The emulator
	thread can therefore run its next tick while the frame is being
	drawn, instead of waiting behind the GPU.
*/
LOCALFUNC blnr MyUploadPendingFrame(void)
{
	if (FrameIsReady) {
		FrameIsReady = falseblnr;

		MTLRenderer_Upload(ScalingBuff,
			FrameIsColor ? true : false,
			FrameSrcX, FrameSrcY, FrameSrcW, FrameSrcH);

		return trueblnr;
	}

	return falseblnr;
}

/*
	Draws the frame MyUploadPendingFrame last copied. Main thread
	only, without the emulator lock.
*/
LOCALPROC MyDrawUploadedFrame(void)
{
	MTLRenderer_Draw();
}
