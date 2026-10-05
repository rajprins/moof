/*
	MTLRENDR.m

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

	See MTLRENDR.h for the interface. This file is deliberately free
	of emulator state: it is handed pixels and a rectangle, and knows
	nothing about ticks, speed or the guest machine.
*/

#import "MTLRENDR.h"

#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

/*
	Pixel layout, as produced by SCRNMAPR and the CLUT that the
	backend builds.

	Colour: each pixel is one uint32 written as 0xRRGGBB00, so on a
	little endian machine the bytes in memory run 00, B, G, R. That
	matches neither rgba8Unorm nor bgra8Unorm, so the texture is
	declared rgba8Unorm and the shader recovers the true colour as
	sample.wzy. Getting this wrong yields a plausible looking but
	blue tinted picture, so it is asserted by construction here
	rather than left to chance.

	Monochrome: one byte per pixel, either 0x00 or 0xFF, so the
	texture is r8Unorm and the shader replicates red across rgb.
*/

static NSString * const kShaderSource = @"\n\
#include <metal_stdlib>\n\
using namespace metal;\n\
\n\
struct Vertex {\n\
	float4 position [[position]];\n\
	float2 uv;\n\
};\n\
\n\
struct Rect {\n\
	float2 origin;\n\
	float2 size;\n\
};\n\
\n\
/*\n\
	A full drawable quad from a four vertex triangle strip. The\n\
	source rectangle arrives normalised, so panning and magnifying\n\
	are both expressed here and nowhere else.\n\
*/\n\
vertex Vertex vertexMain(uint vid [[vertex_id]],\n\
	constant Rect &src [[buffer(0)]])\n\
{\n\
	const float2 corner[4] = {\n\
		float2(0.0, 0.0), float2(1.0, 0.0),\n\
		float2(0.0, 1.0), float2(1.0, 1.0)\n\
	};\n\
	float2 c = corner[vid];\n\
\n\
	Vertex out;\n\
	out.position = float4(c.x * 2.0 - 1.0, 1.0 - c.y * 2.0, 0.0, 1.0);\n\
	out.uv = src.origin + c * src.size;\n\
	return out;\n\
}\n\
\n\
fragment float4 fragmentColor(Vertex in [[stage_in]],\n\
	texture2d<float> tex [[texture(0)]],\n\
	sampler samp [[sampler(0)]])\n\
{\n\
	float4 s = tex.sample(samp, in.uv);\n\
	/* memory is 00,B,G,R so sampled rgba is (0,B,G,R) */\n\
	return float4(s.w, s.z, s.y, 1.0);\n\
}\n\
\n\
fragment float4 fragmentMono(Vertex in [[stage_in]],\n\
	texture2d<float> tex [[texture(0)]],\n\
	sampler samp [[sampler(0)]])\n\
{\n\
	float l = tex.sample(samp, in.uv).r;\n\
	return float4(l, l, l, 1.0);\n\
}\n\
";

typedef struct {
	float originX;
	float originY;
	float sizeW;
	float sizeH;
} tSrcRect;

static CAMetalLayer *gLayer = nil;
static id<MTLDevice> gDevice = nil;
static id<MTLCommandQueue> gQueue = nil;
static id<MTLRenderPipelineState> gPipeColor = nil;
static id<MTLRenderPipelineState> gPipeMono = nil;
static id<MTLSamplerState> gSampler = nil;
static id<MTLTexture> gTexColor = nil;
static id<MTLTexture> gTexMono = nil;

static int gGuestWidth = 0;
static int gGuestHeight = 0;

/*
	What the latest Upload left for Draw: which texture, which part
	of it, and whether there is anything new at all.
*/
static bool gUploadPending = false;
static bool gUploadIsColor = false;
static tSrcRect gUploadSrc;

/*
	This target is compiled without ARC, since the backend still
	uses explicit retain and release and manual autorelease pools.
	Ownership is therefore spelled out by hand here. The retains and
	releases in this file come out when the backend is split and ARC
	is turned on for the whole target.
*/

static id<MTLRenderPipelineState> MTLRenderer_MakePipeline(
	id<MTLLibrary> library, NSString *fragmentName)
{
	MTLRenderPipelineDescriptor *desc =
		[[MTLRenderPipelineDescriptor alloc] init];
	id<MTLFunction> vertexFn =
		[library newFunctionWithName: @"vertexMain"];
	id<MTLFunction> fragmentFn =
		[library newFunctionWithName: fragmentName];

	desc.vertexFunction = vertexFn;
	desc.fragmentFunction = fragmentFn;
	desc.colorAttachments[0].pixelFormat = gLayer.pixelFormat;

	NSError *err = nil;
	id<MTLRenderPipelineState> state =
		[gDevice newRenderPipelineStateWithDescriptor: desc
			error: &err];

	if (nil == state) {
		NSLog(@"MTLRENDR: pipeline %@ failed: %@", fragmentName, err);
	}

	[vertexFn release];
	[fragmentFn release];
	[desc release];

	return state;
}

bool MTLRenderer_Init(NSView *view, int guestWidth, int guestHeight)
{
	gGuestWidth = guestWidth;
	gGuestHeight = guestHeight;

	gDevice = MTLCreateSystemDefaultDevice();
	if (nil == gDevice) {
		NSLog(@"MTLRENDR: no Metal device");
		return false;
	}

	gQueue = [gDevice newCommandQueue];
	if (nil == gQueue) {
		NSLog(@"MTLRENDR: no command queue");
		return false;
	}

	gLayer = [[CAMetalLayer layer] retain];
	gLayer.device = gDevice;
	gLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
	gLayer.framebufferOnly = YES;
	gLayer.opaque = YES;
	/*
		The emulated screen is a fixed grid of pixels, so the layer
		must not resample it on our behalf when the window resizes.
	*/
	gLayer.magnificationFilter = kCAFilterNearest;
	gLayer.minificationFilter = kCAFilterNearest;

	/*
		Order matters. Assigning the layer before setting
		wantsLayer makes this a layer hosting view, which is what
		is wanted: the layer is ours and AppKit must not replace
		it. Doing it the other way round makes the view layer
		backed first, and the layer assignment is then fighting
		AppKit for ownership.
	*/
	view.layer = gLayer;
	view.wantsLayer = YES;

	/*
		The shader is compiled from source rather than shipped as a
		.metal file. That keeps the generated Xcode project free of
		a Metal compile build phase, which would mean teaching the
		project generator a second new file type.
	*/
	NSError *err = nil;
	id<MTLLibrary> library =
		[gDevice newLibraryWithSource: kShaderSource
			options: nil error: &err];

	if (nil == library) {
		NSLog(@"MTLRENDR: shader compile failed: %@", err);
		return false;
	}

	gPipeColor = MTLRenderer_MakePipeline(library, @"fragmentColor");
	gPipeMono = MTLRenderer_MakePipeline(library, @"fragmentMono");

	[library release];

	if ((nil == gPipeColor) || (nil == gPipeMono)) {
		return false;
	}

	MTLSamplerDescriptor *sd = [[MTLSamplerDescriptor alloc] init];
	sd.minFilter = MTLSamplerMinMagFilterNearest;
	sd.magFilter = MTLSamplerMinMagFilterNearest;
	sd.sAddressMode = MTLSamplerAddressModeClampToEdge;
	sd.tAddressMode = MTLSamplerAddressModeClampToEdge;
	gSampler = [gDevice newSamplerStateWithDescriptor: sd];
	[sd release];

	MTLTextureDescriptor *td = [MTLTextureDescriptor
		texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm
			width: (NSUInteger)guestWidth
			height: (NSUInteger)guestHeight
			mipmapped: NO];
	td.usage = MTLTextureUsageShaderRead;
	td.storageMode = MTLStorageModeShared;
	gTexColor = [gDevice newTextureWithDescriptor: td];

	td.pixelFormat = MTLPixelFormatR8Unorm;
	gTexMono = [gDevice newTextureWithDescriptor: td];

	if ((nil == gTexColor) || (nil == gTexMono)) {
		NSLog(@"MTLRENDR: texture allocation failed");
		return false;
	}

	return true;
}

void MTLRenderer_UnInit(void)
{
	gUploadPending = false;
	[gTexColor release];
	gTexColor = nil;
	[gTexMono release];
	gTexMono = nil;
	[gSampler release];
	gSampler = nil;
	[gPipeColor release];
	gPipeColor = nil;
	[gPipeMono release];
	gPipeMono = nil;
	[gQueue release];
	gQueue = nil;
	[gDevice release];
	gDevice = nil;
	[gLayer release];
	gLayer = nil;
}

void MTLRenderer_Resize(double ptWidth, double ptHeight,
	double backingScale)
{
	if (nil == gLayer) {
		return;
	}
	if (backingScale <= 0.0) {
		backingScale = 1.0;
	}

	gLayer.contentsScale = backingScale;
	gLayer.drawableSize = CGSizeMake(ptWidth * backingScale,
		ptHeight * backingScale);
}

void MTLRenderer_Upload(const void *pixels, bool isColor,
	int srcX, int srcY, int srcW, int srcH)
{
	if ((nil == gLayer) || (nil == gQueue) || (NULL == pixels)) {
		return;
	}
	if ((srcW <= 0) || (srcH <= 0)) {
		return;
	}

	id<MTLTexture> tex = isColor ? gTexColor : gTexMono;
	NSUInteger bytesPerPixel = isColor ? 4 : 1;

	/*
		The whole frame is uploaded rather than the dirty rectangle.
		At 800x600x4 that is under 2 MB, so roughly 115 MB/s at the
		emulated 60.14 Hz, which is nothing on unified memory. The
		alternative means unioning dirty rectangles whenever the
		display skips a produced frame, and that bookkeeping is a
		reliable source of corruption that cannot be reproduced.

		replaceRegion on a shared storage texture is a synchronous
		CPU copy, so once it returns the caller's buffer is free.
	*/
	[tex replaceRegion: MTLRegionMake2D(0, 0,
			(NSUInteger)gGuestWidth, (NSUInteger)gGuestHeight)
		mipmapLevel: 0
		withBytes: pixels
		bytesPerRow: (NSUInteger)gGuestWidth * bytesPerPixel];

	gUploadIsColor = isColor;
	gUploadSrc.originX = (float)srcX / (float)gGuestWidth;
	gUploadSrc.originY = (float)srcY / (float)gGuestHeight;
	gUploadSrc.sizeW = (float)srcW / (float)gGuestWidth;
	gUploadSrc.sizeH = (float)srcH / (float)gGuestHeight;
	gUploadPending = true;
}

void MTLRenderer_Draw(void)
{
	if ((nil == gLayer) || (nil == gQueue) || ! gUploadPending) {
		return;
	}

	gUploadPending = false;

	/*
		Metal hands back autoreleased drawables, command buffers and
		encoders. The caller does not always sit inside a pool of its
		own, so one is established here rather than relying on it.
	*/
	@autoreleasepool {

	id<MTLTexture> tex = gUploadIsColor ? gTexColor : gTexMono;

	/*
		nextDrawable can block until the compositor frees one, which
		is why this runs outside the caller's lock.
	*/
	id<CAMetalDrawable> drawable = [gLayer nextDrawable];
	if (nil == drawable) {
		return;
	}

	MTLRenderPassDescriptor *rp =
		[MTLRenderPassDescriptor renderPassDescriptor];
	rp.colorAttachments[0].texture = drawable.texture;
	rp.colorAttachments[0].loadAction = MTLLoadActionClear;
	rp.colorAttachments[0].storeAction = MTLStoreActionStore;
	rp.colorAttachments[0].clearColor =
		MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

	id<MTLCommandBuffer> cb = [gQueue commandBuffer];
	id<MTLRenderCommandEncoder> enc =
		[cb renderCommandEncoderWithDescriptor: rp];

	[enc setRenderPipelineState:
		gUploadIsColor ? gPipeColor : gPipeMono];
	[enc setVertexBytes: &gUploadSrc length: sizeof(gUploadSrc)
		atIndex: 0];
	[enc setFragmentTexture: tex atIndex: 0];
	[enc setFragmentSamplerState: gSampler atIndex: 0];
	[enc drawPrimitives: MTLPrimitiveTypeTriangleStrip
		vertexStart: 0 vertexCount: 4];
	[enc endEncoding];

	[cb presentDrawable: drawable];
	[cb commit];

	} /* @autoreleasepool */
}
