//
//  VoiceDelegate.m
//  surespot
//
//  Created by Adam on 12/27/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "VoiceDelegate.h"
#import "DDLog.h"
#import "IdentityController.h"
#import "EncryptionController.h"
#import "UIUtils.h"
#import "NSData+Base64.h"
#import "ChatController.h"
#import "ChatDataSource.h"
#import "NetworkController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface VoiceDelegate()
@property (nonatomic, strong) NSString * username;
@property (nonatomic, strong) NSString * theirUsername;
@property (nonatomic, strong) NSString * ourVersion;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) AVAudioPlayer *player;
@end

@implementation VoiceDelegate


- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion


{
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;
    _username = username;
    _ourVersion = ourVersion;
    return self;
}



-(void) prepareRecording {
    
    NSArray *pathComponents = [NSArray arrayWithObjects:
                               [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                               @"MyAudioMemo.m4a",
                               nil];
    NSURL *outputFileURL = [NSURL fileURLWithPathComponents:pathComponents];
    
    // Setup audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    // Define the recorder setting
    NSMutableDictionary *recordSetting = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithInt:kAudioFormatMPEG4AAC] , AVFormatIDKey,
                                          [NSNumber numberWithInteger: 12000], AVEncoderBitRateKey,
                                          [NSNumber numberWithFloat: 12000],AVSampleRateKey,
                                          [NSNumber numberWithInt:1],AVNumberOfChannelsKey, nil];
    
    // Initiate and prepare the recorder
    _recorder = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordSetting error:nil];
    _recorder.delegate = self;
    _recorder.meteringEnabled = YES;
    [_recorder prepareToRecord];
}

-(void) startRecordingUsername: (NSString *) username {
    DDLogInfo(@"start recording");
    if (_player.playing) {
        [_player stop];
    }
    
    if (!_recorder.recording) {
        _theirUsername = username;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:YES error:nil];
        
        // Start recording
        [_recorder record];
        //  [recordPauseButton setTitle:@"Pause" forState:UIControlStateNormal];
        
    }
}

-(void) stopRecordingSend: (BOOL) send {
    DDLogInfo(@"stop recording");
    if (_recorder.recording) {
        [_recorder stop];
        
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:NO error:nil];
        
        _player = [[AVAudioPlayer alloc] initWithContentsOfURL:_recorder.url error:nil];
        [_player setDelegate:self];
        [_player play];
        

        
        if (send) {
            [self uploadVoiceUrl:_recorder.url];
        }
        
        else {
            //todo delete file
        }
        

    }
}


-(void) uploadVoiceUrl: (NSURL *) url {
    //    if (!image) {
    //        [self stopProgress];
    //        [UIUtils showToastKey:NSLocalizedString(@"could_not_upload_image", nil) duration:2];
    //        return;
    //    }
    //
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [[IdentityController sharedInstance] getTheirLatestVersionForUsername:_theirUsername callback:^(NSString *version) {
            if (version) {
                //encrypt and upload the voice data
                NSData * voiceData = [NSData dataWithContentsOfURL: url];
                NSData * iv = [EncryptionController getIv];
                
                //encrypt
                [EncryptionController symmetricEncryptData:voiceData
                                                ourVersion:_ourVersion
                                             theirUsername:_theirUsername
                                              theirVersion:version
                                                        iv:iv
                                                  callback:^(NSData * encryptedImageData) {
                                                      if (encryptedImageData) {
                                                          //create message
                                                          SurespotMessage * message = [SurespotMessage new];
                                                          message.from = _username;
                                                          message.fromVersion = _ourVersion;
                                                          message.to = _theirUsername;
                                                          message.toVersion = version;
                                                          message.mimeType = MIME_TYPE_M4A;
                                                          message.iv = [iv base64EncodedStringWithSeparateLines:NO];
                                                    //      NSString * key = [@"voiceKey_" stringByAppendingString: message.iv];
                                                      //    message.data = key;
                                                          
//                                                          DDLogInfo(@"adding local image to cache %@", key);
//                                                          [[[SDWebImageManager sharedManager] imageCache] storeImage:scaledImage imageData:encryptedImageData forKey:key toDisk:YES];
                                                          
                                                          //add message locally before we upload it
                                                          ChatDataSource * cds = [[ChatController sharedInstance] getDataSourceForFriendname:_theirUsername];
                                                          if (cds) {
                                                              [cds addMessage:message refresh:YES];
                                                          }
                                                          
                                                          //upload image to server
                                                     //     DDLogInfo(@"uploading image %@ to server", key);
                                                          [[NetworkController sharedInstance] postFileStreamData:encryptedImageData
                                                                                                      ourVersion:_ourVersion
                                                                                                   theirUsername:_theirUsername
                                                                                                    theirVersion:version
                                                                                                          fileid:[iv SR_stringByBase64Encoding]
                                                                                                        mimeType:MIME_TYPE_M4A
                                                                                                    successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                                                      //  DDLogInfo(@"uploaded voice %@ to server successfully", key);
                                                                                                        //[self stopProgress];
                                                                                                    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                                                    //    DDLogInfo(@"uploaded voice %@ to server failed, statuscode: %d", key, operation.response.statusCode);
                                                                                                      //  [self stopProgress];
                                                                                                        if (operation.response.statusCode == 402) {
                                                                                                            message.errorStatus = 402;
                                                                                                        }
                                                                                                        else {
                                                                                                            message.errorStatus = 500;
                                                                                                        }
                                                                                                        
                                                                                                        [cds postRefresh];
                                                                                                    }];
                                                      }
                                                      else {
                                                        //  [self stopProgress];
                                                          [UIUtils showToastKey:NSLocalizedString(@"could_not_upload_image", nil) duration:2];
                                                          
                                                      }
                                                  }];
                
            }
            else {
                [UIUtils showToastKey:NSLocalizedString(@"could_not_upload_image", nil) duration:2];
            }
        }];
    });
}




@end