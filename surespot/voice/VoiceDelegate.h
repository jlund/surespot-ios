//
//  VoiceDelegate.h
//  surespot
//
//  Created by Adam on 12/27/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface VoiceDelegate : NSObject<AVAudioRecorderDelegate, AVAudioPlayerDelegate>
- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion;

-(void) prepareRecording;
-(void) startRecordingUsername: (NSString *) username;
-(void) stopRecordingSend: (BOOL) send;
@end
