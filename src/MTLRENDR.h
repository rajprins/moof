/*
	MTLRENDR.h

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
	MeTaL RENDeRer

	Presents the emulated screen through a CAMetalLayer, replacing
	the fixed function OpenGL path that used glRasterPos2i,
	glPixelZoom and glDrawPixels.

	The renderer takes a whole converted frame and the sub rectangle
	of it that should be visible, and stretches that sub rectangle
	over the drawable with nearest neighbour sampling. Magnification
	and full screen panning are therefore expressed purely as the
	source rectangle plus the drawable size, and no offset
	arithmetic is needed by the caller.

	Pixel layout of the incoming frame is dictated by SCRNMAPR and
	the CLUT built in the backend. See MTLRENDR.m for the details.
*/

#ifndef MTLRENDR_H
#define MTLRENDR_H

#import <AppKit/AppKit.h>

#include <stdbool.h>

/*
	Attaches a CAMetalLayer to the given view and builds the
	pipeline. guestWidth and guestHeight are the dimensions of the
	emulated screen, which fix the texture size for the lifetime of
	the renderer.
*/
extern bool MTLRenderer_Init(NSView *view,
	int guestWidth, int guestHeight);

extern void MTLRenderer_UnInit(void);

/*
	Tells the renderer the drawable should be resized. Sizes are in
	points; the renderer applies the backing scale factor itself so
	that an integral magnification stays pixel exact.
*/
extern void MTLRenderer_Resize(double ptWidth, double ptHeight,
	double backingScale);

/*
	Presenting a frame is two calls, so that the caller can hold its
	lock over the first and not the second.

	MTLRenderer_Upload copies the frame into the renderer's texture
	and records which rectangle of it to show. isColor selects
	between the 32 bit colour layout and the 8 bit monochrome layout.
	The src rectangle is in guest pixels and selects the visible
	region, which differs from the whole screen only when panning in
	full screen. After it returns the caller's pixel buffer is no
	longer read, so whatever protected that buffer may be released.

	MTLRenderer_Draw takes the next drawable, encodes the pass that
	stretches the uploaded rectangle over it, and commits. It reads
	only renderer state, so it needs no lock of the caller's. It
	draws what the latest Upload left behind, and does nothing if
	there has been no Upload since the last Draw.

	Both must be called on the main thread: the texture copy is
	only safe while the drawable is not being written, and the
	layer belongs to AppKit.
*/
extern void MTLRenderer_Upload(const void *pixels, bool isColor,
	int srcX, int srcY, int srcW, int srcH);

extern void MTLRenderer_Draw(void);

#endif /* MTLRENDR_H */
