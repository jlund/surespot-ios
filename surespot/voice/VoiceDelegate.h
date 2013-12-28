//
//  VoiceDelegate.h
//  surespot
//
//  Created by Adam on 12/27/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#include <libkern/OSAtomic.h>
#include <CoreFoundation/CFURL.h>

#import "EAGLView.h"
#import "FFTBufferManager.h"
#import "aurio_helper.h"
#import "CAStreamBasicDescription.h"

#define SPECTRUM_BAR_WIDTH 4

#ifndef CLAMP
#define CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))
#endif

typedef enum aurioTouchDisplayMode {
	aurioTouchDisplayModeOscilloscopeWaveform,
	aurioTouchDisplayModeOscilloscopeFFT,
	aurioTouchDisplayModeSpectrum
} aurioTouchDisplayMode;

typedef struct SpectrumLinkedTexture {
	GLuint							texName;
	struct SpectrumLinkedTexture	*nextTex;
} SpectrumLinkedTexture;

inline double linearInterp(double valA, double valB, double fract)
{
	return valA + ((valB - valA) * fract);
}

@interface VoiceDelegate : NSObject<AVAudioRecorderDelegate, AVAudioPlayerDelegate, EAGLViewDelegate>
{
//	IBOutlet UIWindow*			window;
	IBOutlet EAGLView*			view;
	
	UIImageView*				sampleSizeOverlay;
	UILabel*					sampleSizeText;
	
	SInt32*						fftData;
	NSUInteger					fftLength;
	BOOL						hasNewFFTData;
	
	AudioUnit					rioUnit;
	BOOL						unitIsRunning;
	BOOL						unitHasBeenCreated;
	
	BOOL						initted_oscilloscope, initted_spectrum;
	UInt32*						texBitBuffer;
	CGRect						spectrumRect;
	
	GLuint						bgTexture;
	GLuint						muteOffTexture, muteOnTexture;
	GLuint						fftOffTexture, fftOnTexture;
	GLuint						sonoTexture;
	
	aurioTouchDisplayMode		displayMode;
	
	BOOL						mute;
	
	SpectrumLinkedTexture*		firstTex;
	FFTBufferManager*			fftBufferManager;
	DCRejectionFilter*			dcFilter;
	CAStreamBasicDescription	thruFormat;
    CAStreamBasicDescription    drawFormat;
    AudioBufferList*            drawABL;
	Float64						hwSampleRate;
    
    AudioConverterRef           audioConverter;
	
	UIEvent*					pinchEvent;
	CGFloat						lastPinchDist;
	
	AURenderCallbackStruct		inputProc;
    
	SystemSoundID				buttonPressSound;
	
	int32_t*					l_fftData;
    
	GLfloat*					oscilLine;
	BOOL						resetOscilLine;
}

@property (nonatomic, retain)	UIWindow*				window;
@property (nonatomic, retain)	EAGLView*				view;

@property (assign)				aurioTouchDisplayMode	displayMode;
@property						FFTBufferManager*		fftBufferManager;

@property (nonatomic, assign)	AudioUnit				rioUnit;
@property (nonatomic, assign)	BOOL					unitIsRunning;
@property (nonatomic, assign)	BOOL					unitHasBeenCreated;
@property (nonatomic, assign)	BOOL					mute;
@property (nonatomic, assign)	AURenderCallbackStruct	inputProc;

- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion;

-(void) prepareRecording;
-(void) startRecordingUsername: (NSString *) username;
-(void) stopRecordingSend: (BOOL) send;
@end
