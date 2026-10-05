/*
	CCOSOUND.h

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
	SOUND for the Cocoa backend

	The sample ring between the emulator thread and the CoreAudio
	render thread, and the output audio unit.

	Not a header in the usual sense: this is a fragment of
	OSGLUCCO.m, #included by it exactly once, in place, so that the
	backend stays a single translation unit. LOCALVAR and LOCALPROC
	are file static and the order of inclusion matters.
*/

/* --- sound --- */

#if MySoundEnabled

#define kLn2SoundBuffers 4 /* kSoundBuffers must be a power of two */
#define kSoundBuffers (1 << kLn2SoundBuffers)
#define kSoundBuffMask (kSoundBuffers - 1)

#define DesiredMinFilledSoundBuffs 3
	/*
		if too big then sound lags behind emulation.
		if too small then sound will have pauses.
	*/

#define kLnOneBuffLen 9
#define kLnAllBuffLen (kLn2SoundBuffers + kLnOneBuffLen)
#define kOneBuffLen (1UL << kLnOneBuffLen)
#define kAllBuffLen (1UL << kLnAllBuffLen)
#define kLnOneBuffSz (kLnOneBuffLen + kLn2SoundSampSz - 3)
#define kLnAllBuffSz (kLnAllBuffLen + kLn2SoundSampSz - 3)
#define kOneBuffSz (1UL << kLnOneBuffSz)
#define kAllBuffSz (1UL << kLnAllBuffSz)
#define kOneBuffMask (kOneBuffLen - 1)
#define kAllBuffMask (kAllBuffLen - 1)
#define dbhBufferSize (kAllBuffSz + kOneBuffSz)

#define dbglog_SoundStuff (0 && dbglog_HAVE)
#define dbglog_SoundBuffStats (0 && dbglog_HAVE)

/*
	The sample ring is a single producer, single consumer queue
	between two threads that must never wait for each other. The
	producer is the emulator thread, which calls MySound_BeginWrite
	and MySound_EndWrite sixteen times a tick from ASC_SubTick or
	MacSound_SubTick while holding the emulator lock. The consumer is
	CoreAudio's realtime render thread, in my_audio_callback, which
	must never take that lock: a render thread blocked behind the
	emulator is a dropout, and a priority inversion on top.

	So the boundary is two free running offsets and nothing else.
	TheFillOffset is written only by the producer, ThePlayOffset only
	by the consumer, and each is read by the other side. Samples in
	[ThePlayOffset, TheFillOffset) belong to the consumer; everything
	else in the ring belongs to the producer. They were `volatile`,
	which stops the compiler caching them but orders nothing: the
	render thread could see a new fill offset before the samples it
	covers. Now they are _Atomic, published with release once the
	block is fully written and converted, and loaded with acquire by
	the other side before it touches the samples the offset covers.

	The offsets are 16 bits and wrap; kAllBuffLen divides 65536, so
	their difference is always the number of samples between them.
*/

#include <stdatomic.h>

LOCALVAR tpSoundSamp TheSoundBuffer = nullpr;
static _Atomic ui4b ThePlayOffset;
static _Atomic ui4b TheFillOffset;
static _Atomic ui4b MinFilledSoundBuffs;
#if dbglog_SoundBuffStats
LOCALVAR ui4b MaxFilledSoundBuffs;
#endif
LOCALVAR ui4b TheWriteOffset;

/*
	Overflow. When the render thread falls behind (it is stopped, or
	the emulator is running faster than real time) there may be no
	free block to write into. The old answer was to rewind
	TheWriteOffset by a block and overwrite the newest one — but that
	block had already been published, so the producer was rewriting
	samples the render thread was entitled to be reading.

	Instead the decision is made once per block, at its first sample:
	if a whole block is free in the ring the block is written there,
	and since the consumer only ever frees space that decision cannot
	become wrong part way through. Otherwise the whole block goes to a
	private scratch block and is thrown away when it is complete. The
	core only writes inside the span it is handed (the volume and
	invert passes step back within it, never before it), so a span
	from scratch is indistinguishable to it.

	The scratch block is the spare kOneBuffSz at the end of the
	allocation (dbhBufferSize); the ring never reaches it because
	every ring access is masked with kAllBuffMask.
*/
LOCALVAR blnr SoundDroppingBlock = falseblnr;
LOCALVAR ui4b SoundDropOffset;
LOCALVAR ui5b SoundBlocksDropped = 0;

LOCALPROC MySound_Start0(void)
{
	/*
		Reset variables. The render callback is not running here:
		MySound_Start stops the unit, if a fade out still had it
		running, before calling this, and starts it only after.
	*/
	atomic_store_explicit(&ThePlayOffset, 0, memory_order_relaxed);
	atomic_store_explicit(&TheFillOffset, 0, memory_order_relaxed);
	TheWriteOffset = 0;
	SoundDroppingBlock = falseblnr;
	SoundDropOffset = 0;
	atomic_store_explicit(&MinFilledSoundBuffs, kSoundBuffers + 1,
		memory_order_relaxed);
#if dbglog_SoundBuffStats
	MaxFilledSoundBuffs = 0;
#endif
}

GLOBALOSGLUFUNC tpSoundSamp MySound_BeginWrite(ui4r n, ui4r *actL)
{
	ui4b BlockOffset = TheWriteOffset & kOneBuffMask;
	ui4b WriteBuffContig = kOneBuffLen - BlockOffset;

	if (WriteBuffContig < n) {
		n = WriteBuffContig;
	}

	if (0 == BlockOffset && ! SoundDroppingBlock) {
		/*
			Acquire pairs with the release in my_audio_callback:
			once the play offset says a block is free, the render
			thread has finished reading it.
		*/
		ui4b PlayOffset = atomic_load_explicit(&ThePlayOffset,
			memory_order_acquire);
		ui4b ToFillLen = kAllBuffLen - (ui4b)(TheWriteOffset - PlayOffset);

		if (ToFillLen < kOneBuffLen) {
#if dbglog_SoundStuff
			dbglog_writeln("sound buffer over flow");
#endif
			SoundDroppingBlock = trueblnr;
			SoundDropOffset = 0;
		}
	}

	if (SoundDroppingBlock) {
		if (n > kOneBuffLen - SoundDropOffset) {
			n = kOneBuffLen - SoundDropOffset;
		}
		*actL = n;
		return TheSoundBuffer + kAllBuffLen + SoundDropOffset;
	}

	*actL = n;
	return TheSoundBuffer + (TheWriteOffset & kAllBuffMask);
}

#if 4 == kLn2SoundSampSz
LOCALPROC ConvertSoundBlockToNative(tpSoundSamp p)
{
	int i;

	for (i = kOneBuffLen; --i >= 0; ) {
		*p++ -= 0x8000;
	}
}
#else
#define ConvertSoundBlockToNative(p)
#endif

LOCALPROC MySound_WroteABlock(void)
{
#if (4 == kLn2SoundSampSz)
	ui4b PrevWriteOffset = TheWriteOffset - kOneBuffLen;
	tpSoundSamp p = TheSoundBuffer + (PrevWriteOffset & kAllBuffMask);
#endif

#if dbglog_SoundStuff
	dbglog_writeln("enter MySound_WroteABlock");
#endif

	ConvertSoundBlockToNative(p);

	/*
		Release: the samples just written and converted must be
		visible to the render thread before the offset that hands
		them over.
	*/
	atomic_store_explicit(&TheFillOffset, TheWriteOffset,
		memory_order_release);

#if dbglog_SoundBuffStats
	{
		ui4b ToPlayLen = TheWriteOffset
			- atomic_load_explicit(&ThePlayOffset,
				memory_order_relaxed);
		ui4b ToPlayBuffs = ToPlayLen >> kLnOneBuffLen;

		if (ToPlayBuffs > MaxFilledSoundBuffs) {
			MaxFilledSoundBuffs = ToPlayBuffs;
		}
	}
#endif
}

GLOBALOSGLUPROC MySound_EndWrite(ui4r actL)
{
	if (SoundDroppingBlock) {
		/*
			Nothing in the ring changes, so there is nothing to
			publish; the write offset stays put and the next block
			gets a fresh chance at the ring.
		*/
		SoundDropOffset += actL;
		if (SoundDropOffset >= kOneBuffLen) {
			SoundDroppingBlock = falseblnr;
			SoundDropOffset = 0;
			++SoundBlocksDropped;
		}
		return;
	}

	TheWriteOffset += actL;

	if (0 == (TheWriteOffset & kOneBuffMask)) {
		/* just finished a block */

		MySound_WroteABlock();
	}
}

LOCALPROC MySound_SecondNotify0(void)
{
	/*
		The render thread lowers MinFilledSoundBuffs towards the
		least the ring held during this second; this thread reads it
		and starts a new second. An exchange does both at once, so a
		minimum the callback records in between is never lost.
		Relaxed is enough: it is a statistic, not a guard on memory.
	*/
	ui4b MinFilled = atomic_exchange_explicit(&MinFilledSoundBuffs,
		kSoundBuffers + 1, memory_order_relaxed);

	if (MinFilled <= kSoundBuffers) {
		if (MinFilled > DesiredMinFilledSoundBuffs) {
#if dbglog_SoundStuff
			dbglog_writeln("MinFilledSoundBuffs too high");
#endif
			NextTickChangeTime += MyTickDuration;
		} else if (MinFilled < DesiredMinFilledSoundBuffs) {
#if dbglog_SoundStuff
			dbglog_writeln("MinFilledSoundBuffs too low");
#endif
			++TrueEmulatedTime;
		}
#if dbglog_SoundBuffStats
		dbglog_writelnNum("MinFilledSoundBuffs", MinFilled);
		dbglog_writelnNum("MaxFilledSoundBuffs",
			MaxFilledSoundBuffs);
		dbglog_writelnNum("SoundBlocksDropped", SoundBlocksDropped);
		MaxFilledSoundBuffs = 0;
#endif
	}
}

typedef ui4r trSoundTemp;

#define kCenterTempSound 0x8000

#define AudioStepVal 0x0040

#if 3 == kLn2SoundSampSz
#define ConvertTempSoundSampleFromNative(v) ((v) << 8)
#elif 4 == kLn2SoundSampSz
#define ConvertTempSoundSampleFromNative(v) ((v) + kCenterSound)
#else
#error "unsupported kLn2SoundSampSz"
#endif

#if 3 == kLn2SoundSampSz
#define ConvertTempSoundSampleToNative(v) ((v) >> 8)
#elif 4 == kLn2SoundSampSz
#define ConvertTempSoundSampleToNative(v) ((v) - kCenterSound)
#else
#error "unsupported kLn2SoundSampSz"
#endif

LOCALPROC SoundRampTo(trSoundTemp *last_val, trSoundTemp dst_val,
	tpSoundSamp *stream, int *len)
{
	trSoundTemp diff;
	tpSoundSamp p = *stream;
	int n = *len;
	trSoundTemp v1 = *last_val;

	while ((v1 != dst_val) && (0 != n)) {
		if (v1 > dst_val) {
			diff = v1 - dst_val;
			if (diff > AudioStepVal) {
				v1 -= AudioStepVal;
			} else {
				v1 = dst_val;
			}
		} else {
			diff = dst_val - v1;
			if (diff > AudioStepVal) {
				v1 += AudioStepVal;
			} else {
				v1 = dst_val;
			}
		}

		--n;
		*p++ = ConvertTempSoundSampleToNative(v1);
	}

	*stream = p;
	*len = n;
	*last_val = v1;
}

/*
	Of the fields shared with the render thread, wantplaying is the
	emulator's request to start or stop and lastv is the callback's
	report of where the output level has got to. When wantplaying is
	cleared the callback ramps the output to the centre value, so the
	stop fades rather than clicks, and once it gets there it sets
	RampDone. Release on each store and acquire on each cross thread
	load make that handshake an ordered one. HaveStartedPlaying is
	reset by MySound_Start while the unit is stopped and otherwise
	belongs to the callback, but it is atomic too so that no field
	here is shared without being.

	UnitRunning is main thread and emulator thread state, under the
	emulator lock: whether AudioOutputUnitStart has been called
	without a matching AudioOutputUnitStop yet. StopQueued says a
	block that will do that stop is waiting on the main queue.
*/
struct MySoundR {
	tpSoundSamp fTheSoundBuffer;
	_Atomic ui4b (*fPlayOffset);
	_Atomic ui4b (*fFillOffset);
	_Atomic ui4b (*fMinFilledSoundBuffs);

	_Atomic trSoundTemp lastv;

	blnr enabled;
	blnr UnitRunning;
	blnr StopQueued;
	_Atomic blnr wantplaying;
	_Atomic blnr HaveStartedPlaying;
	_Atomic blnr RampDone;

	AudioUnit outputAudioUnit;
};
typedef struct MySoundR MySoundR;

LOCALPROC my_audio_callback(void *udata, void *stream, int len)
{
	ui4b ToPlayLen;
	ui4b FilledSoundBuffs;
	int i;
	MySoundR *datp = (MySoundR *)udata;
	tpSoundSamp CurSoundBuffer = datp->fTheSoundBuffer;
	/* This thread is the only writer of the play offset and lastv. */
	ui4b CurPlayOffset = atomic_load_explicit(datp->fPlayOffset,
		memory_order_relaxed);
	trSoundTemp v1 = atomic_load_explicit(&datp->lastv,
		memory_order_relaxed);
	ui4b MinFilled;
	tpSoundSamp dst = (tpSoundSamp)stream;

#if kLn2SoundSampSz > 3
	len >>= (kLn2SoundSampSz - 3);
#endif

#if dbglog_SoundStuff
	dbglog_writeln("Enter my_audio_callback");
	dbglog_writelnNum("len", len);
#endif

label_retry:
	/*
		Acquire pairs with the release in MySound_WroteABlock: every
		sample below the fill offset is fully written before it is
		read here.
	*/
	ToPlayLen = atomic_load_explicit(datp->fFillOffset,
		memory_order_acquire) - CurPlayOffset;
	FilledSoundBuffs = ToPlayLen >> kLnOneBuffLen;

	if (! atomic_load_explicit(&datp->wantplaying,
		memory_order_acquire))
	{
#if dbglog_SoundStuff
		dbglog_writeln("playing end transistion");
#endif

		SoundRampTo(&v1, kCenterTempSound, &dst, &len);

		if (kCenterTempSound == v1) {
			/*
				The fade out is complete. Release pairs with the
				acquire in MySound_StopUnitIfRampDone, which may
				now stop the unit without a click.
			*/
			atomic_store_explicit(&datp->RampDone, trueblnr,
				memory_order_release);
		}

		ToPlayLen = 0;
	} else if (! atomic_load_explicit(&datp->HaveStartedPlaying,
		memory_order_relaxed))
	{
#if dbglog_SoundStuff
		dbglog_writeln("playing start block");
#endif

		if ((ToPlayLen >> kLnOneBuffLen) < 8) {
			ToPlayLen = 0;
		} else {
			tpSoundSamp p = datp->fTheSoundBuffer
				+ (CurPlayOffset & kAllBuffMask);
			trSoundTemp v2 = ConvertTempSoundSampleFromNative(*p);

#if dbglog_SoundStuff
			dbglog_writeln("have enough samples to start");
#endif

			SoundRampTo(&v1, v2, &dst, &len);

			if (v1 == v2) {
#if dbglog_SoundStuff
				dbglog_writeln("finished start transition");
#endif

				atomic_store_explicit(&datp->HaveStartedPlaying,
					trueblnr, memory_order_relaxed);
			}
		}
	}

	if (0 == len) {
		/* done */

		/*
			Atomic minimum: MySound_SecondNotify0 may exchange in a
			fresh value between the load and the store, and a plain
			store would overwrite it with a stale minimum.
		*/
		MinFilled = atomic_load_explicit(datp->fMinFilledSoundBuffs,
			memory_order_relaxed);
		while ((FilledSoundBuffs < MinFilled)
			&& ! atomic_compare_exchange_weak_explicit(
				datp->fMinFilledSoundBuffs, &MinFilled,
				FilledSoundBuffs,
				memory_order_relaxed, memory_order_relaxed))
		{
		}
	} else if (0 == ToPlayLen) {

#if dbglog_SoundStuff
		dbglog_writeln("under run");
#endif

		for (i = 0; i < len; ++i) {
			*dst++ = ConvertTempSoundSampleToNative(v1);
		}
		/* zero is the least possible, so a plain store is a minimum */
		atomic_store_explicit(datp->fMinFilledSoundBuffs, 0,
			memory_order_relaxed);
	} else {
		ui4b PlayBuffContig = kAllBuffLen
			- (CurPlayOffset & kAllBuffMask);
		tpSoundSamp p = CurSoundBuffer
			+ (CurPlayOffset & kAllBuffMask);

		if (ToPlayLen > PlayBuffContig) {
			ToPlayLen = PlayBuffContig;
		}
		if (ToPlayLen > len) {
			ToPlayLen = len;
		}

		for (i = 0; i < ToPlayLen; ++i) {
			*dst++ = *p++;
		}
		v1 = ConvertTempSoundSampleFromNative(p[-1]);

		CurPlayOffset += ToPlayLen;
		len -= ToPlayLen;

		/*
			Release: the copy out of the ring is complete before the
			producer, loading this with acquire, may reuse the space.
		*/
		atomic_store_explicit(datp->fPlayOffset, CurPlayOffset,
			memory_order_release);

		goto label_retry;
	}

	atomic_store_explicit(&datp->lastv, v1, memory_order_release);
}

LOCALFUNC OSStatus audioCallback(
	void                       *inRefCon,
	AudioUnitRenderActionFlags *ioActionFlags,
	const AudioTimeStamp       *inTimeStamp,
	UInt32                     inBusNumber,
	UInt32                     inNumberFrames,
	AudioBufferList            *ioData)
{
	AudioBuffer *abuf;
	UInt32 i;
	UInt32 n = ioData->mNumberBuffers;

#if dbglog_SoundStuff
	dbglog_writeln("Enter audioCallback");
	dbglog_writelnNum("mNumberBuffers", n);
#endif

	for (i = 0; i < n; i++) {
		abuf = &ioData->mBuffers[i];
		my_audio_callback(inRefCon,
			abuf->mData, abuf->mDataByteSize);
	}

	return 0;
}

LOCALVAR MySoundR cur_audio;

LOCALPROC ZapAudioVars(void)
{
	memset(&cur_audio, 0, sizeof(MySoundR));
}

/*
	Stops the audio unit now. Emulator lock held.
*/
LOCALPROC MySound_StopUnit(void)
{
	if (cur_audio.UnitRunning) {
		OSStatus result;

		cur_audio.UnitRunning = falseblnr;

		if (noErr != (result = AudioOutputUnitStop(
			cur_audio.outputAudioUnit)))
		{
#if dbglog_HAVE
			dbglog_writeln("AudioOutputUnitStop fails");
#endif
		}

		(void) result; /* ignore any errors */
	}
}

/*
	Runs on the main queue some time after MySound_Stop. Stops the
	unit once the render callback has faded the output to the
	centre, or gives up waiting after about half a second, as the
	old code did. Checks that a stop is still wanted, since a
	MySound_Start may have come and gone in between.
*/
LOCALPROC MySound_StopUnitIfRampDone(void);

LOCALPROC MySound_QueueStopCheck(void)
{
	cur_audio.StopQueued = trueblnr;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
			10 * NSEC_PER_MSEC),
		dispatch_get_main_queue(), ^{
			MySound_StopUnitIfRampDone();
		});
}

LOCALVAR int MySoundStopRetries = 0;

LOCALPROC MySound_StopUnitIfRampDone(void)
{
	EmuLock_Acquire();

	cur_audio.StopQueued = falseblnr;

	if (cur_audio.UnitRunning
		&& ! atomic_load_explicit(&cur_audio.wantplaying,
			memory_order_relaxed))
	{
		/* Acquire pairs with the release in my_audio_callback. */
		if (atomic_load_explicit(&cur_audio.RampDone,
			memory_order_acquire))
		{
#if dbglog_SoundStuff
			dbglog_writeln("reached kCenterTempSound");
#endif
			MySound_StopUnit();
		} else if (++MySoundStopRetries >= 50) {
#if dbglog_SoundStuff
			dbglog_writeln("retry limit reached");
#endif
			MySound_StopUnit();
		} else {
			MySound_QueueStopCheck();
		}
	}

	EmuLock_Release();
}

/*
	Asks for sound to stop and returns at once. The render callback
	fades the output to the centre on its own, and the unit is
	stopped later from the main queue. This used to sleep in 10 ms
	steps, up to half a second, waiting for the fade, with the
	emulator lock held throughout; a pause therefore froze the
	interface for as long as the fade took.

	At teardown there is no later: MySound_UnInit stops the unit
	itself, and the queued block, if it ever runs, finds nothing to
	do.
*/
LOCALPROC MySound_Stop(void)
{
#if dbglog_SoundStuff
	dbglog_writeln("enter MySound_Stop");
#endif

	if (atomic_load_explicit(&cur_audio.wantplaying,
		memory_order_relaxed))
	{
		atomic_store_explicit(&cur_audio.RampDone, falseblnr,
			memory_order_relaxed);
		atomic_store_explicit(&cur_audio.wantplaying, falseblnr,
			memory_order_release);

		MySoundStopRetries = 0;
		if (! cur_audio.StopQueued) {
			MySound_QueueStopCheck();
		}
	}

#if dbglog_SoundStuff
	dbglog_writeln("leave MySound_Stop");
#endif
}

LOCALPROC MySound_Start(void)
{
	if ((! atomic_load_explicit(&cur_audio.wantplaying,
		memory_order_relaxed)) && cur_audio.enabled)
	{
		OSStatus result;

#if dbglog_SoundStuff
		dbglog_writeln("enter MySound_Start");
#endif

		/*
			A stop may still be fading out: MySound_Stop returns
			before the unit is stopped. The ring is about to be
			reset, which the callback must not be reading through,
			so the unit is stopped here first and started afresh.
			Any check still queued finds UnitRunning and
			wantplaying both saying there is nothing to do.
		*/
		MySound_StopUnit();

		MySound_Start0();
		atomic_store_explicit(&cur_audio.lastv, kCenterTempSound,
			memory_order_relaxed);
		atomic_store_explicit(&cur_audio.HaveStartedPlaying, falseblnr,
			memory_order_relaxed);
		atomic_store_explicit(&cur_audio.RampDone, falseblnr,
			memory_order_relaxed);
		/* Release publishes the resets above to the render thread. */
		atomic_store_explicit(&cur_audio.wantplaying, trueblnr,
			memory_order_release);

		if (noErr != (result = AudioOutputUnitStart(
			cur_audio.outputAudioUnit)))
		{
#if dbglog_HAVE
			dbglog_writeln("AudioOutputUnitStart fails");
#endif
			atomic_store_explicit(&cur_audio.wantplaying, falseblnr,
				memory_order_relaxed);
		} else {
			cur_audio.UnitRunning = trueblnr;
		}

#if dbglog_SoundStuff
		dbglog_writeln("leave MySound_Start");
#endif

		(void) result; /* ignore any errors */
	}
}

LOCALPROC MySound_UnInit(void)
{
	if (cur_audio.enabled) {
		OSStatus result;
		struct AURenderCallbackStruct callback;

		cur_audio.enabled = falseblnr;

		/*
			MySound_Stop, called just before this, only asks; the
			unit is still running until the fade completes. Nothing
			will run the queued stop after main returns, so stop it
			here, before the callback is removed and the unit
			disposed of.
		*/
		MySound_StopUnit();

		/* Remove the input callback */
		callback.inputProc = 0;
		callback.inputProcRefCon = 0;

		if (noErr != (result = AudioUnitSetProperty(
			cur_audio.outputAudioUnit,
			kAudioUnitProperty_SetRenderCallback,
			kAudioUnitScope_Input,
			0,
			&callback,
			sizeof(callback))))
		{
#if dbglog_HAVE
			dbglog_writeln("AudioUnitSetProperty fails"
				"(kAudioUnitProperty_SetRenderCallback)");
#endif
		}

		(void) result; /* ignore any errors */

		if (noErr != (result = AudioComponentInstanceDispose(
			cur_audio.outputAudioUnit)))
		{
#if dbglog_HAVE
			dbglog_writeln("AudioComponentInstanceDispose fails"
				" in MySound_UnInit");
#endif
		}

		(void) result; /* ignore any errors */
	}
}

#define SOUND_SAMPLERATE 22255 /* = round(7833600 * 2 / 704) */

LOCALFUNC blnr MySound_Init(void)
{
	OSStatus result = noErr;
	AudioComponent comp;
	AudioComponentDescription desc;
	struct AURenderCallbackStruct callback;
	AudioStreamBasicDescription requestedDesc;

	cur_audio.fTheSoundBuffer = TheSoundBuffer;
	cur_audio.fPlayOffset = &ThePlayOffset;
	cur_audio.fFillOffset = &TheFillOffset;
	cur_audio.fMinFilledSoundBuffs = &MinFilledSoundBuffs;
	atomic_store_explicit(&cur_audio.wantplaying, falseblnr,
		memory_order_relaxed);

	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_DefaultOutput;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;


	requestedDesc.mFormatID = kAudioFormatLinearPCM;
	requestedDesc.mFormatFlags = kLinearPCMFormatFlagIsPacked
#if 3 != kLn2SoundSampSz
		| kLinearPCMFormatFlagIsSignedInteger
#endif
		;
	requestedDesc.mChannelsPerFrame = 1;
	requestedDesc.mSampleRate = SOUND_SAMPLERATE;

	requestedDesc.mBitsPerChannel = (1 << kLn2SoundSampSz);

	requestedDesc.mFramesPerPacket = 1;
	requestedDesc.mBytesPerFrame = (requestedDesc.mBitsPerChannel
		* requestedDesc.mChannelsPerFrame) >> 3;
	requestedDesc.mBytesPerPacket = requestedDesc.mBytesPerFrame
		* requestedDesc.mFramesPerPacket;


	callback.inputProc = audioCallback;
	callback.inputProcRefCon = &cur_audio;

	if (NULL == (comp = AudioComponentFindNext(NULL, &desc)))
	{
#if dbglog_HAVE
		dbglog_writeln("Failed to start CoreAudio: "
			"AudioComponentFindNext returned NULL");
#endif
	} else

	if (noErr != (result = AudioComponentInstanceNew(
		comp, &cur_audio.outputAudioUnit)))
	{
#if dbglog_HAVE
		dbglog_writeln("Failed to start CoreAudio:"
			" AudioComponentInstanceNew");
#endif
	} else

	if (noErr != (result = AudioUnitInitialize(
		cur_audio.outputAudioUnit)))
	{
#if dbglog_HAVE
		dbglog_writeln(
			"Failed to start CoreAudio: AudioUnitInitialize");
#endif
	} else

	if (noErr != (result = AudioUnitSetProperty(
		cur_audio.outputAudioUnit,
		kAudioUnitProperty_StreamFormat,
		kAudioUnitScope_Input,
		0,
		&requestedDesc,
		sizeof(requestedDesc))))
	{
#if dbglog_HAVE
		dbglog_writeln("Failed to start CoreAudio: "
			"AudioUnitSetProperty(kAudioUnitProperty_StreamFormat)");
#endif
	} else

	if (noErr != (result = AudioUnitSetProperty(
		cur_audio.outputAudioUnit,
		kAudioUnitProperty_SetRenderCallback,
		kAudioUnitScope_Input,
		0,
		&callback,
		sizeof(callback))))
	{
#if dbglog_HAVE
		dbglog_writeln("Failed to start CoreAudio: "
			"AudioUnitSetProperty(kAudioUnitProperty_SetInputCallback)"
			);
#endif
	} else

	{
		cur_audio.enabled = trueblnr;

		MySound_Start();
			/*
				This should be taken care of by LeaveSpeedStopped,
				but since takes a while to get going properly,
				start early.
			*/
	}

	(void) result; /* ignore any errors */
	return trueblnr; /* keep going, even if no sound */
}

LOCALPROC MySound_SecondNotify(void)
{
	if (cur_audio.enabled) {
		MySound_SecondNotify0();
	}
}

#endif
