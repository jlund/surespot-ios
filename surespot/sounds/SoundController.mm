//
//  SoundController.m
//  surespot
//
//  Created by Adam on 1/13/14.
//  Copyright (c) 2014 2fours. All rights reserved.
//

#import "SoundController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "IdentityController.h"
#import "UIUtils.h"

@interface SoundController() {
    SystemSoundID _messageSoundID;
    SystemSoundID _inviteSoundID;
    SystemSoundID _acceptSoundID;
    NSMutableDictionary * soundMap;
    
}


@end

@implementation SoundController
+(SoundController*)sharedInstance
{
    static SoundController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}


-(id) init {
    self = [super init];
    if (self) {
        
        soundMap = [NSMutableDictionary new];
        NSString *messageSoundPath = [[NSBundle mainBundle]
                                      pathForResource:@"message" ofType:@"caf"];
        
        NSURL *messageSoundURL = [NSURL fileURLWithPath:messageSoundPath];
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)messageSoundURL, &_messageSoundID);
        
        [soundMap setObject:[NSNumber numberWithInt:_messageSoundID] forKey:@"message.caf"];
        
        NSString *inviteSoundPath = [[NSBundle mainBundle]
                                     pathForResource:@"surespot-invite" ofType:@"caf"];
        NSURL *inviteSoundURL = [NSURL fileURLWithPath:inviteSoundPath];
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)inviteSoundURL, &_inviteSoundID);
        [soundMap setObject:[NSNumber numberWithInt:_inviteSoundID] forKey:@"surespot-invite.caf"];
        
        
        NSString *inviteAcceptSoundPath = [[NSBundle mainBundle]
                                           pathForResource:@"invite-accept" ofType:@"caf"];
        NSURL *inviteAcceptSoundURL = [NSURL fileURLWithPath:inviteAcceptSoundPath];
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)inviteAcceptSoundURL, &_acceptSoundID);
        [soundMap setObject:[NSNumber numberWithInt:_acceptSoundID] forKey:@"invite-accept.caf"];
        
    }
    return self;
}

-(BOOL) shouldPlaySoundForUser: (NSString *) username {
    BOOL playSound = [UIUtils getBoolPrefWithDefaultYesForUser:username key:@"_user_notifications_sound"];
    return playSound;
}

-(void) playNewMessageSoundForUser: (NSString *) username {
    
    if ([self shouldPlaySoundForUser: username]) {
        AudioServicesPlaySystemSound(_messageSoundID);
    }
}
-(void) playInviteSoundForUser: (NSString *) username {
    if ([self shouldPlaySoundForUser:username]) {
        AudioServicesPlaySystemSound(_inviteSoundID);
    }
}

-(void) playInviteAcceptedSoundForUser: (NSString *) username {
    if ([self shouldPlaySoundForUser:username]) {
        AudioServicesPlaySystemSound(_acceptSoundID);
    }
}

-(void) playSoundNamed: (NSString *) soundName forUser: (NSString *) username{
    if ([self shouldPlaySoundForUser:username]) {
        AudioServicesPlaySystemSound([[soundMap objectForKey:soundName] intValue]);
    }
}

@end
