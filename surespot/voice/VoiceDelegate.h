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
#import "aurio_helper.h"
#import "CAStreamBasicDescription.h"

#import "SurespotMessage.h"
#import "MessageView.h"


#ifndef CLAMP
#define CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))
#endif

inline double linearInterp(double valA, double valB, double fract)
{
	return valA + ((valB - valA) * fract);
}

@interface VoiceDelegate : NSObject<AVAudioRecorderDelegate, AVAudioPlayerDelegate, EAGLViewDelegate>
{
	IBOutlet EAGLView*			view;
			
	AudioUnit					rioUnit;
	BOOL						unitIsRunning;
	BOOL						unitHasBeenCreated;
	
	UInt32*						texBitBuffer;
	
	GLuint						bgTexture;

	

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

@property (nonatomic, strong)	EAGLView*				view;
@property (nonatomic, assign)	AudioUnit				rioUnit;
@property (nonatomic, assign)	BOOL					unitIsRunning;
@property (nonatomic, assign)	BOOL					unitHasBeenCreated;
@property (nonatomic, assign)	BOOL					mute;
@property (nonatomic, assign)	AURenderCallbackStruct	inputProc;
@property (nonatomic, assign)   NSInteger               max;
@property (nonatomic, strong)   UIView * backgroundView;

- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion;


-(void) playVoiceMessage: (SurespotMessage *) message cell: (MessageView *) cell;
-(void) prepareRecording;
-(void) startRecordingUsername: (NSString *) username;
-(void) stopRecordingSend: (NSNumber *) send;
-(void) attachCell: (MessageView *) cell;
-(BOOL) isRecording;
@end
